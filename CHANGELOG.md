# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-22

### Fixed
- **Cart Total Updates**: Cart total now updates in real-time when removing items or changing quantities
  - Fixed `CartLive.remove_item/2` to reload cart after removing items
  - Fixed `CartLive.update_quantity/2` to reload cart after quantity changes
  - Total calculation now uses updated `@cart.cart_items` data
- **Non-Store Location Cart Button**: Cart buttons no longer appear on non-store locations
  - Dashboard now only shows cart button for locations with `store=true`
  - Prevents users from accessing cart for warehouse/office locations
- **Product Browsing UX**: Added cart item count badge to ProductsLive
  - "View Cart" button displays badge showing number of items in cart
  - Badge auto-updates after adding products
  - Badge only appears when cart has items (count > 0)
- **Database Duplicates**: Cleared and regenerated seed data to fix duplicate organizations
  - Used `mix ash.reset` to drop and recreate database
  - All seed data regenerated cleanly

### Added (earlier today)

### Added
- **LiveView Admin UI - Phase 5: Shopping Cart & Purchase Flow** (branch: `inventory`)
  - **CartLive** (`/location/:location_id/cart`) - Full cart management interface
    - Authorization checking (org_buyer role required)
    - Empty cart state with "Browse Products" link
    - Cart items table with product details (title, SKU, price, quantity, line total)
    - Quantity controls with +/- buttons (prevents going below 1)
    - Remove individual items from cart
    - Clear entire cart functionality
    - Calculate and display cart total
    - Place order button → redirects to order confirmation
    - Authorization: only users with org_buyer role for location's organization can access
  - **ProductsLive** (`/location/:location_id/products`) - Product browsing interface
    - Display all active products in responsive grid (3 columns on large screens)
    - Product cards with image/placeholder, title, SKU, price, description
    - Search functionality (by product title)
    - Add to cart with success flash messages
    - Links to cart and dashboard
    - Authorization: org_buyer role required
  - **OrderConfirmationLive** (`/orders/:order_id/confirmation`) - Order confirmation page
    - Success message with order number prominently displayed
    - Order details: location, status badge, order date, total
    - Order items table with product details and line totals
    - Subtotal and grand total display
    - Status badges with appropriate colors (pending=warning, confirmed=info, delivered=success)
    - Order notes display (when present)
    - Links to continue shopping or return to dashboard
    - Authorization: only order owner can view their orders
  - **Cart Button on Dashboard**
    - Added cart icon/button to each location card
    - Only visible to users with org_buyer role
    - Links to location-specific cart
  - **Router Updates**
    - Added `/location/:location_id/cart` → CartLive
    - Added `/location/:location_id/products` → ProductsLive
    - Added `/orders/:order_id/confirmation` → OrderConfirmationLive
    - All routes protected by `ash_authentication_live_session`
  - **Comprehensive Test Suite** (51 tests created)
    - `test/medishop_web/live/cart_live_test.exs` - 24 tests
      - Authentication/authorization tests
      - Empty cart display
      - Cart items display with quantities and totals
      - Quantity increment/decrement with validation
      - Remove items and clear cart
      - Place order functionality
    - `test/medishop_web/live/products_live_test.exs` - 16 tests
      - Authentication/authorization tests
      - Active products display
      - Product details rendering
      - Search functionality
      - Add to cart functionality
      - Inactive products filtering
    - `test/medishop_web/live/order_confirmation_live_test.exs` - 11 tests
      - Order display with all details
      - Authorization (order ownership verification)
      - Status badges rendering
      - Order items table display
      - Order notes display
      - Multiple order statuses tested

### Added
- **LiveView Admin UI - Dashboard**
  - Created `DashboardLive` (`/dashboard`) displaying user organizations and locations
  - Implemented detailed organization cards with location access info
  - Added user dropdown menu with "Dashboard" and "Sign Out" options
