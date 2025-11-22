# LiveView Admin UI Implementation Plan

This document outlines the plan to create a minimal and clean LiveView-based user interface for the Medishop application. The UI will allow users to sign in and view the organizations and locations they are members of.

Testing is a mandatory part of this process. Each new piece of functionality must be accompanied by corresponding tests to ensure correctness and prevent regressions.

## Phase 1: Authentication UI

This phase focuses on creating the user-facing sign-in and sign-out capabilities using the existing `AshAuthentication` setup.

- [x] **Create Sign-In LiveView:** Implement a new LiveView at `/sign-in` (currently `/`) that allows users to enter their credentials.
- [x] **Implement Sign-In Logic:** Use `AshAuthentication` strategy (Password implemented).
- [ ] **Write Sign-In Tests (LiveViewTest):** ⚠️ BLOCKED - Needs AshAuthentication test setup
    - [ ] Test that a user can successfully request a magic link.
    - [ ] Test that a user is redirected to a confirmation page after requesting a link.
    - [ ] Test that a user can sign in by visiting the link from their email (simulated).
- [x] **Create a Log-Out Button:** Add a secure log-out button to the main layout that is visible only to authenticated users.
- [ ] **Write Log-Out Test (LiveViewTest):** ⚠️ BLOCKED - Needs AshAuthentication test setup

## Phase 2: Display User's Organizations

This phase focuses on displaying the list of organizations a user belongs to after they have signed in.

- [x] **Create Organizations LiveView:** Implemented `DashboardLive` at `/dashboard`.
- [x] **Fetch and Display Organizations:**
    - [x] Use the `:live_user_required` on_mount hook from `MedishopWeb.LiveUserAuth`.
    - [x] In the LiveView, fetch the list of `OrganizationMembership` records for the current user.
    - [x] Use Phoenix LiveView streams to display the list of organizations efficiently.
- [x] **Write Organizations View Tests (LiveViewTest):** ✅ COMPLETED - All 6 tests passing
    - [x] Test that an unauthenticated user is redirected to the `/sign-in` page.
    - [x] Test that an authenticated user sees a list of only the organizations they are a member of.
    - [x] Test that an authenticated user who is not a member of any organization sees an appropriate message.
    - [x] Test user roles displayed correctly
    - [x] Test active/test organization badges
    - [x] Test only shows user's organizations (not others')

## Phase 3: Display Organization's Locations

This phase will create a page to show the locations associated with a specific organization that the user has access to.
*Note: This was consolidated into the Dashboard view for better UX.*

- [x] **Create Locations LiveView:** Implemented within `DashboardLive`.
- [x] **Fetch and Display Locations:**
    - [x] The LiveView should verify that the current user is a member of the organization specified by the ID in the URL.
    - [x] If authorized, fetch and display the list of `Location` records for that organization.
- [x] **Add Navigation:** Dashboard acts as the central hub.
- [x] **Write Locations View Tests (LiveViewTest):** ✅ COMPLETED - All 12 tests passing (7 location + 3 relationship + 2 no-org)
    - [x] Test that locations are displayed for user's organizations
    - [x] Test that the locations page correctly displays only the locations for user's access
    - [x] Test that locations user doesn't have access to are not shown
    - [x] Test location details (address, contact) display
    - [x] Test store badge shows for store locations
    - [x] Test "No specific location access" message
    - [x] Test preloading of organization and location relationships

## Phase 4: UI Styling and Layout

This phase will ensure the new LiveViews are presented in a clean, professional, and consistent manner using the project's existing UI components.

- [x] **Create a Root Layout:** Updated `layouts.ex` with responsive header and user menu.
- [x] **Apply Mishka Chelekom Components:** Used Tailwind/DaisyUI for styling.
- [x] **Ensure Responsiveness:** Verified responsive design for dashboard cards and layout.

## Phase 5: Shopping Cart & Purchase Flow ✅ COMPLETE

This phase implements the shopping cart functionality, allowing users to browse products, add them to a location's cart, and place orders.

### Step 1: Add Cart Navigation to Dashboard ✅
**Effort:** Small
**Dependencies:** Phase 3 (Dashboard with locations)

- [x] **Add Cart Icon/Button to Location Cards:**
  - Add a cart icon button to each location card in `DashboardLive`
  - Button links to `/location/:location_id/cart`
  - Show cart item count badge if cart has items (optional for v1)
  - Only show for locations where user has `org_buyer` role

### Step 2: Create Cart LiveView ✅
**Effort:** Medium
**Dependencies:** Step 1

- [x] **Create `lib/medishop_web/live/cart_live.ex`:**
  - Route: `/location/:location_id/cart`
  - Use `:live_user_required` on_mount hook
  - Verify user has `org_buyer` role for location's organization
  - Fetch or create cart for location using `Shop.get_or_create_cart_for_location/1`
  - Load cart items with product details preloaded

- [x] **Implement Cart View:**
  - Display empty cart state with "Browse Products" link
  - Show cart items with: product name, quantity, price_at_addition, line_total
  - Add quantity adjustment controls (+/- buttons)
  - Add "Remove Item" button for each item
  - Show cart subtotal and total
  - Add "Clear Cart" button
  - Add "Browse Products" navigation button
  - Add "Place Order" button (enabled only if cart has items)

