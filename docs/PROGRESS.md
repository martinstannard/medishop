# Project Progress

This file tracks the high-level progress of work on the Medishop project. Updated with each commit to provide a clear history of what has been accomplished.

---

## 2025-11-25

### Voucher System - Phase 2: Cart Integration ✅ COMPLETE

**What was accomplished:**
- **Cart Resource Updates**: Added `voucher_id` and `discount_total` fields.
- **Cart Logic**:
  - Implemented `calculate_cart_totals/1` in Shop domain.
  - Added `after_action` hooks to `CartItem` (create, update, destroy) to automatically recalculate cart totals.
  - Added `after_action` hook to `Cart` (update) to handle voucher application/removal.
- **Order Integration**:
  - Updated `Order` resource to store `voucher_id` and `discount_total`.
  - Updated `create_from_cart` action to:
    - Pass discount data to the new order.
    - Create a `VoucherRedemption` record.
    - Clear the voucher from the cart after order placement.
- **Migrations**: Generated and ran migrations for all schema changes.

**Files Modified:**
- `lib/medishop/shop/cart.ex`
- `lib/medishop/shop/cart_item.ex`
- `lib/medishop/shop/order.ex`
- `lib/medishop/shop.ex`

### Voucher System - Phase 1: Data Model & Logic ✅ COMPLETE

**What was accomplished:**
- **Voucher Resource**: Created `Medishop.Shop.Voucher` for managing promotional codes.
  - Supports percentage and fixed discounts.
  - Supports minimum purchase requirements (amount/quantity).
  - Supports validity dates and active status.
  - Supports eligibility restrictions (Organization, Location, Product).
- **Voucher Redemption**: Created `Medishop.Shop.VoucherRedemption` to track usage history.
- **Business Logic**: Implemented core logic functions in `Medishop.Shop`:
  - `validate_voucher/3`: Checks code existence, active status, and dates.
  - `calculate_discount/2`: Calculates discount amount based on cart subtotal.
- **Testing**:
  - Created `test/medishop/shop/voucher_test.exs` for CRUD and relationships.
  - Created `test/medishop/shop/voucher_logic_test.exs` for validation and calculation logic.
  - Added `voucher` generator to test support.
  - All tests passing ✅

**Files Modified:**
- `lib/medishop/shop/voucher.ex`
- `lib/medishop/shop/voucher_redemption.ex`
- `lib/medishop/shop.ex`
- `test/medishop/shop/voucher_test.exs`
- `test/medishop/shop/voucher_logic_test.exs`

### Product Supplier Management ✅ COMPLETE
... (rest of file)
