# Stock Reconciliation Feature Plan

## Overview

This document outlines the implementation plan for **Feature Set 1: Inventory & Drug Registry**, focusing on periodic stock reconciliation to ensure the digital ledger accurately reflects physical inventory.

## User Story

**Story 1: Periodic Stock Reconciliation**

> As a Location Admin,
> I want to perform a physical stock take and input the actual count of units and measurements (e.g., milliliters) into the system,
> So that the digital inventory ledger reflects the true physical stock on hand and identifies any discrepancies.

## Business Requirements

### Core Functionality
1. **Physical Stock Take Interface**: Allow entry of physical counts for all inventory items
2. **Discrepancy Detection**: Compare physical counts against system counts automatically
3. **Adjustment Creation**: Generate adjustment events for any discrepancies found
4. **Reason Categorization**: Require categorized reasons for all adjustments
5. **Storage Location Support**: Track items in different storage locations (cupboard, fridge)
6. **Unit of Measure**: Support different measurement units (tablets, mL, vials, etc.)
7. **Audit Trail**: Complete history of all reconciliation sessions

### Acceptance Criteria
- ✅ System displays all active inventory items for a location
- ✅ Users can enter physical counts for each item
- ✅ System calculates and displays discrepancies (physical - system count)
- ✅ Users must select a reason category for each discrepancy
- ✅ System creates adjustment inventory events for approved discrepancies
- ✅ Reconciliation session is saved with timestamp and user attribution
- ✅ Users can view history of past reconciliations
- ✅ Items can be filtered by storage location (cupboard/fridge)
- ✅ Different unit of measure supported (tablets, mL, vials, etc.)

## Current System Analysis

### Existing Resources
1. **LocationInventory** (`lib/medishop/inventory/location_inventory.ex`)
   - Tracks current quantity via aggregate of inventory events
   - Relates to location and product
   - Current quantity calculated from `sum(inventory_events.quantity_change)`

2. **InventoryEvent** (`lib/medishop/inventory/inventory_event.ex`)
   - Event-sourced inventory tracking with AshEvents extension
   - Event types: `:purchase_received`, `:administered`, `:expired`, `:disposed`, `:adjustment`
   - Already has `reason` field for explanatory text
   - Has `actor_id` via AshEvents for user attribution
   - Has `occurred_at` timestamp

3. **Product** (`lib/medishop/products/product.ex`)
   - Basic product information (SKU, title, description, price)
   - Currently lacks storage location and unit of measure

### What's Missing
1. **Storage Location** - Products don't have a field for cupboard/fridge
2. **Unit of Measure** - Products don't specify their measurement unit
3. **Structured Adjustment Reasons** - Currently free-text, need predefined categories
4. **Reconciliation Sessions** - No way to track when reconciliations happen
5. **Reconciliation UI** - No interface for performing stock takes

## Implementation Plan

### Phase 1: Data Model Enhancements ✅ COMPLETE

**Status**: ✅ COMPLETED on 2025-11-24
**Branch**: `drugbook`
**Tests**: 56 new tests added (353 total, all passing)
**Migrations**: Development migrations created and applied

#### 1.1 Add Product Attributes ✅
Enhance the `Product` resource with:
- `unit_of_measure` - enum attribute (`:tablets`, `:milliliters`, `:vials`, `:boxes`, `:bottles`, `:syringes`)
- `storage_location` - enum attribute (`:cupboard`, `:fridge`, `:controlled_drugs_cabinet`)
- `active_ingredient` - string (for drug reference, future use)
- `strength` - string (e.g., "500mg", "10mg/mL", for future use)

**Migration**: ✅ Add columns to `products` table
**Tests**: ✅ Update product tests to include new attributes
**Fixtures**: ✅ Update generator to include new fields

**Completed Files**:
- `lib/medishop/products/product.ex` - Added 4 attributes, updated actions
- `test/support/generator.ex` - Updated product generator with defaults
- `priv/repo/migrations/20251124025227_migrate_resources3_dev.exs` - Database migration

