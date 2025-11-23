# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-23

### Added
- **Dashboard Low Stock Alerts Widget (Phase 3.4 Complete)** (`lib/medishop_web/live/dashboard_live.ex`)
  - Added "Low Stock Alerts" section to main Dashboard
  - Shows all products with quantity < 10 across all user's locations
  - Displays in prominent yellow-bordered card above organizations section
  - Features:
    - Item count badge showing total number of low stock items
    - Product title and SKU display
    - Location name for each item
    - Current quantity with color-coded badges (red for 0, yellow for 1-9)
    - "View Details" link to inventory detail page for each item
    - Sorted by quantity (lowest first) for urgent items at top
    - Only shows if there are low stock items (doesn't show empty state)
  - Automatically loads inventory data across all accessible locations on dashboard mount
  - Provides quick visibility into stock issues without navigating to each location
- **Record Inventory Event Form (Phase 3.3 Complete)** (`lib/medishop_web/live/inventory_detail_live.ex`)
  - Added interactive form to record inventory events directly from the inventory detail page
  - "Record Event" button to toggle form visibility
  - Form implemented as proper `<form>` element with `phx-change` and `phx-submit`
  - Form fields with real-time validation:
    - Event Type dropdown (Administered, Expired, Disposed, Adjustment)
    - Quantity input with automatic conversion (enter positive, auto-converts to negative for removals)
    - Batch Number (optional)
    - Expiration Date (required for expired events)
    - Reason textarea (required for disposed and adjustment events)
  - Comprehensive validation logic:
    - Cannot remove more than current quantity
    - Automatic quantity sign conversion for removal events (administered, expired, disposed)
    - Required field validation with contextual requirements
    - Real-time error messages displayed inline
  - Form state management with 7 assigns for form fields and errors
  - Event handlers: toggle_form, update_form, submit_event, cancel_form
  - After successful submission:
    - Reloads inventory with updated quantity
    - Reloads event list with new event (sorted newest first)
    - Displays success flash message
    - Resets and hides form
  - Helper functions: validate_event_form, parse_integer, parse_date, extract_errors
  - Comprehensive test suite: 6 new tests covering:
    - Form display and toggle
    - Form visibility with Record Event button
    - Form cancellation
    - All form fields presence
    - Empty form validation
    - Event recording flow
  - Total implementation: ~300 lines of form UI and validation logic

### Changed
- **Inventory Event Sorting** - Events now display in reverse chronological order (newest first)
  - Updated `filter_and_sort_events/1` to properly handle DateTime sorting with `{:desc, DateTime}`
  - Default sort is by `occurred_at` in descending order
  - Most recent events appear at the top of the list

- **Inventory Detail Page with Event Log (Phase 3.2 Complete)** (`lib/medishop_web/live/inventory_detail_live.ex`)
  - InventoryDetailLive shows detailed inventory event log for a product at a location
  - Route: `/location/:location_id/inventory/:product_id`
  - Product information display: title, SKU, location name
  - Current quantity card with dynamic stock status badge
    - Out of Stock (red) - quantity = 0
    - Low Stock (yellow) - quantity 1-9
    - In Stock (green) - quantity >= 10
  - Event type filtering with 6 filter buttons:
    - All Events, Purchases, Administered, Expired, Disposed, Adjustments
    - Active filter highlighted in color
  - Sortable event log table with 5 columns:
    - Date/Time (sortable) - displays date and time separately
    - Type - color-coded badges (green=purchase, blue=administered, yellow=expired, red=disposed, purple=adjustment)
    - Quantity (sortable) - with +/- prefix and color coding
    - Reference - displays reference_type if available
    - Reason - displays reason for disposal and adjustment events
  - Sorting functionality: click column headers to sort by occurred_at or quantity_change
  - Toggle sort order (ascending/descending) with visual indicators (↑/↓)
  - Empty state messages for no events and filtered results
  - Navigation: Back to Inventory link
  - Auto-creates LocationInventory record if it doesn't exist
  - Comprehensive test suite: `test/medishop_web/live/inventory_detail_live_test.exs` - 36/36 tests passing ✅ (30 existing + 6 form tests)
    - Authentication and authorization tests
    - Product and location display tests
    - Stock status badge tests (all 3 states)
    - Event log table rendering tests
    - Event type badge display tests
    - Quantity change formatting tests
    - Reason display tests for disposal/adjustment events
    - Event type filtering tests (all 6 types + switching)
    - Empty state message tests
    - Sorting functionality tests (both columns)
    - Navigation tests

- **Order Status Change UI** (`lib/medishop_web/live/orders_live.ex`)
  - Added status transition buttons to OrdersLive page
  - Contextual buttons based on current order status:
    - Pending → Confirm Order / Cancel Order
    - Confirmed → Mark as Shipped / Cancel Order
    - Shipped → Mark as Delivered
  - Handle `update_status` event with order reloading
  - Helper functions: `next_status_options/1`, `status_button_class/1`
  - Flash messages for each status transition
  - Special message for delivery: "Order delivered! Inventory has been updated."
  - Comprehensive tests: `test/medishop_web/live/orders_live_test.exs` - 18/18 tests passing ✅
  - Integration with inventory: marking orders as delivered automatically creates inventory events

- **Inventory Management UI (Phase 3)** (`lib/medishop_web/live/inventory_list_live.ex`)
  - InventoryListLive with product list and current quantities
  - Search functionality (filters by product title or SKU, case-insensitive)
  - Sortable columns (Product name, Current Quantity) with visual indicators (↑/↓)
  - Stock status badges: Out of Stock (red), Low Stock (yellow, <10 units), In Stock (green)
  - View Details link for each product (routes to placeholder InventoryDetailLive)
  - Back to Dashboard navigation
  - Authentication check with redirect to sign-in
  - Comprehensive tests: `test/medishop_web/live/inventory_list_live_test.exs` - 17/17 tests passing ✅
  - Added inventory button to Dashboard location cards

- **Automatic LocationInventory Creation** (`lib/medishop/inventory/inventory_event.ex:55-72`)
  - Added `after_action` hook to InventoryEvent create action
  - Automatically creates LocationInventory record when inventory event is created
  - Uses upsert mechanism to handle duplicates gracefully
  - Ensures inventory events always have corresponding LocationInventory records
  - Prevents orphaned inventory events

- **Event-Sourced Inventory Management (Phase 1 Complete)** (branch: `inventory-events`)
  - **InventoryEvent Resource** (`lib/medishop/inventory/inventory_event.ex`)
    - Event-sourced inventory tracking using AshEvents extension
    - Event types: :purchase_received, :administered, :expired, :disposed, :adjustment
    - Automatic actor attribution via `actor_id` field (AshEvents)
    - Event versioning and metadata tracking (AshEvents)
    - Attributes: event_type, quantity_change, batch_number, expiration_date, reference_type, reference_id, reason, occurred_at
    - Validation: reason required for :disposed and :adjustment events
    - Relationships: belongs_to :location, belongs_to :product
    - Custom read actions: by_location_and_product, by_location, by_product
    - Comprehensive test suite: `test/medishop/inventory/inventory_event_test.exs` - 18/18 tests passing ✅
  - **LocationInventory Updated to Event-Sourced Model**
    - Removed `quantity_available` stored attribute
    - Added `current_quantity` aggregate (sum of inventory_events.quantity_change)
    - Added `has_many :inventory_events` relationship with product filter
    - Removed `update` action (quantity now calculated, not stored)
    - Tests updated to verify aggregate calculations: `test/medishop/inventory/location_inventory_test.exs` - 10/10 tests passing ✅
  - **Order-Inventory Integration**
    - Updated `update_status` action in Order resource with `after_action` hook
    - Automatic inventory event creation when orders marked as :delivered
    - Helper function: `create_inventory_events_for_order/2` (lib/medishop/shop/order.ex:272)
    - Creates :purchase_received events for each order item with proper reference tracking
    - Idempotent: only triggers when status changes TO :delivered (prevents duplicates)
    - Integration tests: `test/medishop/inventory/order_inventory_integration_test.exs` - 3/3 tests passing ✅
  - **Database Migrations**
    - Created inventory_events table with AshEvents fields
    - Removed quantity_available column from location_inventories
    - Migration files in `priv/repo/migrations/`
    - Resource snapshots updated in `priv/resource_snapshots/`
  - **Code Interface Updates**
    - Added 6 interface functions for InventoryEvent in Inventory domain
    - Removed `update_location_inventory` interface (no longer needed)
  - **Dependencies**
    - Added `{:ash_events, "~> 0.1"}` to mix.exs (installed v0.5.1)
  - **Test Results**: All 292 tests passing ✅
    - 67 inventory tests (InventoryEvent, LocationInventory, Order-Inventory integration, InventoryDetailLive)
    - 18 OrdersLive tests (including 8 new status transition tests)
    - 17 InventoryListLive tests (authentication, search, sort, status badges)
    - 36 InventoryDetailLive tests (authentication, display, filtering, sorting, navigation, form recording)

### Changed
- **LocationInventory Create Action with Upsert** (`lib/medishop/inventory/location_inventory.ex:24-25`)
  - Changed create action to use `upsert? true` with `upsert_identity :unique_location_product`
  - Now returns existing record instead of failing when location+product combination already exists
  - Enables safe automatic creation of LocationInventory records from inventory events
  - Updated test to verify upsert behavior instead of unique constraint error

- **Inventory Management Plan Updated to Use AshEvents**: Revised implementation approach for event-sourced inventory system
  - Updated `docs/09-inventory-management-plan.md` to use `ash_events` package instead of custom implementation
  - Added AshEvents extension configuration for InventoryEvent resource
  - Actor attribution now handled automatically via `actor_id` field (replaces `performed_by_user_id`)
  - Event versioning and metadata tracking built-in via AshEvents
  - Database schema updated to include AshEvents fields: `actor_id`, `version`, `metadata`
  - Benefits: Better regulatory compliance, maintained by Ash team, event replay capabilities
  - Added `ash_events` dependency to Phase 1 MVP requirements
  - Updated technical implementation details with AshEvents architecture
  - Modified `create_inventory_events_for_order/2` example to use actor from context

## 2025-11-22

### Added
- **Unified Shopping Experience (ShopLive)**: New split-pane shopping interface
  - Cart panel always visible on right side (384px wide)
  - Products grid on left with responsive layout (1-3 columns)
  - Full-height scrollable panes for comfortable browsing
  - Add products, manage cart, and place orders all on one page
  - Real-time cart updates (item count and total)
  - Product search integrated into main view
  - Route: `/location/:location_id/shop`
  - Dashboard updated with "Shop" button
  - No navigation needed between cart and products
  - Cart items maintain consistent order based on creation time (oldest first)

- **Test Coverage for Cart Item Ordering**: Added comprehensive test suite for cart item order consistency
  - Test file: `test/medishop_web/live/shop_live_test.exs`
  - Verifies cart items maintain order when updating quantities
  - Verifies cart items maintain order when adding new products
  - Verifies cart items sorted by `created_at` timestamp
  - Verifies removed and re-added products appear at end
  - Tests use helper functions to extract DOM order and verify against database
  - Tests manually set `created_at` timestamps for speed (no `Process.sleep/1`)
  - These tests catch bugs like using incorrect field names (e.g., `inserted_at` vs `created_at`)

- **Order Filtering and Search**: Enhanced OrdersLive with filtering and search capabilities
  - Status filter buttons: All, Pending, Confirmed, Shipped, Delivered, Cancelled
  - Search bar for filtering by order number (case-insensitive, real-time)
  - Filters work together (status AND search)
  - Active filter buttons highlighted with appropriate colors
  - Responsive design (stacks on mobile, inline on desktop)
  - Real-time updates as you type

- **Order Viewing and PDF Export**: New OrdersLive page to view all orders for a location
  - Orders button added to each location card on Dashboard
  - OrdersLive displays all orders for a location sorted by date (newest first)
  - Order list shows order number, status badge, placed date, total, and items summary
  - Each order has "View Details" link to existing OrderConfirmationLive
  - Each order has "Download PDF" link to generate printable order document
  - PDF includes order header, items table, totals, and professional styling
  - Authorization: users must have location access to view orders
  - Empty state when no orders exist for location
  - Route: `/location/:location_id/orders`

- **Dashboard UI Improvements**: Completely redesigned for better readability and usability
  - Increased text sizes throughout (page title: text-5xl, org names: text-2xl, badges: text-sm)
  - Added generous spacing and padding (p-8 cards, gap-8 grids, space-y-4)
  - Improved contrast in dark mode (slate-900 background, gray-700 card backgrounds)
  - Larger, more visible badges with explicit color classes
  - Better icon sizes (w-5 h-5 for main icons)
  - Rounded-2xl cards for modern appearance
  - Maximum width increased to max-w-7xl for better space utilization

- **Header and Navigation**: Professional branded header with theme support
  - Medishop logo with gradient (blue-600 to purple-600) and shopping bag icon
  - Brand tagline: "Healthcare Supply Platform"
  - Three-mode theme toggle (System/Light/Dark) with visual slider
  - User menu dropdown with avatar initials, Dashboard link, and Sign Out
  - Proper dark mode support (dark:bg-gray-900 header, responsive colors)
  - Theme toggle remembers preference in localStorage
  - Smooth transitions and hover effects

- **Product Gradient Thumbnails**: Beautiful SVG-based thumbnails for products without images
  - Created `MedishopWeb.Helpers.ProductThumbnail` module
  - Generates colorful gradient backgrounds with product initials and SKU
  - 20 predefined gradient color pairs (purple, pink-red, blue-cyan, green, etc.)
  - Deterministic: same product always gets same colors (based on title hash)
  - Modern, professional design perfect for pharmaceutical products
  - Initials extracted intelligently from product title
  - SVG-based (scales perfectly, lightweight)
  - Inline data URI (no external requests)

### Fixed
- **Cart Item Ordering Bug**: Fixed cart items reordering when updating quantities
  - Changed `sort_cart_items/1` to use correct field: `created_at` instead of `inserted_at`
  - Cart items now maintain consistent order based on creation timestamp
  - Items stay in the same position when quantities are updated
  - New items always appear at the end of the cart
  - Applied sorting in all cart operations: mount, add_to_cart, update_quantity, remove_item
  - See `lib/medishop_web/live/shop_live.ex:227`

- **Code Quality and Test Suite**: Comprehensive cleanup and quality improvements
  - Fixed 5 failing tests (PageControllerTest and Organizations membership queries)
  - Removed all compilation warnings (unused variables, unused imports)
  - Formatted entire codebase with `mix format`
  - Verified clean compilation with `--warnings-as-errors`
  - All 213 tests passing with zero warnings ✅
  - Phase 6 of LiveView Admin UI plan complete

- **Test Fixes**: Corrected test expectations and function signatures
  - Updated PageControllerTest to match HomeLive content
  - Fixed Organizations membership query tests to pass IDs directly (not wrapped in maps)
  - Fixed `get_memberships_for_user`, `get_memberships_for_organization`
  - Fixed `get_location_memberships_for_user`, `get_location_memberships_for_location`

- **OrdersLive Sorting**: Fixed Ash Framework sort option error in order listing
  - Removed invalid `sort: [placed_at: :desc]` option from `Shop.get_orders_for_location` call
  - Ash code interface doesn't support `sort:` option - must sort in application code
  - Now sorting orders with `Enum.sort_by(orders, & &1.placed_at, {:desc, DateTime})`
  - Orders display newest first as intended
  - All 10 OrdersLive tests passing

- **OrdersLive Tests**: Added comprehensive test suite for order viewing functionality
  - Created `test/medishop_web/live/orders_live_test.exs` with 10 tests
  - Tests cover: authentication, authorization, empty state, order display, links, location isolation
  - Ensures users can only view orders for locations they have access to

- **LiveView Authentication**: Fixed current_user not being available in LiveView sessions
  - Added `assign_new_resources` call to `:live_user_required` and `:live_user_optional` hooks
  - Configured app layout in `ash_authentication_live_session` with proper on_mount hooks
  - Header now correctly detects authenticated user and displays user menu
  - Fixed Ash.CiString handling in user email display (convert to string before String.slice)

- **Layout Configuration**: Properly configured app layout for all authenticated LiveViews
  - Added `layout: {MedishopWeb.Layouts, :app}` to router live session
  - Fixed `Layouts.app` to work as both component (@inner_block) and layout (@inner_content)
  - Removed explicit wrapper from DashboardLive (layout applied automatically)
  - All authenticated pages now display header with branding and navigation

- **Sign Out Functionality**: Fixed sign out button in header dropdown
  - Changed route from `/auth/user/sign_out` to correct `/sign-out` route
  - Using verified route helper `~p"/sign-out"` for type safety
  - Sign out now works correctly from user menu

- **Theme Toggle Styling**: Updated theme toggle to match new design system
  - Replaced DaisyUI classes with explicit Tailwind utilities
  - Better contrast with gray borders and backgrounds
  - Smooth slider animation with shadow
  - Icons have proper colors and hover states
  - Added accessibility titles to each button

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

### Changed
- **Dashboard Design**: Complete redesign from DaisyUI to explicit Tailwind utility classes
  - Migrated all badges from DaisyUI (badge-success, badge-info) to Tailwind color classes
  - Changed primary text to gray-900/white for high contrast
  - Changed secondary text to gray-600/gray-300
  - Organization cards use white/gray-800 backgrounds with explicit borders
  - Location cards use gray-50/gray-700 nested backgrounds
  - All badges use explicit color classes with /50 opacity variants in dark mode
  - Simplified "Locations & Access" label to just "Locations"
  - Simplified "No specific location access assigned" to "No location access"

- **Test Suite**: Updated all Dashboard tests to match new HTML structure
  - Changed from DaisyUI class checks to content-based assertions
  - Updated element type assertions (span to p for location names)
  - Updated badge counting to use new color classes
  - All 18 Dashboard tests passing
  - All 69 LiveView tests passing

### Technical Notes
- Following explicit Tailwind utilities over DaisyUI for better control and consistency
- Dark mode uses gray-700/gray-800 for better contrast than gray-900/gray-950
- Theme toggle uses localStorage key "phx:theme" with system/light/dark values
- Layout works as both Phoenix layout (@inner_content) and LiveView component (@inner_block)
- All LiveViews in `ash_authentication_live_session` inherit app layout automatically

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