- **LiveView Admin UI - Phase 1: Authentication UI**
  - Created `HomeLive` at `/` for user sign-in
  - Implemented password-based authentication form with Mishka components
  - Configured authenticated LiveView session in `router.ex`
- **LiveView Tests - Phases 2 & 3 Complete** (branch: `inventory`)
  - Created comprehensive test suite for `DashboardLive` - 18/18 tests passing ✅
  - **Phase 2 (Organizations) - 6 tests:**
    - Test displays user's organizations only
    - Test user roles display (org_admin, org_buyer, org_member)
    - Test active/test organization badges
    - Test users without organizations see appropriate message
  - **Phase 3 (Locations) - 12 tests:**
    - Test displays locations with user access
    - Test location details (address, contact, store badge)
    - Test "No specific location access" message
    - Test relationship preloading (organizations, locations)
  - **Test Infrastructure:**
    - Created `test/medishop_web/live/` directory structure
    - Implemented `LiveViewTestHelpers.log_in_user/2` using `AshAuthentication.Plug.Helpers.store_in_session/2`
    - Added comprehensive test documentation (`test/medishop_web/live/README.md`)
  - **Authentication Setup Solved:**
    - Discovered correct approach: `AshAuthentication.Plug.Helpers.store_in_session/2`
    - Generates JWT token with `AshAuthentication.Jwt.token_for_user/1`
    - Works perfectly with `ash_authentication_live_session` in router
  - Test files: `test/medishop_web/live/dashboard_live_test.exs`
  - Helper module: `test/support/live_view_test_helpers.ex`
  - Updated `docs/08-liveview-admin-ui-plan.md` with test completion status
- **Medication Purchasing System - Phase 1: Products Domain** (branch: `inventory`)
  - Created Products domain (`lib/medishop/products.ex`)
  - Product resource with attributes: sku (unique), title, description, images (array), price, active
  - Product search functionality with filters: title (partial match), SKU (exact), active status
  - Product sorting by title, price, or created_at (asc/desc)
  - Price validation (must be positive, non-zero)
  - Code interface functions for all CRUD operations and search
  - Comprehensive test suite (`test/medishop/products/product_test.exs`) - 17/17 tests passing
  - Product fixtures (`test/support/products_fixtures.ex`)
  - Database migration for products table
  - Configured Products domain in `config/config.exs`

- **Medication Purchasing System - Phase 2: Inventory Domain** (branch: `inventory`)
  - Created Inventory domain (`lib/medishop/inventory.ex`)
  - LocationInventory resource tracking product stock per location
  - Attributes: location_id, product_id, quantity_available (defaults to 0)
  - Unique constraint on location + product combination
  - Quantity validation (must be non-negative)
  - Relationships: belongs_to Location and Product
  - Filter actions: get_by_location, get_by_product
  - Added `has_many :location_inventories` to Location and Product resources
  - Code interface functions for all CRUD operations
  - Comprehensive test suite (`test/medishop/inventory/location_inventory_test.exs`) - 13/13 tests passing
  - Inventory fixtures (`test/support/inventory_fixtures.ex`)
  - Database migration for location_inventories table with foreign keys and unique index
  - Configured Inventory domain in `config/config.exs`