#### 1.2 Create StockReconciliation Resource ✅
New resource to track reconciliation sessions:
- `location_id` - which location was reconciled
- `performed_by_user_id` - who performed it (via actor_id from AshEvents)
- `started_at` - when reconciliation began
- `completed_at` - when reconciliation finished
- `status` - enum (`:in_progress`, `:completed`, `:cancelled`)
- `notes` - optional notes about the reconciliation
- `total_items_checked` - count of items checked
- `total_discrepancies` - count of items with discrepancies
- `total_adjustments_made` - count of adjustment events created

**Relationships**:
- `belongs_to :location`
- `has_many :reconciliation_items` (details for each product checked)

**Actions**: ✅
- `create` - start new reconciliation
- `complete` - finalize reconciliation (with require_atomic? false)
- `cancel` - abandon reconciliation (with require_atomic? false)
- `by_location` - view history by location
- `by_status` - filter by status

**Completed Files**:
- `lib/medishop/inventory/stock_reconciliation.ex` - Complete resource implementation
- `lib/medishop/inventory.ex` - Added 9 interface functions
- `test/medishop/inventory/stock_reconciliation_test.exs` - 25 tests ✅
- `test/support/generator.ex` - Added stock_reconciliation generator

#### 1.3 Create ReconciliationItem Resource ✅
Track individual product checks within a reconciliation:
- `reconciliation_id` - parent session
- `product_id` - which product
- `location_inventory_id` - the inventory record
- `system_quantity` - what system showed at time of check
- `physical_quantity` - what was physically counted
- `discrepancy` - calculated (physical - system)
- `adjustment_reason` - enum (structured reasons)
- `adjustment_notes` - additional free-text explanation
- `inventory_event_id` - link to created adjustment event (if discrepancy exists)

**Adjustment Reason Enum**:
- `:training_stock` - Used for training purposes
- `:breakage` - Physical damage/breakage
- `:expired` - Past expiration date
- `:theft` - Suspected theft or loss
- `:count_error` - Previous counting error
- `:system_error` - System data entry error
- `:spillage` - Spilled or contaminated
- `:other` - Other reason (requires notes)

**Relationships**:
- `belongs_to :reconciliation`
- `belongs_to :product`
- `belongs_to :location_inventory`
- `belongs_to :inventory_event` (the adjustment that was created)

**Calculations**:
- `discrepancy` - calculated as `physical_quantity - system_quantity`
- `has_discrepancy` - boolean, true if discrepancy != 0

**Actions**: ✅
- `create` - record a product check
- `update` - modify before reconciliation is completed (with smart validation)
- `bulk_create` - create multiple items at once
- `by_reconciliation` - get all items for a reconciliation
- `with_discrepancies` - filter items with discrepancies

**Completed Files**:
- `lib/medishop/inventory/reconciliation_item.ex` - Complete resource implementation with validations
- `lib/medishop/inventory.ex` - Added 9 interface functions
- `test/medishop/inventory/reconciliation_item_test.exs` - 31 tests ✅
- `test/support/generator.ex` - Added reconciliation_item generator

**Key Implementation Details**:
- Validation only requires adjustment_reason when creating new discrepancy (not on all updates)
- `inventory_event_id` is optional and set during Phase 2 workflow
- Calculations for `discrepancy` and `has_discrepancy` implemented
- Unique constraint prevents duplicate items per reconciliation

---

## Phase 1 Summary

**Total Implementation**:
- 3 resources enhanced/created (Product, StockReconciliation, ReconciliationItem)
- 18 new code interface functions
- 2 new database tables created
- 4 new columns added to products table
- 56 new tests (353 total, 100% passing)
- 3 test generators added/updated
- Complete data foundation for stock reconciliation feature

