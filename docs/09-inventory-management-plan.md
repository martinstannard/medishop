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

## Proposed Architecture: Event-Sourced Inventory with AshEvents

### Why Event Sourcing with AshEvents?

We'll use **AshEvents** (`ash_events` package) for built-in event sourcing capabilities:

- **Complete audit trail**: Every inventory change is recorded automatically
- **Actor attribution**: Automatically tracks who made each change
- **Versioning**: Built-in version tracking for all events
- **Point-in-time queries**: "What was the stock level on date X?"
- **Event replay**: Reconstruct state from event history
- **Regulatory compliance**: Required for pharmaceutical inventory with full audit trail
- **Reconciliation**: Easy to identify discrepancies
- **Maintained by Ash team**: Less maintenance burden than custom implementation

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

#### 1.1 Create InventoryEvent Resource with AshEvents

**Purpose**: Immutable event log of all inventory changes using AshEvents extension

**Setup**:
```elixir
use Ash.Resource,
  otp_app: :medishop,
  domain: Medishop.Inventory,
  data_layer: AshPostgres.DataLayer,
  extensions: [AshEvents.Event]  # Add AshEvents extension
```

**Attributes**:
- `id` (uuid, primary key)
- `location_id` (uuid, references locations)
- `product_id` (uuid, references products)
- `event_type` (enum: :purchase_received, :administered, :expired, :disposed, :adjustment)
- `quantity_change` (integer, positive for additions, negative for removals)
- `batch_number` (string, optional - lot number)
- `expiration_date` (date, optional)
- `reference_type` (string, optional - "Order", "Transfer", etc.)
- `reference_id` (uuid, optional - links to order, transfer, etc.)
- `reason` (string, optional - why was this done)
- `occurred_at` (utc_datetime_usec, when event happened)

**AshEvents Automatic Fields** (provided by extension):
- `actor_id` (uuid) - Automatically set by AshEvents to track who made the change
- `version` (integer) - Event version for ordering and replay
- `metadata` (map) - Additional event metadata
- `created_at` (utc_datetime_usec) - Automatically set when event is recorded

**Actions**:
- `create` - Record new inventory event (AshEvents handles actor attribution)
- `read` - Query events (with filtering by location, product, date range)
- No update/delete - events are immutable (enforced by AshEvents)

**Calculations**:
- `net_change` - Returns quantity_change (for aggregation)

**AshEvents Configuration**:
```elixir
events do
  # Configure event versioning
  event_source :inventory_events

  # Automatically track actor (performed_by_user_id becomes actor_id)
  track_actor? true

  # Store changed attributes in metadata
  store_changed_attributes? true
end
```

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
defp create_inventory_events_for_order(order, context) do
  # Load order items with products
  {:ok, order} = Shop.get_order(order.id, load: [:order_items])

  # Create inventory event for each order item
  # AshEvents will automatically set actor_id from context
  Enum.each(order.order_items, fn item ->
    Inventory.create_inventory_event(
      %{
        location_id: order.location_id,
        product_id: item.product_id,
        event_type: :purchase_received,
        quantity_change: item.quantity,
        reference_type: "Order",
        reference_id: order.id,
        occurred_at: DateTime.utc_now()
      },
      actor: context.actor  # AshEvents uses actor from context
    )
  end)
end
```

**Note**: With AshEvents, we no longer need `performed_by_user_id` as the extension automatically tracks the actor via `actor_id` field.

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

#### 3.2 Inventory Detail/Event Log LiveView ✅ **COMPLETED**

**Route**: `/location/:location_id/inventory/:product_id`

**Features** (✅ All Implemented):
- ✅ Product information (name, SKU, current quantity)
- ✅ Stock status badge (Out of Stock / Low Stock / In Stock)
- ✅ Event log table (all inventory events for this product)
  - ✅ Columns: Date/Time, Type, Quantity Change, Reference, Reason
  - ✅ Sort by occurred_at and quantity_change (toggleable asc/desc)
  - ✅ Filter by event type (All, Purchases, Administered, Expired, Disposed, Adjustments)
  - ✅ Color-coded event type badges
  - ✅ Quantity changes with +/- formatting
  - ✅ Empty state messages
- ✅ Navigation: Back to Inventory link
- ✅ 30 comprehensive tests covering all features

**Implementation**: `lib/medishop_web/live/inventory_detail_live.ex` (484 lines)

**Tests**: `test/medishop_web/live/inventory_detail_live_test.exs` (30 tests, all passing)

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

### Using AshEvents Extension

#### Event Sourcing with AshEvents

We'll use the **AshEvents** extension from the Ash project for built-in event sourcing:

**Package**: `ash_events` (https://github.com/ash-project/ash_events)
**Released**: May 2025

#### Key Features We'll Use

1. **Automatic Event Logging**: All inventory changes recorded automatically
2. **Actor Attribution**: Automatic tracking of who made each change via `actor_id`
3. **Versioning**: Built-in event versioning for ordering and replay
4. **Immutability**: Events are append-only by design (no updates/deletes)
5. **Metadata Tracking**: Changed attributes stored automatically
6. **Event Replay**: Reconstruct state from event history for audits

#### Architecture with AshEvents

```elixir
# InventoryEvent resource with AshEvents extension
use Ash.Resource,
  extensions: [AshEvents.Event]