- [ ] **Implement Cart Events:**
  - `update_quantity` - Update cart item quantity
  - `remove_item` - Remove cart item from cart
  - `clear_cart` - Clear all items from cart
  - Use Phoenix LiveView streams for cart items list

### Step 3: Create Products Catalog LiveView
**Effort:** Medium
**Dependencies:** Step 2

- [x] **Create `lib/medishop_web/live/products_live.ex`:**
  - Route: `/location/:location_id/products`
  - Use `:live_user_required` on_mount hook
  - Verify user has `org_buyer` role for location's organization
  - Fetch products using `Products.list_products/0` or `Products.search_products/1`
  - Use Phoenix LiveView streams for products list

- [x] **Implement Products Catalog View:**
  - Display products in grid/card layout
  - Show: product title, SKU, description, price, images (if available)
  - Add "Add to Cart" button for each product
  - Show quantity selector (default: 1, min: 1)
  - Add search bar for filtering by title
  - Add filter for active/inactive products
  - Add "Back to Cart" navigation button
  - Show current cart item count in header/badge

- [x] **Implement Product Events:**
  - `add_to_cart` - Add product to cart with specified quantity
  - `search` - Filter products by search query
  - Use `Shop.add_or_update_cart_item/3` interface
  - Show success toast/notification on add
  - Update cart count badge after adding

### Step 4: Implement Checkout Flow
**Effort:** Medium
**Dependencies:** Step 2, Step 3

- [x] **Add "Place Order" Functionality to CartLive:**
  - Handle `place_order` event
  - Show confirmation modal before placing order
  - Use `Shop.create_order_from_cart/2` interface
  - On success: redirect to order confirmation page
  - On error: show error message

- [x] **Create Order Confirmation LiveView:**
  - Route: `/orders/:order_id/confirmation`
  - Display order details: order number, items, total, status
  - Show "View My Orders" link
  - Show "Continue Shopping" link (back to products)

### Step 5: Create Orders List LiveView ✅ COMPLETE
**Effort:** Small
**Dependencies:** Step 4

- [x] **Create `lib/medishop_web/live/orders_live.ex`:**
  - Route: `/location/:location_id/orders`
  - Lists all orders for a location using `Shop.get_orders_for_location/2`
  - Shows: order number, date, status badge, total, items summary
  - Authorization: user must have location access
  - Empty state when no orders
  - Sorted by date (newest first) using `Enum.sort_by` in application code
  - Links to order confirmation page and PDF download
  - **Note:** Ash code interface doesn't support `sort:` option; sorting done in Elixir

- [x] **Create Order PDF Download:**
  - Route: `/orders/:order_id/pdf`
  - Controller: `OrderPDFController`
  - Generates HTML-based PDF with professional styling
  - Includes order header, items table, totals
  - Authorization: user must own the order
  - Uses browser print functionality

### Step 6: Write Cart & Shopping LiveView Tests
**Effort:** Large
**Dependencies:** Steps 1-5

**Test File 1:** `test/medishop_web/live/cart_live_test.exs`

**Required Tests:**
- [x] Test unauthenticated user redirected to sign-in
- [x] Test authorized user can view cart
- [x] Test unauthorized user (different org) cannot access cart
- [x] Test user without org_buyer role cannot access cart
- [x] Test empty cart shows appropriate message
- [x] Test cart displays items with correct details
- [x] Test updating cart item quantity
- [x] Test removing cart item
- [x] Test clearing entire cart
- [x] Test "Place Order" button disabled when cart empty
- [x] Test "Place Order" button enabled when cart has items
- [x] Test placing order successfully
- [x] Test navigation to products catalog

**Test File 2:** `test/medishop_web/live/products_live_test.exs`

**Required Tests:**
- [x] Test unauthenticated user redirected to sign-in
- [x] Test authorized user can view products
- [x] Test unauthorized user cannot access products
- [x] Test products displayed in catalog
- [x] Test adding product to cart
- [x] Test adding product with custom quantity
- [x] Test search/filter functionality
- [x] Test cart count updates after adding item
- [x] Test navigation back to cart

**Test File 3:** `test/medishop_web/live/orders_live_test.exs` ✅ COMPLETE (10/10 tests)

**Required Tests:**
- [x] Test unauthenticated user redirected to sign-in
- [x] Test unauthorized user (no location access) redirected with error
- [x] Test authorized user can view orders
- [x] Test empty orders message displayed correctly
- [x] Test back to dashboard link present
- [x] Test displays all orders for the location
- [x] Test order status badges displayed
- [x] Test order totals displayed correctly
- [x] Test view details link for each order
- [x] Test download PDF link for each order
- [x] Test only shows orders for current location (not others)

**Quality Gate:** All cart and shopping tests passing ✅ (51 + 10 = 61 tests total)

## Phase 6: Finalization and Quality Assurance

This final phase is for ensuring the quality and integrity of the new code before considering the work complete.

- [ ] **Run All Tests:** Execute the full test suite with `mix test` to confirm that no regressions have been introduced in other parts of the application.
- [ ] **Run Code Formatter:** Ensure all new code adheres to the project's style guide by running `mix format`.
- [ ] **Run Static Analysis:** Check for any potential code quality issues or bugs by running `mix credo --strict`.
- [ ] **Update Documentation:** Update the `CHANGELOG.md` file to reflect the addition of the new LiveView UI features and shopping cart functionality.