**Branch**: `drugbook`
**Status**: ✅ COMPLETE
**Completed**: 2025-11-24

---

### Phase 2: Business Logic

#### 2.1 Reconciliation Workflow
1. **Start Reconciliation**
   - User navigates to location inventory page
   - Clicks "Start Stock Take" button
   - System creates `StockReconciliation` record with `:in_progress` status
   - System loads all `LocationInventory` records for the location
   - UI presents stock take interface

2. **Record Physical Counts**
   - User sees list of all products with current system quantities
   - User can filter by storage location (cupboard/fridge)
   - User enters physical count for each item
   - System auto-calculates discrepancy on input
   - If discrepancy exists, user must select reason category
   - Optional: user adds additional notes

3. **Review Discrepancies**
   - System shows summary of all items checked
   - Highlights items with discrepancies
   - Shows total count of discrepancies
   - User can edit counts/reasons before finalizing

4. **Complete Reconciliation**
   - User clicks "Complete Stock Take"
   - System validates all discrepancies have reasons
   - System creates `InventoryEvent` (type: `:adjustment`) for each discrepancy
   - System updates `StockReconciliation` status to `:completed`
   - System sets `completed_at` timestamp
   - System calculates summary statistics
   - UI shows confirmation with summary

#### 2.2 Adjustment Event Creation
When reconciliation is completed:
- For each `ReconciliationItem` with discrepancy:
  - Create `InventoryEvent` with:
    - `event_type`: `:adjustment`
    - `quantity_change`: the discrepancy amount (can be positive or negative)
    - `reason`: formatted string combining reason category and notes
    - `reference_type`: "StockReconciliation"
    - `reference_id`: the reconciliation session ID
    - `occurred_at`: the reconciliation completion time
  - Update `ReconciliationItem.inventory_event_id` with created event
- LocationInventory current_quantity will automatically update via aggregate

#### 2.3 Authorization
- Only users with `org_admin` or location-level inventory management permission can perform reconciliations
- Users can only reconcile locations they have access to
- Reconciliation history viewable by all location members

### Phase 3: UI Implementation

#### 3.1 Stock Take Interface (`/location/:location_id/reconciliation/new`)
**Components**:
- Header: Location name, storage location filter, progress indicator
- Search bar: Filter products by name/SKU
- Product list table:
  - Column: Product name & SKU
  - Column: Storage location badge (cupboard/fridge)
  - Column: Unit of measure
  - Column: System quantity (read-only)
  - Column: Physical count (input field)
  - Column: Discrepancy (calculated, color-coded)
  - Column: Reason (dropdown, shown if discrepancy)
  - Column: Notes (textarea, optional)
- Footer: Summary stats, Cancel button, Save & Continue button

**Features**:
- Auto-save to draft (store in LiveView state or DB)
- Inline discrepancy highlighting (red for negative, green for positive)
- Required field validation (reason required if discrepancy exists)
- Mobile-responsive layout

#### 3.2 Review & Confirm Screen (`/location/:location_id/reconciliation/:id/review`)
**Components**:
- Summary card:
  - Total items checked
  - Items with discrepancies
  - Total adjustment amount (net change)
- Discrepancies table (filtered view of items with discrepancies only):
  - Product details
  - System vs Physical quantities
  - Discrepancy amount
  - Reason category
  - Notes
  - Edit button (returns to stock take interface)
- Action buttons:
  - Go Back (edit more items)
  - Complete Stock Take (finalize)

#### 3.3 Reconciliation History (`/location/:location_id/reconciliation/history`)
**Components**:
- List of past reconciliations:
  - Date & time
  - Performed by (user name)
  - Items checked / Discrepancies found
  - Status badge
  - View Details link
- Filters: Date range, performed by user

#### 3.4 Reconciliation Detail View (`/location/:location_id/reconciliation/:id`)
**Components**:
- Session metadata (date, user, duration)
- Summary statistics
- Full list of reconciliation items (all products checked)
- Links to created inventory events
- Print/Export button (PDF or CSV)

