# Implementation Plan: Medication Purchasing System

**Status:** Not Started
**Created:** 2025-11-22
**Estimated Effort:** 2-3 days of focused work

---

## High-Level Summary

We'll implement a medication purchasing system with three new domains:
1. **Products Domain**: Manages product catalog (medications) with basic information
2. **Inventory Domain**: Tracks product availability per location
3. **Shop Domain**: Handles carts and order processing

The system will allow users with `org_buyer` role to browse products, add them to a location's cart, and place orders. Initial implementation focuses on core functionality with notes for future enhancements.

---

## Testing Requirements ⚠️ MANDATORY

**All functionality must be tested before implementation is considered complete.**

Per `docs/instructions/04-testing-and-quality.md`:

### Test-Driven Development (TDD) Approach
1. **Write the test first** - Define expected behavior
2. **Watch it fail** - Confirms test is valid
3. **Write minimum code** - Make the test pass
4. **Refactor** - Improve code with test safety net

### Test Coverage Requirements
- ✅ **Every resource** must have a test file
- ✅ **Every action** must be tested (create, read, update, destroy, custom actions)
- ✅ **Every validation** must be tested (positive and negative cases)
- ✅ **Every relationship** must be tested (belongs_to, has_many, has_one)
- ✅ **Every calculation** must be tested
- ✅ **Every authorization policy** must be tested
- ✅ **Every unique constraint** must be tested
- ✅ **Edge cases** must be tested

### Quality Gates (Before Each Commit)
```bash
mix format              # Format code
mix test                # All tests must pass
mix credo --strict      # Code quality (when available)
```

### Test Organization
- Unit tests: `test/medishop/<domain>/<resource>_test.exs`
- Fixtures: `test/support/<domain>_fixtures.ex`
- Follow existing test patterns in the codebase

---

## Acceptance Criteria

### Products Domain
- [ ] Products can be created with title, SKU, description, images (array), and price
- [ ] Products can be searched and filtered
- [ ] Products have unique SKUs
- [ ] Product images stored as array of URLs/paths
- [ ] **All product functionality has passing tests**

### Inventory Domain
- [ ] Each location can have inventory records for products
- [ ] Inventory tracks quantity_available per product per location
- [ ] Inventory records are unique per location+product combination
- [ ] **All inventory functionality has passing tests**

### Shop Domain
- [ ] Each location has exactly one cart (singleton pattern)
- [ ] Cart items can be added/updated/removed with quantity
- [ ] Orders can be created from cart with status tracking
- [ ] Order captures: location, purchasing user, organization (via location), items, total
- [ ] Order status: `:pending`, `:confirmed`, `:shipped`, `:delivered`, `:cancelled`
- [ ] **All shop functionality has passing tests**

### Authorization
- [ ] Only users with `org_buyer` role for a location's organization can manage that location's cart
- [ ] Only users with `org_buyer` role can create orders
- [ ] **All authorization policies have passing tests**

### Quality
- [ ] All tests pass (`mix test`)
- [ ] Code is formatted (`mix format`)
- [ ] No compilation warnings

---

## Implementation Steps

### Phase 1: Products Domain (Foundation)

#### Step 1: Create Products Domain Structure ✅ COMPLETED
**Effort:** Small
**Dependencies:** None

- [x] Create `lib/medishop/products.ex` domain module
- [x] Create `lib/medishop/products/product.ex` resource
- [x] Add to domain configuration
- [x] Set up AshPostgres data layer

**Product Attributes:**
- `id` (uuid, primary key)
- `sku` (string, unique, required) - product identifier
- `title` (string, required) - product name
- `description` (text, optional) - detailed description
- `images` (array of strings, default: []) - image URLs/paths
- `price` (decimal, required) - price in dollars
- `active` (boolean, default: true) - whether product is available for purchase
- `created_at`, `updated_at` (timestamps)

**Actions:**
- `create`, `read`, `update`, `destroy`
- `search` - custom read action with search filters

**Code Interface:**
- Define interface functions in domain module

#### Step 2: Add Product Search Capabilities ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 1

- [x] Add custom read action `:search` with arguments for filtering
- [x] Support search by: title (partial match), SKU (exact), active status
- [x] Add sorting options (title, price, created_at)
- [x] Define `search_products` interface function

#### Step 3: Create Product Test Suite ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 1

**Test File:** `test/medishop/products/product_test.exs`