# Configure event sourcing behavior
events do
  event_source :inventory_events
  track_actor? true
  store_changed_attributes? true
end

# LocationInventory becomes a read model
# InventoryEvent (with AshEvents) is the source of truth
# Current quantity is calculated from events using aggregates
```

**Benefits of AshEvents**:
- **Regulatory compliance**: Complete audit trail with actor attribution
- **Maintained by Ash team**: Less maintenance burden
- **Event replay**: Can reconstruct inventory state at any point in time
- **Versioning**: Built-in event ordering and version management
- **Simpler code**: Less boilerplate than custom implementation
- **Future-proof**: Can add event replay for physical count reconciliation (Phase 2)

### Database Schema

```sql
-- New table with AshEvents fields
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
  occurred_at TIMESTAMP NOT NULL,

  -- AshEvents automatic fields
  actor_id UUID REFERENCES users(id),  -- Replaces performed_by_user_id
  version INTEGER NOT NULL,            -- Event version for ordering
  metadata JSONB,                      -- Additional event metadata
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inventory_events_location_product
  ON inventory_events(location_id, product_id);
CREATE INDEX idx_inventory_events_occurred_at
  ON inventory_events(occurred_at DESC);
CREATE INDEX idx_inventory_events_actor_id
  ON inventory_events(actor_id);
CREATE INDEX idx_inventory_events_version
  ON inventory_events(version);

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
1. Add `ash_events` dependency to mix.exs
2. InventoryEvent resource with AshEvents extension (without batch tracking)
3. Update LocationInventory to calculate from events
4. UI control for marking orders as delivered (OrdersLive or OrderConfirmationLive)
5. Order integration (auto-create events on :delivered with actor tracking)
6. Basic inventory list UI showing current stock levels
7. **Current Stock Levels Report** (REQUIRED)
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

### Phase 1 (COMPLETE ✅)
- ✅ Every inventory change is recorded as an event
- ✅ Current stock levels accurately reflect event history
- ✅ Orders automatically update inventory when delivered
- ✅ Actor attribution via AshEvents (tracks who made changes)
- ✅ Event versioning and metadata tracking
- ✅ Comprehensive test coverage (31 tests, all passing)
- ✅ InventoryEvent resource with 5 event types
- ✅ LocationInventory calculates quantity from events (aggregate)
- ✅ Order integration with after_action hook
- ✅ Idempotent event creation (prevents duplicates)

### Phase 3 (IN PROGRESS)
- ⏳ Users can mark items as administered/expired/disposed (via UI)
- ⏳ Complete audit trail visible in UI
- ⏳ Inventory list view with current quantities
- ⏳ Event log view per product
- ⏳ UI is intuitive for daily inventory management
- ✅ All tests passing with good coverage

## Implementation Progress

### Phase 1: Event-Sourced Inventory Foundation (COMPLETE ✅)
1. ✅ Review and approve this plan (DONE - using AshEvents)
2. ✅ Add `ash_events` dependency to mix.exs
3. ✅ Create InventoryEvent resource with AshEvents extension
4. ✅ Update LocationInventory to use calculated quantity from events
5. ✅ Implement order integration with automatic event creation
6. ✅ Write comprehensive tests (31 tests, all passing)
7. ✅ Generate and run migrations

### Phase 3: Inventory Management UI (IN PROGRESS)
1. ⏳ Build inventory list UI (current stock levels report)
2. ⏳ Build inventory detail/event log UI
3. ⏳ Build event recording form/modal
4. ⏳ Add dashboard widget for low stock alerts
5. ⏳ Write comprehensive LiveView tests
6. ⏳ Deploy and train users

## Dependencies

**Add to mix.exs**:
```elixir
{:ash_events, "~> 0.1"}  # Event sourcing extension for Ash
```