### Phase 4: Testing

#### 4.1 Unit Tests
**Resource Tests**:
- `test/medishop/inventory/stock_reconciliation_test.exs`
  - Create reconciliation
  - Complete reconciliation workflow
  - Cancel reconciliation
  - List reconciliations by location
  - Validate status transitions

- `test/medishop/inventory/reconciliation_item_test.exs`
  - Create reconciliation item
  - Discrepancy calculation
  - Adjustment reason validation
  - Link to inventory event

**Integration Tests**:
- `test/medishop/inventory/reconciliation_workflow_test.exs`
  - Full reconciliation flow from start to completion
  - Verify inventory events created correctly
  - Verify LocationInventory quantities updated
  - Test multiple discrepancies in one session
  - Test reconciliation with no discrepancies

#### 4.2 LiveView Tests
- `test/medishop_web/live/stock_take_live_test.exs`
  - Authentication/authorization
  - Product list rendering
  - Physical count input
  - Discrepancy calculation
  - Reason selection
  - Form validation
  - Save and complete workflow

- `test/medishop_web/live/reconciliation_history_live_test.exs`
  - List past reconciliations
  - View reconciliation details
  - Filter by date/user

### Phase 5: Additional Features (Future Enhancements)

#### 5.1 Scheduled Reconciliations
- System prompts for regular stock takes (weekly/monthly)
- Notifications for overdue reconciliations

#### 5.2 Partial Reconciliations
- Allow checking only specific items (e.g., just fridge items)
- Track which items were checked vs skipped

#### 5.3 Mobile Scanning
- Barcode scanner integration for faster data entry
- Mobile-optimized UI for stock takes

#### 5.4 Analytics & Reporting
- Discrepancy trends over time
- Most frequently adjusted items
- Reconciliation frequency metrics

#### 5.5 Multi-User Reconciliation
- Support multiple users performing counts simultaneously
- Blind count verification (two users count independently)

## Database Schema Changes

### New Tables

#### `stock_reconciliations`
```sql
CREATE TABLE stock_reconciliations (
  id UUID PRIMARY KEY,
  location_id UUID NOT NULL REFERENCES locations(id),
  status VARCHAR(20) NOT NULL CHECK (status IN ('in_progress', 'completed', 'cancelled')),
  started_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  notes TEXT,
  total_items_checked INTEGER DEFAULT 0,
  total_discrepancies INTEGER DEFAULT 0,
  total_adjustments_made INTEGER DEFAULT 0,
  actor_id UUID REFERENCES users(id), -- from AshEvents
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_stock_reconciliations_location_id ON stock_reconciliations(location_id);
CREATE INDEX idx_stock_reconciliations_status ON stock_reconciliations(status);
CREATE INDEX idx_stock_reconciliations_started_at ON stock_reconciliations(started_at);
```

#### `reconciliation_items`
```sql
CREATE TABLE reconciliation_items (
  id UUID PRIMARY KEY,
  reconciliation_id UUID NOT NULL REFERENCES stock_reconciliations(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  location_inventory_id UUID NOT NULL REFERENCES location_inventories(id),
  system_quantity INTEGER NOT NULL,
  physical_quantity INTEGER NOT NULL,
  discrepancy INTEGER GENERATED ALWAYS AS (physical_quantity - system_quantity) STORED,
  adjustment_reason VARCHAR(50) CHECK (adjustment_reason IN (
    'training_stock', 'breakage', 'expired', 'theft', 'count_error',
    'system_error', 'spillage', 'other'
  )),
  adjustment_notes TEXT,
  inventory_event_id UUID REFERENCES inventory_events(id),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_reconciliation_items_reconciliation_id ON reconciliation_items(reconciliation_id);
CREATE INDEX idx_reconciliation_items_product_id ON reconciliation_items(product_id);
CREATE UNIQUE INDEX idx_reconciliation_items_unique_product ON reconciliation_items(reconciliation_id, product_id);
```