- **Medication Purchasing System - Phase 3: Shop Domain** (branch: `inventory`)
  - Created Shop domain (`lib/medishop/shop.ex`) with 4 core resources
  - **Cart Resource** (`lib/medishop/shop/cart.ex`)
    - Singleton pattern: one cart per location (unique constraint on location_id)
    - Actions: create, read, update, destroy, get_or_create_for_location, clear
    - Relationships: belongs_to :location, has_many :cart_items
    - Clear action removes all cart items
  - **CartItem Resource** (`lib/medishop/shop/cart_item.ex`)
    - Attributes: quantity (min: 1), price_at_addition (price snapshot)
    - Unique constraint on [cart_id, product_id]
    - Actions: create, read, update, destroy, add_or_update
    - Calculation: line_total (quantity * price_at_addition)
    - Relationships: belongs_to :cart, belongs_to :product
  - **Order Resource** (`lib/medishop/shop/order.ex`)
    - Auto-generated unique order numbers (format: ORD-YYYYMMDD-XXXXXX)
    - Status workflow with validation: pending → confirmed → shipped → delivered (with cancel option)
    - Timestamp tracking: placed_at, confirmed_at, shipped_at, delivered_at, cancelled_at
    - Actions: create, read, update, destroy, create_from_cart, update_status, get_by_location, get_by_user
    - Relationships: belongs_to :location, belongs_to :user, has_many :order_items
    - Custom create_from_cart action: copies cart items, calculates totals, clears cart
  - **OrderItem Resource** (`lib/medishop/shop/order_item.ex`)
    - Immutable (read-only after creation, no update/destroy actions)
    - Attributes: quantity, unit_price, line_total (all captured at order time)
    - Relationships: belongs_to :order, belongs_to :product
  - Added 50+ code interface functions to Shop domain
  - Added relationships to existing resources:
    - Location: has_one :cart, has_many :orders
    - User: has_many :orders
    - Product: has_many :cart_items, has_many :order_items
  - Comprehensive test suite (63 tests, all passing):
    - `test/medishop/shop/cart_test.exs` - 10/10 tests passing
    - `test/medishop/shop/cart_item_test.exs` - 14/14 tests passing
    - `test/medishop/shop/order_test.exs` - 29/29 tests passing
    - `test/medishop/shop/order_item_test.exs` - 10/10 tests passing
  - Shop fixtures (`test/support/shop_fixtures.ex`) with comprehensive test helpers
  - Database migrations for carts, cart_items, orders, order_items tables
  - Configured Shop domain in `config/config.exs`

- **Implementation Planning and Progress Tracking**
  - Created detailed 18-step implementation plan (`docs/medication-purchasing-implementation-plan.md`)
  - Documented three new domains: Products, Inventory, and Shop
  - Defined acceptance criteria and phase breakdown
  - Emphasized mandatory testing requirements (TDD approach)
  - Updated progress tracking: Phases 1, 2, and 3 completed (Steps 1-15)
  - All checklist items for Steps 1-15 marked as completed

### Changed
- Updated `docs/PROGRESS.md` with Phase 1, Phase 2, and Phase 3 completion details
- Updated `docs/08-liveview-admin-ui-plan.md` marking Phases 2 & 3 tests as complete
- Test summary now shows 148/148 tests passing (100% pass rate)
  - Organizations: 37/37 tests ✅
  - Products: 17/17 tests ✅
  - Inventory: 13/13 tests ✅
  - Shop: 63/63 tests ✅
  - LiveView (Dashboard): 18/18 tests ✅

### Fixed
- **Database & Seeds Repair**
  - Restored missing database migrations for Organizations and Locations
  - Added `hashed_password` column to users table (fixed in initial migration)
  - Updated seeds to generate users with known password "password" for testing
  - Fixed `Medishop.Accounts` code interface for user registration

### Technical Notes
- Following Ash Framework 3.0 best practices and code interface pattern
- All functionality thoroughly tested before implementation marked complete
- Database migrations generated with `mix ash_postgres.generate_migrations`
- Production migrations finalized with `mix ash.codegen --name add_products_and_inventory`
- All snapshots verified and up to date (no changes detected)
- Next phase: Shop Domain (Carts and Orders) - Steps 9-15

## 2025-11-21