**Required Tests:**
- [x] Test product creation with all attributes
- [x] Test product creation with minimal attributes
- [x] Test SKU uniqueness constraint (duplicate SKU should fail)
- [x] Test price validation (must be positive, reject zero/negative)
- [x] Test active/inactive products
- [x] Test product update (all attributes)
- [x] Test product deletion
- [x] Test reading products
- [x] Test search by title (partial match, case insensitive)
- [x] Test search by SKU (exact match)
- [x] Test search by active status
- [x] Test sorting (by title, price, created_at)
- [x] Test combining search filters

**Fixtures:** `test/support/products_fixtures.ex`
- [x] Create `product_fixture/1` helper
- [x] Support passing custom attributes
- [x] Generate unique SKUs by default

**Quality Gate:** All tests must pass before proceeding to Step 4 ✅ PASSED (17/17 tests)

#### Step 4: Generate Product Migration ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 1

- [x] Run `mix ash_postgres.generate_migrations`
- [x] Review migration for products table
- [x] Run migration

---

### Phase 2: Inventory Domain (Location Stock)

#### Step 5: Create Inventory Domain Structure ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 4 (needs Products domain)

- [x] Create `lib/medishop/inventory.ex` domain module
- [x] Create `lib/medishop/inventory/location_inventory.ex` resource
- [x] Add to domain configuration
- [x] Set up AshPostgres data layer

**LocationInventory Attributes:**
- `id` (uuid, primary key)
- `location_id` (uuid, required) - belongs to Organizations.Location
- `product_id` (uuid, required) - belongs to Products.Product
- `quantity_available` (integer, default: 0) - current stock level
- `created_at`, `updated_at` (timestamps)

**Relationships:**
- `belongs_to :location, Medishop.Organizations.Location`
- `belongs_to :product, Medishop.Products.Product`

**Identities:**
- Unique constraint on `[:location_id, :product_id]`

**Actions:**
- `create`, `read`, `update`, `destroy`
- `get_by_location` - read action filtered by location
- `get_by_product` - read action filtered by product

**Code Interface:**
- Define interface functions in domain module

**Future Note:** 🔮 Add inventory tracking (decrement on purchase, increment on restock)

#### Step 6: Add Inventory Relationships to Existing Resources ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 5

- [x] Add `has_many :location_inventories` to `Organizations.Location`
- [x] Add `has_many :location_inventories` to `Products.Product`
- [x] Update CLAUDE.md with inventory domain information

#### Step 7: Create Inventory Test Suite ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 5

**Test File:** `test/medishop/inventory/location_inventory_test.exs`

**Required Tests:**
- [x] Test inventory creation for location+product combination
- [x] Test unique constraint (location+product must be unique)
- [x] Test duplicate inventory record creation fails
- [x] Test quantity_available defaults to 0
- [x] Test quantity_available updates
- [x] Test quantity_available can be set to zero
- [x] Test quantity_available validation (must be non-negative)
- [x] Test belongs_to :location relationship
- [x] Test belongs_to :product relationship
- [x] Test get_by_location action (filters correctly)
- [x] Test get_by_product action (filters correctly)
- [x] Test inventory deletion
- [x] Test loading inventory with location preload
- [x] Test loading inventory with product preload

**Fixtures:** `test/support/inventory_fixtures.ex`
- [x] Create `location_inventory_fixture/2` (location_id, product_id)
- [x] Support custom quantity_available
- [x] Use existing location and product fixtures

**Quality Gate:** All tests must pass before proceeding to Step 8 ✅ PASSED (13/13 tests)

#### Step 8: Generate Inventory Migration ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 5

- [x] Run `mix ash_postgres.generate_migrations`
- [x] Review migration for location_inventories table
- [x] Verify foreign keys and unique constraint
- [x] Run migration

---

### Phase 3: Shop Domain (Carts & Orders)

#### Step 9: Create Shop Domain with Cart Resource ✅ COMPLETED
**Effort:** Medium
**Dependencies:** Step 8 (needs Products and Inventory)

- [x] Create `lib/medishop/shop.ex` domain module
- [x] Create `lib/medishop/shop/cart.ex` resource
- [x] Implement singleton pattern (one cart per location)

**Cart Attributes:**
- `id` (uuid, primary key)
- `location_id` (uuid, required, unique) - one cart per location
- `created_at`, `updated_at` (timestamps)

**Relationships:**
- `belongs_to :location, Medishop.Organizations.Location`
- `has_many :cart_items, Medishop.Shop.CartItem`