### Modified Tables

#### `products` (add columns)
```sql
ALTER TABLE products
  ADD COLUMN unit_of_measure VARCHAR(20) CHECK (unit_of_measure IN (
    'tablets', 'milliliters', 'vials', 'boxes', 'bottles', 'syringes'
  )),
  ADD COLUMN storage_location VARCHAR(30) CHECK (storage_location IN (
    'cupboard', 'fridge', 'controlled_drugs_cabinet'
  )),
  ADD COLUMN active_ingredient VARCHAR(255),
  ADD COLUMN strength VARCHAR(50);
```

## Code Interface Functions

### Inventory Domain (`lib/medishop/inventory.ex`)
Add new interface functions:

```elixir
# Stock Reconciliation
define :create_reconciliation, action: :create
define :get_reconciliation, action: :read, get_by: [:id]
define :list_reconciliations_by_location, action: :by_location
define :complete_reconciliation, action: :complete
define :cancel_reconciliation, action: :cancel

# Reconciliation Items
define :create_reconciliation_item, action: :create
define :bulk_create_reconciliation_items, action: :bulk_create
define :get_reconciliation_items, action: :read
define :update_reconciliation_item, action: :update
```

## Implementation Phases Summary

| Phase | Description | Status | Completed | Dependencies |
|-------|-------------|--------|-----------|--------------|
| Phase 1 | Data Model Enhancements | ✅ COMPLETE | 2025-11-24 | None |
| Phase 2 | Business Logic | 📋 Planned | - | Phase 1 |
| Phase 3 | UI Implementation | 📋 Planned | - | Phase 1, 2 |
| Phase 4 | Testing | 📋 Planned | - | Phase 1, 2, 3 |
| Phase 5 | Future Enhancements | 📋 Planned | - | Phase 1-4 complete |

**Phase 1 Complete**: 56 new tests, 353 total passing, full data model implementation
**Remaining MVP**: Phases 2-4 (Business Logic, UI, Integration Testing)

## Success Metrics

1. **Accuracy**: Digital inventory matches physical inventory after reconciliation
2. **Adoption**: Location admins perform regular stock takes (weekly/monthly)
3. **Discrepancy Tracking**: System captures and categorizes all discrepancies
4. **Audit Compliance**: Complete audit trail of all reconciliations
5. **User Experience**: Stock take process takes < 15 minutes for typical location

## Technical Considerations

### Concurrency
- Only one active reconciliation per location at a time
- Prevent inventory modifications during active reconciliation (or show warning)

### Performance
- Efficient loading of all location inventory items (optimize query)
- Consider pagination for locations with 100+ products
- Auto-save draft to prevent data loss

### Data Integrity
- Reconciliation completion must be atomic (all adjustments succeed or none)
- Use database transactions for creating adjustment events
- Validate system_quantity hasn't changed since reconciliation started

### User Experience
- Clear visual feedback for discrepancies
- Progress tracking (X of Y items counted)
- Keyboard shortcuts for rapid data entry
- Mobile-friendly interface for tablets

## Next Steps

1. Review and approve this plan
2. Generate development migrations for Phase 1 schema changes
3. Implement StockReconciliation resource with tests
4. Implement ReconciliationItem resource with tests
5. Update Product resource with new attributes
6. Build reconciliation workflow logic
7. Create stock take UI
8. Comprehensive testing
9. User acceptance testing
10. Generate production migrations and commit

## Questions for Stakeholder Review

1. Are there additional adjustment reasons we should support?
2. Should we support partial reconciliations (only counting some items)?
3. Do we need approval workflow (manager must approve adjustments)?
4. Should reconciliations be mandatory on a schedule?
5. Do we need to track batch/lot numbers during reconciliation?
6. Should we support multiple storage locations per product?