### Added
- **Organizations and Locations Feature** (branch: `organisations`)
  - Created Organizations domain (`lib/medishop/organizations.ex`)
  - Organization resource with attributes: name, active, is_test_organization, invoice_email, billing_address, tax_id
  - Location resource with multitenancy support and attributes: name, address, contact_number, store, test_location
  - OrganizationMembership join table linking users to organizations with roles (org_admin, org_member, org_buyer)
  - OrganizationLocationMembership join table assigning users to specific locations
  - OrgRole enum type for organization roles
  - Relationships between Users, Organizations, Locations, and Memberships
  - Development migrations for all new tables
  - Comprehensive seed data in `priv/repo/seeds.exs`:
    - 3 test users (admin, buyer, member)
    - 3 organizations (Acme Medical Supply, Global Health Partners, Test Organization)
    - 5 locations across organizations
    - 4 organization memberships with different roles
    - 3 location memberships for purchasing permissions
  - Configured Organizations domain in `config/config.exs`
  - Simple authorization policies (to be enhanced later)
  - Test files for all resources (`test/medishop/organizations/`)
  - OrganizationsFixtures module for test helpers (`test/support/organizations_fixtures.ex`)

  **Data Model**:
  ```
  User → OrganizationMembership → Organization → Location
                    ↓
        OrganizationLocationMembership → Location
  ```

- **Code Interface Pattern Implementation**
  - Added domain-level code interfaces for all Organizations resources in `lib/medishop/organizations.ex`
  - Created interface functions for Organization: `create_organization/1`, `list_organizations/0`, `get_organization/1`, `update_organization/2`, `destroy_organization/1`
  - Created interface functions for Location: `create_location/1`, `list_locations/0`, `get_location/1`, `get_locations_by_organization/1`, `update_location/2`, `destroy_location/1`
  - Created interface functions for OrganizationMembership: `create_membership/2`, `list_memberships/0`, `get_membership/1`, `get_memberships_for_user/1`, `get_memberships_for_organization/1`, `update_membership/2`, `destroy_membership/1`
  - Created interface functions for OrganizationLocationMembership: `create_location_membership/2`, `list_location_memberships/0`, `get_location_membership/1`, `get_location_memberships_for_user/1`, `get_location_memberships_for_location/1`, `destroy_location_membership/1`
  - Refactored `priv/repo/seeds.exs` to use interface functions instead of direct `Ash.Changeset` calls
  - Refactored `test/support/organizations_fixtures.ex` to use interface functions
  - Updated `CLAUDE.md` with comprehensive code interface documentation:
    - Section on "Using Code Interfaces" with DO/DON'T examples
    - Explanation of interface function benefits (encapsulation, cleaner APIs, discoverability)
    - Instructions for adding code interfaces in domain modules
    - Examples of calling interface functions
    - Guidelines for seeds and tests
    - Important note: interfaces are defined in domain module, not resource files
- Created `CLAUDE.md` with comprehensive guidance for Claude Code instances
  - Project overview with technology stack (Ash Framework 3.0, Phoenix LiveView 1.1, AshAuthentication, Tailwind CSS v4)
  - Essential commands for setup, testing, code quality, assets, and database operations
  - Architecture documentation covering Ash domains, resources, authentication flow, and web layer structure
  - Detailed Ash migration workflow with snapshot system explanation
  - Instructions for `mix ash.codegen --dev` vs `mix ash.codegen` usage
  - Git commit workflow with conventional commit message format
  - Changelog maintenance requirements (this file)
  - Key development patterns for resources, LiveView, and API development
  - Testing guidelines and important project-specific notes
  - Prominent references to `AGENTS.md` for detailed framework-specific guidelines
- Created `CHANGELOG.md` to track project changes over time
- Git commit workflow guidelines in `CLAUDE.md`
  - Instructions to always ask user before committing
  - Conventional commit message format (feat, fix, refactor, etc.)
  - Examples of good commit messages
  - Integration with Ash migration finalization workflow
- References to `AGENTS.md` throughout `CLAUDE.md`
  - Added prominent section at top directing Claude instances to read `AGENTS.md` first
  - Enhanced LiveView Development section with references to detailed guidelines
  - Enhanced Testing section with references to comprehensive testing patterns
  - Added reminder in Important Notes section