**Actions:**
- `create`, `read`, `update`, `destroy`
- `get_or_create_for_location` - custom action to get existing cart or create new one
- `clear` - remove all cart items

**Code Interface:**
- `get_or_create_cart_for_location(location_id, opts)`
- `clear_cart(cart, opts)`

**Future Note:** 🔮 Add cart persistence (don't auto-delete old carts)

#### Step 10: Create CartItem Resource ✅ COMPLETED
**Effort:** Medium
**Dependencies:** Step 9

- [x] Create `lib/medishop/shop/cart_item.ex` resource

**CartItem Attributes:**
- `id` (uuid, primary key)
- `cart_id` (uuid, required)
- `product_id` (uuid, required)
- `quantity` (integer, required, default: 1, minimum: 1)
- `price_at_addition` (decimal, required) - snapshot price when added
- `created_at`, `updated_at` (timestamps)

**Relationships:**
- `belongs_to :cart, Medishop.Shop.Cart`
- `belongs_to :product, Medishop.Products.Product`

**Identities:**
- Unique constraint on `[:cart_id, :product_id]`

**Actions:**
- `create`, `read`, `update`, `destroy`
- `add_or_update` - custom action to add new item or update quantity if exists

**Calculations:**
- `line_total` - quantity * price_at_addition

**Code Interface:**
- `add_or_update_cart_item(cart_id, product_id, quantity, opts)`
- `update_cart_item_quantity(cart_item, quantity, opts)`
- `remove_cart_item(cart_item, opts)`

#### Step 11: Create Order Resource ✅ COMPLETED
**Effort:** Medium
**Dependencies:** Step 10

- [x] Create `lib/medishop/shop/order.ex` resource

**Order Attributes:**
- `id` (uuid, primary key)
- `order_number` (string, unique, auto-generated) - human-readable order ID
- `location_id` (uuid, required) - where order is being delivered
- `user_id` (uuid, required) - who placed the order
- `status` (atom enum, required, default: :pending)
  - `:pending`, `:confirmed`, `:shipped`, `:delivered`, `:cancelled`
- `subtotal` (decimal, required) - sum of all line totals
- `total` (decimal, required) - final amount (same as subtotal for now)
- `placed_at` (datetime, default: now) - when order was created
- `confirmed_at`, `shipped_at`, `delivered_at`, `cancelled_at` (datetime, optional)
- `notes` (text, optional) - order notes
- `created_at`, `updated_at` (timestamps)

**Relationships:**
- `belongs_to :location, Medishop.Organizations.Location`
- `belongs_to :user, Medishop.Accounts.User`
- `has_many :order_items, Medishop.Shop.OrderItem`

**Relationships (derived):**
- Get organization via location relationship

**Actions:**
- `create`, `read`, `update`, `destroy`
- `create_from_cart` - custom create action that copies cart items
- `update_status` - custom update action with status transitions
- `get_by_location` - filtered read
- `get_by_user` - filtered read
- `get_by_organization` - filtered read (via location)

**Validations:**
- Status transitions must be valid (e.g., can't go from :delivered to :pending)
- Generate unique order_number on create

**Code Interface:**
- `create_order_from_cart(cart_id, user_id, opts)`
- `update_order_status(order, new_status, opts)`
- `get_orders_for_location(location_id, opts)`
- `get_orders_for_user(user_id, opts)`

**Future Note:** 🔮 Add approval workflows for large orders

#### Step 12: Create OrderItem Resource ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 11

- [x] Create `lib/medishop/shop/order_item.ex` resource

**OrderItem Attributes:**
- `id` (uuid, primary key)
- `order_id` (uuid, required)
- `product_id` (uuid, required)
- `quantity` (integer, required, minimum: 1)
- `unit_price` (decimal, required) - price per unit at time of order
- `line_total` (decimal, required) - quantity * unit_price
- `created_at`, `updated_at` (timestamps)

**Relationships:**
- `belongs_to :order, Medishop.Shop.Order`
- `belongs_to :product, Medishop.Products.Product`

**Actions:**
- `create`, `read` (order items are immutable after creation)

**Code Interface:**
- Minimal - order items created automatically via `create_from_cart`

#### Step 13: Add Shop Relationships to Existing Resources ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 12

- [x] Add `has_one :cart` to `Organizations.Location`
- [x] Add `has_many :orders` to `Organizations.Location`
- [x] Add `has_many :orders` to `Accounts.User`
- [x] Add `has_many :cart_items` to `Products.Product`
- [x] Add `has_many :order_items` to `Products.Product`
- [x] Update CLAUDE.md with shop domain information

#### Step 14: Create Shop Test Suite ✅ COMPLETED
**Effort:** Large
**Dependencies:** Step 13

This is the most critical testing phase. All shop functionality must be thoroughly tested.

**Test File 1:** `test/medishop/shop/cart_test.exs` - 10/10 tests passing ✅

**Required Tests:**
- [x] Test cart creation for location
- [x] Test get_or_create_for_location (creates new cart)
- [x] Test get_or_create_for_location (returns existing cart)
- [x] Test singleton pattern (second create for same location should fail or return existing)
- [x] Test cart has unique location_id
- [x] Test cart belongs_to :location relationship
- [x] Test cart has_many :cart_items relationship
- [x] Test clear cart action (removes all items)
- [x] Test cart deletion
- [x] Test loading cart with items preloaded
- [x] Test loading cart with location preloaded

**Test File 2:** `test/medishop/shop/cart_item_test.exs` - 14/14 tests passing ✅

**Required Tests:**
- [x] Test adding item to cart
- [x] Test add_or_update creates new item
- [x] Test add_or_update updates existing item quantity
- [x] Test cart_item unique constraint (cart+product)
- [x] Test quantity validation (minimum 1)
- [x] Test quantity validation (reject zero)
- [x] Test quantity validation (reject negative)
- [x] Test price_at_addition is captured on creation
- [x] Test price_at_addition doesn't change if product price changes
- [x] Test line_total calculation (quantity * price_at_addition)
- [x] Test update cart item quantity
- [x] Test remove cart item (delete)
- [x] Test cart_item belongs_to :cart relationship
- [x] Test cart_item belongs_to :product relationship
- [x] Test loading cart_item with cart preloaded
- [x] Test loading cart_item with product preloaded

**Test File 3:** `test/medishop/shop/order_test.exs` - 29/29 tests passing ✅

**Required Tests:**
- [x] Test order creation from cart
- [x] Test create_from_cart copies all cart items correctly
- [x] Test create_from_cart calculates subtotal correctly
- [x] Test create_from_cart calculates total correctly
- [x] Test create_from_cart clears cart after order creation
- [x] Test order_number generation (auto-generated)
- [x] Test order_number is unique
- [x] Test order_number format is consistent
- [x] Test order status defaults to :pending
- [x] Test placed_at timestamp is set on creation
- [x] Test status transition: pending → confirmed
- [x] Test status transition: confirmed → shipped
- [x] Test status transition: shipped → delivered
- [x] Test status transition: pending → cancelled
- [x] Test invalid status transition: delivered → pending (should fail)
- [x] Test invalid status transition: cancelled → confirmed (should fail)
- [x] Test confirmed_at timestamp set on status update to :confirmed
- [x] Test shipped_at timestamp set on status update to :shipped
- [x] Test delivered_at timestamp set on status update to :delivered
- [x] Test cancelled_at timestamp set on status update to :cancelled
- [x] Test order belongs_to :location relationship
- [x] Test order belongs_to :user relationship
- [x] Test order has_many :order_items relationship
- [x] Test get_orders_for_location filters correctly
- [x] Test get_orders_for_user filters correctly
- [x] Test get_orders_for_organization filters via location
- [x] Test order with notes
- [x] Test order deletion
- [x] Test loading order with all relationships

**Test File 4:** `test/medishop/shop/order_item_test.exs` - 10/10 tests passing ✅

**Required Tests:**
- [x] Test order item created from cart item
- [x] Test order_item has correct quantity
- [x] Test order_item has correct unit_price
- [x] Test order_item has correct line_total
- [x] Test line_total calculation (quantity * unit_price)
- [x] Test order_item immutability (update should fail)
- [x] Test order_item deletion not allowed after order created
- [x] Test order_item belongs_to :order relationship
- [x] Test order_item belongs_to :product relationship
- [x] Test loading order_item with order preloaded
- [x] Test loading order_item with product preloaded

**Fixtures:** `test/support/shop_fixtures.ex`
- [x] Create `cart_fixture/1` (location_id)
- [x] Create `cart_item_fixture/3` (cart_id, product_id, quantity)
- [x] Create `order_fixture/2` (location_id, user_id)
- [x] Create `order_from_cart_fixture/2` (cart_id, user_id)
- [x] Support custom attributes for all fixtures

**Quality Gate:** All 63 tests passed ✅ (Steps 9-14 complete)

#### Step 15: Generate Shop Migrations ✅ COMPLETED
**Effort:** Small
**Dependencies:** Step 13

- [x] Run `mix ash_postgres.generate_migrations`
- [x] Review migrations for: carts, cart_items, orders, order_items tables
- [x] Verify all foreign keys, unique constraints, and indexes
- [x] Run migrations

---

### Phase 4: Integration & Polish

#### Step 16: Add Authorization Policies ⚠️ TESTS REQUIRED
**Effort:** Medium
**Dependencies:** Step 15

**Cart & CartItem Policies:**
- [ ] Require user to have `org_buyer` role for location's organization
- [ ] Check via OrganizationMembership → OrganizationLocationMembership

**Order Policies:**
- [ ] Require user to have `org_buyer` role for location's organization
- [ ] Users can read their own orders
- [ ] Org admins can read all orders for their organization

**Implementation:**
- [ ] Add Ash.Policy.Authorizer to Cart resource
- [ ] Add Ash.Policy.Authorizer to CartItem resource
- [ ] Add Ash.Policy.Authorizer to Order resource
- [ ] Add Ash.Policy.Authorizer to OrderItem resource
- [ ] Define policies using organization membership checks

**Authorization Tests (add to existing test files):**

`test/medishop/shop/cart_test.exs`:
- [ ] Test authorized user (org_buyer) can access cart
- [ ] Test authorized user (org_buyer) can create cart
- [ ] Test unauthorized user cannot access cart
- [ ] Test unauthorized user cannot create cart
- [ ] Test user from different org cannot access cart
- [ ] Test user without org_buyer role cannot access cart

`test/medishop/shop/cart_item_test.exs`:
- [ ] Test authorized user can add items to cart
- [ ] Test authorized user can update cart items
- [ ] Test authorized user can remove cart items
- [ ] Test unauthorized user cannot add items
- [ ] Test unauthorized user cannot modify items

`test/medishop/shop/order_test.exs`:
- [ ] Test authorized user (org_buyer) can create order
- [ ] Test unauthorized user cannot create order
- [ ] Test user can read their own orders
- [ ] Test user cannot read other users' orders (different org)
- [ ] Test org_admin can read all orders for their organization
- [ ] Test org_member cannot read orders (not org_buyer)
- [ ] Test authorized user can update order status
- [ ] Test unauthorized user cannot update order status

**Quality Gate:** All authorization tests must pass before proceeding to Step 17

**Future Note:** 🔮 Add more granular permissions and approval workflows

#### Step 17: Update Seeds File
**Effort:** Small
**Dependencies:** Step 16

- [ ] Add sample products (10-15 medications) to `priv/repo/seeds.exs`
- [ ] Create inventory for products at existing locations
- [ ] Create a sample cart with items for one location
- [ ] Create a sample order with completed status

#### Step 18: Update Documentation
**Effort:** Small
**Dependencies:** Step 17

- [ ] Update `CLAUDE.md` with Products, Inventory, and Shop domains
- [ ] Explain cart singleton pattern in CLAUDE.md
- [ ] Document order status workflow in CLAUDE.md
- [ ] Note future enhancements with 🔮 markers
- [ ] Update `CHANGELOG.md` with medication purchasing system entry
- [ ] Update `docs/PROGRESS.md` with completion status

---

## Progress Tracking

### Phase Completion

- [x] **Phase 1: Products Domain** (Steps 1-4) - All tests must pass ✅ **COMPLETED**
- [x] **Phase 2: Inventory Domain** (Steps 5-8) - All tests must pass ✅ **COMPLETED**
- [x] **Phase 3: Shop Domain** (Steps 9-15) - All tests must pass ✅ **COMPLETED**
- [ ] **Phase 4: Integration & Polish** (Steps 16-18) - All tests must pass ✅

### Test Status Summary

Track overall test progress here:

**Products Domain:**
- [x] Product tests: 17/17 passing ✅
- [x] Product fixtures created ✅

**Inventory Domain:**
- [x] Inventory tests: 13/13 passing ✅
- [x] Inventory fixtures created ✅

**Shop Domain:**
- [x] Cart tests: 10/10 passing ✅
- [x] CartItem tests: 14/14 passing ✅
- [x] Order tests: 29/29 passing ✅
- [x] OrderItem tests: 10/10 passing ✅
- [x] Shop fixtures created ✅

**Authorization:**
- [ ] Cart authorization tests: 0/6 passing
- [ ] CartItem authorization tests: 0/5 passing
- [ ] Order authorization tests: 0/8 passing

**Total:** 93/113+ tests passing (82% complete - Phases 1-3 done, Phase 4 pending)

### Current Status

**Current Step:** Phase 4 - Integration & Polish (Steps 16-18)
**Blockers:** None
**Notes:** Phases 1, 2, and 3 complete. Ready to start Phase 4 (Authorization & Documentation).

**Completed:**
- ✅ Phase 1: Products Domain (17 tests passing)
- ✅ Phase 2: Inventory Domain (13 tests passing)
- ✅ Phase 3: Shop Domain (63 tests passing)
  - ✅ Cart resource with singleton pattern (10 tests)
  - ✅ CartItem resource with price snapshots (14 tests)
  - ✅ Order resource with status workflow (29 tests)
  - ✅ OrderItem resource (immutable) (10 tests)
  - ✅ All code interfaces defined (50+ functions)
  - ✅ All relationships established
  - ✅ Shop fixtures with comprehensive helpers
  - ✅ Development migrations generated and run

**Testing Note:** All 63 Shop domain tests passing (100%). Ready for Phase 4 authorization policies.

---

## Effort Summary

| Phase | Steps | Estimated Effort |
|-------|-------|------------------|
| Phase 1: Products | Steps 1-4 | Small (4 steps) |
| Phase 2: Inventory | Steps 5-8 | Small (4 steps) |
| Phase 3: Shop | Steps 9-15 | Medium-Large (7 steps) |
| Phase 4: Integration | Steps 16-18 | Small-Medium (3 steps) |
| **Total** | **18 steps** | **~2-3 days of focused work** |

---

## Potential Risks & Dependencies

### Technical Risks
1. **Cart Singleton Pattern:** Need to ensure one cart per location is properly enforced at database and application level
2. **Order Number Generation:** Must be unique and handle race conditions
3. **Status Transitions:** Need clear validation for which status changes are allowed
4. **Authorization Complexity:** Checking org_buyer + location_membership may require complex queries

### Dependencies
- Steps must be completed in order within each phase
- Phase 2 depends on Phase 1 (needs Products)
- Phase 3 depends on Phases 1 & 2 (needs Products and Inventory)
- Phase 4 depends on Phase 3 (integration of all domains)

---

## Future Enhancements (Noted for Later)

- 🔮 **Cart Persistence:** Don't auto-delete carts; allow users to save them
- 🔮 **Inventory Tracking:** Decrement inventory on purchase, prevent overselling
- 🔮 **Inventory Reservations:** Reserve items when in cart
- 🔮 **Product Variants:** Support different sizes, quantities, formulations
- 🔮 **Product Categories:** Organize products (prescription vs OTC, therapeutic categories)
- 🔮 **Location-Specific Pricing:** Different prices per location
- 🔮 **Location-Specific Availability:** Products available at some locations only
- 🔮 **Subscriptions:** Recurring orders for maintenance medications
- 🔮 **Approval Workflows:** Require approval for large orders
- 🔮 **Payment Processing:** Integrate actual payment gateway
- 🔮 **Multi-Location Orders:** Allow ordering from multiple locations in one transaction
- 🔮 **Order Fulfillment Tracking:** Integration with shipping/delivery services
- 🔮 **Product Search Enhancements:** Full-text search, faceted filtering, recommendations

---

## Clarifying Questions (To Be Answered)

1. **Order Number Format:** What format should order numbers have? (e.g., "ORD-2025-00001", "MED-20250122-0001")
2. **Price Precision:** How many decimal places for prices? (2 for USD standard, or more?)
3. **Image Storage:** Where should product images be stored? (S3, local filesystem, CDN?)
4. **Cart Expiry:** Even though temporary, should carts expire after X hours of inactivity?
5. **Order Cancellation:** Who can cancel orders and under what conditions?

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-11-22 | Cart is per location (singleton) | Simplifies initial implementation; can add user-specific carts later |
| 2025-11-22 | No inventory tracking initially | Reduces complexity; focus on core ordering flow first |
| 2025-11-22 | Authorization via org_buyer role | Aligns with existing organization membership model |
| 2025-11-22 | One order per location | Simplifies fulfillment and inventory management |
| 2025-11-22 | No product variants initially | Keeps product model simple; can add variant support later |

---

**Last Updated:** 2025-11-22
