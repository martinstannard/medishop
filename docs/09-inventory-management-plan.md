# Inventory Management System - Implementation Plan

## Overview

This plan describes the implementation of a comprehensive inventory management system that tracks medication stock levels using an event-sourced approach. The system will record all inventory movements (purchases, usage, disposal, expiration) and calculate current stock levels from the event log.

## Current State Analysis

### What We Have
- **LocationInventory resource**: Simple aggregate with `quantity_available` field
- **Order/OrderItem**: Creates orders but doesn't update inventory
- **Products**: Product catalog with pricing

### What's Missing
- Event-sourced inventory tracking (purchases, usage, disposal, etc.)
- Automatic inventory updates when orders are received
- Audit trail of all inventory movements
- Batch/lot tracking with expiration dates
- Usage tracking (administered, expired, disposed)
- UI for managing inventory

## Proposed Architecture: Event-Sourced Inventory

### Why Event Sourcing?

Event sourcing provides:
- **Complete audit trail**: Every inventory change is recorded
- **Point-in-time queries**: "What was the stock level on date X?"
- **Regulatory compliance**: Required for pharmaceutical inventory
- **Reconciliation**: Easy to identify discrepancies
- **Undo capability**: Can reverse erroneous entries

### Core Concepts

```
LocationInventory (Aggregate Root)
├── InventoryEvent (Event Log)
│   ├── :purchase_received - Stock added from order
│   ├── :administered - Medication given to patient
│   ├── :expired - Medication past expiration
│   ├── :disposed - Medication disposed (damaged, recalled)
│   ├── :adjustment - Manual correction
│   └── :transfer_out / :transfer_in - Between locations
├── InventoryBatch (Lot Tracking)
│   ├── batch_number
│   ├── expiration_date
│   ├── quantity_received
│   └── quantity_remaining
└── Calculated: current_quantity (sum of all events)
```

## Implementation Phases

### Phase 1: Event-Sourced Inventory Foundation

#### 1.1 Create InventoryEvent Resource

**Purpose**: Immutable event log of all inventory changes

**Attributes**:
- `id` (uuid, primary key)
- `location_id` (uuid, references locations)
- `product_id` (uuid, references products)
- `event_type` (enum: :purchase_received, :administered, :expired, :disposed, :adjustment, :transfer_in, :transfer_out)
- `quantity_change` (integer, positive for additions, negative for removals)
- `batch_number` (string, optional - lot number)
- `expiration_date` (date, optional)
- `reference_type` (string, optional - "Order", "Transfer", etc.)
- `reference_id` (uuid, optional - links to order, transfer, etc.)
- `reason` (string, optional - why was this done)
- `performed_by_user_id` (uuid, references users)
- `occurred_at` (utc_datetime_usec, when event happened)
- `created_at` (utc_datetime_usec, when recorded in system)

**Actions**:
- `create` - Record new inventory event
- `read` - Query events (with filtering by location, product, date range)
- No update/delete - events are immutable

**Calculations**:
- `net_change` - Returns quantity_change (for aggregation)

