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

## Acceptance Criteria

### Products Domain
- [ ] Products can be created with title, SKU, description, images (array), and price
- [ ] Products can be searched and filtered
- [ ] Products have unique SKUs
- [ ] Product images stored as array of URLs/paths

### Inventory Domain
- [ ] Each location can have inventory records for products
- [ ] Inventory tracks quantity_available per product per location
- [ ] Inventory records are unique per location+product combination

### Shop Domain
- [ ] Each location has exactly one cart (singleton pattern)
- [ ] Cart items can be added/updated/removed with quantity
- [ ] Orders can be created from cart with status tracking
- [ ] Order captures: location, purchasing user, organization (via location), items, total
- [ ] Order status: `:pending`, `:confirmed`, `:shipped`, `:delivered`, `:cancelled`

### Authorization
- [ ] Only users with `org_buyer` role for a location's organization can manage that location's cart
- [ ] Only users with `org_buyer` role can create orders

---

## Implementation Steps

### Phase 1: Products Domain (Foundation)

#### Step 1: Create Products Domain Structure
**Effort:** Small
**Dependencies:** None

- [ ] Create `lib/medishop/products.ex` domain module
- [ ] Create `lib/medishop/products/product.ex` resource
- [ ] Add to domain configuration
- [ ] Set up AshPostgres data layer

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

#### Step 2: Add Product Search Capabilities
**Effort:** Small
**Dependencies:** Step 1

- [ ] Add custom read action `:search` with arguments for filtering
- [ ] Support search by: title (partial match), SKU (exact), active status
- [ ] Add sorting options (title, price, created_at)
- [ ] Define `search_products` interface function

#### Step 3: Create Product Test Suite
**Effort:** Small
**Dependencies:** Step 1

- [ ] Create `test/medishop/products/product_test.exs`
- [ ] Test product creation with all attributes
- [ ] Test SKU uniqueness constraint
- [ ] Test search functionality
- [ ] Test price validation (must be positive)
- [ ] Create product fixtures in `test/support/products_fixtures.ex`

#### Step 4: Generate Product Migration
**Effort:** Small
**Dependencies:** Step 1

- [ ] Run `mix ash_postgres.generate_migrations`
- [ ] Review migration for products table
- [ ] Run migration

---

### Phase 2: Inventory Domain (Location Stock)

#### Step 5: Create Inventory Domain Structure
**Effort:** Small
**Dependencies:** Step 4 (needs Products domain)

- [ ] Create `lib/medishop/inventory.ex` domain module
- [ ] Create `lib/medishop/inventory/location_inventory.ex` resource
- [ ] Add to domain configuration
- [ ] Set up AshPostgres data layer

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

#### Step 6: Add Inventory Relationships to Existing Resources
**Effort:** Small
**Dependencies:** Step 5

- [ ] Add `has_many :location_inventories` to `Organizations.Location`
- [ ] Add `has_many :location_inventories` to `Products.Product`
- [ ] Update CLAUDE.md with inventory domain information

#### Step 7: Create Inventory Test Suite
**Effort:** Small
**Dependencies:** Step 5

- [ ] Create `test/medishop/inventory/location_inventory_test.exs`
- [ ] Test inventory creation for location+product
- [ ] Test unique constraint enforcement
- [ ] Test quantity_available updates
- [ ] Test relationships to location and product
- [ ] Create inventory fixtures in `test/support/inventory_fixtures.ex`

#### Step 8: Generate Inventory Migration
**Effort:** Small
**Dependencies:** Step 5

- [ ] Run `mix ash_postgres.generate_migrations`
- [ ] Review migration for location_inventories table
- [ ] Verify foreign keys and unique constraint
- [ ] Run migration

---

### Phase 3: Shop Domain (Carts & Orders)

#### Step 9: Create Shop Domain with Cart Resource
**Effort:** Medium
**Dependencies:** Step 8 (needs Products and Inventory)

- [ ] Create `lib/medishop/shop.ex` domain module
- [ ] Create `lib/medishop/shop/cart.ex` resource
- [ ] Implement singleton pattern (one cart per location)

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

#### Step 10: Create CartItem Resource
**Effort:** Medium
**Dependencies:** Step 9

- [ ] Create `lib/medishop/shop/cart_item.ex` resource

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

#### Step 11: Create Order Resource
**Effort:** Medium
**Dependencies:** Step 10

- [ ] Create `lib/medishop/shop/order.ex` resource

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

#### Step 12: Create OrderItem Resource
**Effort:** Small
**Dependencies:** Step 11

- [ ] Create `lib/medishop/shop/order_item.ex` resource

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

#### Step 13: Add Shop Relationships to Existing Resources
**Effort:** Small
**Dependencies:** Step 12

- [ ] Add `has_one :cart` to `Organizations.Location`
- [ ] Add `has_many :orders` to `Organizations.Location`
- [ ] Add `has_many :orders` to `Accounts.User`
- [ ] Add `has_many :cart_items` to `Products.Product`
- [ ] Add `has_many :order_items` to `Products.Product`
- [ ] Update CLAUDE.md with shop domain information

#### Step 14: Create Shop Test Suite
**Effort:** Large
**Dependencies:** Step 13

Test files to create:
- [ ] `test/medishop/shop/cart_test.exs`
  - Test singleton pattern (one cart per location)
  - Test cart creation and clearing

- [ ] `test/medishop/shop/cart_item_test.exs`
  - Test adding items to cart
  - Test updating quantities
  - Test unique constraint (cart+product)
  - Test line_total calculation
  - Test removing items

- [ ] `test/medishop/shop/order_test.exs`
  - Test order creation from cart
  - Test order_number generation and uniqueness
  - Test status transitions
  - Test status timestamp updates
  - Test subtotal/total calculations
  - Test querying orders by location/user

- [ ] `test/medishop/shop/order_item_test.exs`
  - Test order items created from cart
  - Test immutability (no updates after creation)
  - Test line_total calculation

- [ ] Create fixtures in `test/support/shop_fixtures.ex`

#### Step 15: Generate Shop Migrations
**Effort:** Small
**Dependencies:** Step 13

- [ ] Run `mix ash_postgres.generate_migrations`
- [ ] Review migrations for: carts, cart_items, orders, order_items tables
- [ ] Verify all foreign keys, unique constraints, and indexes
- [ ] Run migrations

---

### Phase 4: Integration & Polish

#### Step 16: Add Authorization Policies
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
- [ ] Add Ash.Policy.Authorizer to Shop resources
- [ ] Define policies using organization membership checks
- [ ] Test authorization in test suite

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

- [ ] **Phase 1: Products Domain** (Steps 1-4)
- [ ] **Phase 2: Inventory Domain** (Steps 5-8)
- [ ] **Phase 3: Shop Domain** (Steps 9-15)
- [ ] **Phase 4: Integration & Polish** (Steps 16-18)

### Current Status

**Current Step:** None (not started)
**Blockers:** None
**Notes:** Awaiting answers to clarifying questions before starting implementation

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