**Policies**:
- ✅ **All users with location access** can create and read events (per requirements #3)
- No special roles required for inventory management

#### 1.2 Create InventoryBatch Resource (**DEFERRED TO PHASE 2**)

**Purpose**: Track specific batches/lots with expiration dates

**Attributes**:
- `id` (uuid, primary key)
- `location_id` (uuid)
- `product_id` (uuid)
- `batch_number` (string, unique per product)
- `expiration_date` (date)
- `quantity_received` (integer)
- `quantity_remaining` (integer, calculated from events)
- `created_at` (utc_datetime_usec)

**Status**: ✅ **Confirmed for Phase 2** - Per requirements clarification, batch/lot tracking with expiration dates will be implemented after Phase 1 MVP

#### 1.3 Update LocationInventory Resource

**Change from aggregate field to calculated field**:

```elixir
# Remove attribute :quantity_available

# Add calculation
calculations do
  calculate :current_quantity, :integer, expr(
    fragment("(
      SELECT COALESCE(SUM(quantity_change), 0)
      FROM inventory_events
      WHERE inventory_events.location_id = ?
      AND inventory_events.product_id = ?
    )", location_id, product_id)
  )
end
```

**Or use Ash aggregates**:
```elixir
aggregates do
  sum :current_quantity, :inventory_events, :quantity_change
end

relationships do
  has_many :inventory_events, Medishop.Inventory.InventoryEvent do
    destination_attribute :location_id
    source_attribute :location_id
    filter expr(product_id == parent(product_id))
  end
end
```

### Phase 2: Order Integration

#### 2.1 Add UI Control for Marking Order as Delivered

**Update OrdersLive or OrderConfirmationLive**:

Add status update buttons/dropdown:
- Show current status badge
- "Mark as Delivered" button (only visible if status allows transition)
- Calls `Shop.update_order_status(order, :delivered)`
- Confirmation modal: "This will add items to inventory. Continue?"

**Route options**:
- Option 1: Add to existing OrdersLive (status column with action buttons)
- Option 2: Add to OrderConfirmationLive (order detail view)
- Option 3: New admin order management page

#### 2.2 Create Inventory Event When Order is Delivered

**Hook into Order status changes** via `after_action` in Order resource:

```elixir
# In Order resource - update_status action
update :update_status do
  accept []
  argument :status, :atom, allow_nil?: false

  change set_attribute(:status, arg(:status))

  validate fn changeset, _context ->
    current = Ash.Changeset.get_attribute(changeset, :status)
    new = Ash.Changeset.get_argument(changeset, :status)

    if valid_status_transition?(current, new) do
      :ok
    else
      {:error, "Invalid status transition from #{current} to #{new}"}
    end
  end

  # After successfully changing to :delivered, create inventory events
  change after_action(fn changeset, result, _context ->
    new_status = Ash.Changeset.get_argument(changeset, :status)
    old_status = Ash.Changeset.get_data(changeset).status

    if new_status == :delivered and old_status != :delivered do
      create_inventory_events_for_order(result)
    end

    {:ok, result}
  end)
end
```

**Implementation**:
```elixir
defp create_inventory_events_for_order(order) do
  # Load order items with products
  {:ok, order} = Shop.get_order(order.id, load: [:order_items])

  # Create inventory event for each order item
  Enum.each(order.order_items, fn item ->
    Inventory.create_inventory_event(%{
      location_id: order.location_id,
      product_id: item.product_id,
      event_type: :purchase_received,
      quantity_change: item.quantity,
      reference_type: "Order",
      reference_id: order.id,
      performed_by_user_id: order.user_id,
      occurred_at: DateTime.utc_now()
    })
  end)
end
```

#### 2.3 Validation: Prevent Duplicate Inventory Events

**Protection mechanisms**:
1. Status transition validation prevents going from :delivered to :delivered
2. Check in `after_action`: only create events if transitioning TO :delivered
3. Consider idempotency: Check if events already exist for this order before creating

### Phase 3: Inventory Management UI

#### 3.1 Inventory List LiveView

**Route**: `/location/:location_id/inventory`

**Features**:
- Display all products with current quantity
- Show low stock warnings (quantity < reorder_threshold)
- Filter by product name/SKU
- Sort by quantity, product name
- Color coding: red (out of stock), yellow (low stock), green (sufficient)
- Link to inventory detail page

**Data**:
```elixir
{:ok, inventory_items} = Inventory.list_location_inventories(
  location_id: location.id,
  load: [:product, :current_quantity]
)
```

#### 3.2 Inventory Detail/Event Log LiveView

**Route**: `/location/:location_id/inventory/:product_id`

**Features**:
- Product information (name, SKU, current quantity)
- Event log table (all inventory events for this product)
  - Columns: Date/Time, Type, Quantity Change, Batch, Expiration, Reason, User
  - Sort by date (newest first)
  - Filter by event type
- Quick actions:
  - Record usage (administered)
  - Mark as expired
  - Record disposal
  - Manual adjustment
- Charts:
  - Stock level over time
  - Usage patterns

#### 3.3 Record Inventory Event Modal/Form

**Accessible from inventory detail page**

**Form fields**:
- Event type (dropdown: Administered, Expired, Disposed, Adjustment)
- Quantity (integer, validates > 0 for removals)
- Batch number (optional, text)
- Expiration date (optional, date picker)
- Reason (textarea, required for disposal/adjustment)

**Validation**:
- Cannot remove more than current quantity
- Expiration date must be in the past for :expired events
- Reason required for :disposed and :adjustment events

#### 3.4 Dashboard Inventory Widget

**Add to main Dashboard**:
- "Low Stock Alerts" section
- Shows products below reorder threshold across all user's locations
- Click to navigate to inventory page

### Phase 4: Batch/Lot Tracking (Optional Enhancement)

If needed for regulatory compliance:

#### 4.1 Batch Management
- Track individual batches with expiration dates
- FIFO (First In, First Out) consumption
- Expiration alerts

#### 4.2 Batch Selection on Events
- When recording usage, select which batch to consume from
- Automatically suggest oldest batch (FIFO)
- Warn if using near-expiration batch

### Phase 5: Reports and Analytics

#### 5.1 Inventory Reports
- Current stock levels by location
- Usage trends (daily/weekly/monthly)
- Expiration report (items expiring soon)
- Disposal report (what was disposed and why)
- Order history vs. usage (optimize ordering)

#### 5.2 Audit Trail
- Complete event log export (CSV/PDF)
- Regulatory compliance reporting

## Technical Implementation Details

### Using Ash Framework Features

#### Event Sourcing with Ash

Ash doesn't have built-in event sourcing (like Commanded), but we can implement it using:

1. **Immutable InventoryEvent resource** (append-only log)
2. **Calculations/Aggregates** for current state
3. **Change tracking** via `after_action` hooks

**Not using AshEvents**: The blog post you referenced (https://alembic.com.au/blog/ash-events-event-sourcing-made-simple-for-ash-framework) is about the Ash Eventing system for notifications, not event sourcing for domain events.

#### Alternative: Simple Event Log Pattern

Since we're not using Commanded or EventStore:

```elixir
# LocationInventory becomes a read model
# InventoryEvent is the source of truth
# Current quantity is calculated from events
```

**Benefits**:
- Simpler than full event sourcing framework
- Still provides audit trail
- Easy to understand and maintain
- Works well with Ash Framework patterns

### Database Schema

```sql
-- New table
CREATE TABLE inventory_events (
  id UUID PRIMARY KEY,
  location_id UUID REFERENCES locations(id),
  product_id UUID REFERENCES products(id),
  event_type VARCHAR(50) NOT NULL,
  quantity_change INTEGER NOT NULL,
  batch_number VARCHAR(255),
  expiration_date DATE,
  reference_type VARCHAR(100),
  reference_id UUID,
  reason TEXT,
  performed_by_user_id UUID REFERENCES users(id),
  occurred_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inventory_events_location_product
  ON inventory_events(location_id, product_id);
CREATE INDEX idx_inventory_events_occurred_at
  ON inventory_events(occurred_at DESC);

-- Optional: Batches table
CREATE TABLE inventory_batches (
  id UUID PRIMARY KEY,
  location_id UUID REFERENCES locations(id),
  product_id UUID REFERENCES products(id),
  batch_number VARCHAR(255) NOT NULL,
  expiration_date DATE NOT NULL,
  quantity_received INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(location_id, product_id, batch_number)
);
```

### Code Interface Updates

```elixir
# Medishop.Inventory domain
resources do
  resource Medishop.Inventory.LocationInventory do
    # existing definitions...
  end

  resource Medishop.Inventory.InventoryEvent do
    define :create_inventory_event, action: :create
    define :list_inventory_events, action: :read
    define :get_inventory_event, action: :read, get_by: [:id]
    define :get_events_by_location_and_product,
      action: :by_location_and_product,
      args: [:location_id, :product_id]
  end
end
```

## Testing Strategy

### Unit Tests
- InventoryEvent creation with all event types
- Current quantity calculation from events
- Event validation (negative quantities, etc.)
- Order integration (event creation on delivery)

### Integration Tests
- Full flow: Order → Delivered → Inventory Updated
- Multiple events affecting same product
- Event log querying and filtering

### LiveView Tests
- Inventory list display
- Event recording UI
- Validation in forms

## Requirements Confirmed

1. **Batch/Lot Tracking**: ✅ Phase 2 - Will add expiration date tracking later

2. **Event Types**: ✅ Confirmed sufficient for Phase 1
   - :purchase_received (from orders)
   - :administered (used for patients)
   - :expired (past expiration date)
   - :disposed (damaged, recalled, contaminated)
   - :adjustment (manual corrections)
   - ~~:transfer_in / :transfer_out~~ - Not needed

3. **Authorization**: ✅ Everyone with location access can view and manage inventory
   - View inventory: All users with location access
   - Record inventory events: All users with location access
   - Make adjustments: All users with location access

4. **Order Behavior**: ✅ Automatic inventory update when status changes to :delivered
   - Needs UI control to mark orders as delivered
   - Only :delivered orders update inventory (not :confirmed or :shipped)
   - Orders cancelled before delivery do NOT affect inventory

5. **Reorder Thresholds**: ✅ Not needed for Phase 1 - Can add later

6. **Physical Inventory Counts**: ✅ Phase 2 or later
   - Note: Audit system for reconciling physical counts vs. system counts
   - Will create adjustment events for discrepancies

7. **Returns/Credits**: ✅ Confirmed - Only :delivered orders affect inventory
   - Cancelled orders before delivery = no inventory change
   - Returns after delivery = future enhancement

8. **Reporting Priority**: ✅ Phase 1 requires:
   - **Current stock levels report** (REQUIRED)
   - Usage trends (Phase 2)
   - Expiration alerts (Phase 2, with batch tracking)
   - Disposal log (Phase 2)

## Recommended Approach

### Start Simple, Iterate

**Phase 1 MVP** (1-2 weeks):
1. InventoryEvent resource (without batch tracking)
2. Update LocationInventory to calculate from events
3. UI control for marking orders as delivered (OrdersLive or OrderConfirmationLive)
4. Order integration (auto-create events on :delivered)
5. Basic inventory list UI showing current stock levels
6. **Current Stock Levels Report** (REQUIRED)
   - View: `/location/:location_id/inventory`
   - Shows all products with current quantities
   - Filter by product name/SKU
   - Sort by name or quantity
   - Export to CSV

**Phase 2 Enhancement** (1 week):
1. Event recording UI (mark as used, expired, disposed)
2. Event log view per product
3. Batch/lot tracking with expiration dates (from requirements #1)

**Phase 3 Advanced** (1-2 weeks):
1. Physical inventory count audit system (from requirements #6)
2. Reports and analytics (usage trends, disposal log)
3. Low stock alerts (reorder thresholds)

## Success Criteria

- ✅ Every inventory change is recorded as an event
- ✅ Current stock levels accurately reflect event history
- ✅ Orders automatically update inventory when delivered
- ✅ Users can mark items as administered/expired/disposed
- ✅ Complete audit trail of all inventory movements
- ✅ No lost inventory events (append-only log)
- ✅ UI is intuitive for daily inventory management
- ✅ All tests passing with good coverage

## Next Steps

After clarification of the questions above:
1. Review and approve this plan
2. Create InventoryEvent resource
3. Update LocationInventory to use calculated quantity
4. Implement order integration
5. Build inventory management UI
6. Write comprehensive tests
7. Deploy and train users
