# Implementation Plan: Voucher System

**Status:** Draft
**Created:** 2025-11-25

## Overview
Implement a comprehensive voucher and discount system based on the provided UI design. This system will allow Admins to create promotional codes with specific rules regarding eligibility, value, and usage limits, and allow Purchasers (Location Admins) to apply them in the cart.

## User Stories
1. **Admin:** I want to create vouchers with specific codes, discount values (fixed/percent), and validity rules so I can run promotions.
2. **Admin:** I want to limit vouchers to specific organizations, clinics, or products to target campaigns.
3. **Purchaser:** I want to enter a voucher code in the cart and see the discount applied to my total.

## Data Model (Shop Domain)

Based on the UI requirements, we will add the following resources to `Medishop.Shop`.

### 1. `Medishop.Shop.Voucher`
The core resource defining the discount rule.

**Attributes:**
- `name` (string, required): e.g., "Daya Haute"
- `code` (string, required, unique, case-insensitive): e.g., "DAYAHAUTE500"
- `discount_type` (atom): `:percentage` or `:fixed`
- `discount_value` (decimal): e.g., 500.00 or 10.0
- `min_purchase_type` (atom): `:none`, `:amount`, `:quantity`
- `min_purchase_value` (decimal): The amount or quantity required.
- `usage_limit_total` (integer, optional): Total times code can be used system-wide.
- `usage_limit_per_location` (integer, optional): Limit per clinic/location.
- `apply_to_shipping` (boolean): "Shipping Discount" combinability.
- `combinable` (boolean): "Other Discount" combinability.
- `tax_application` (atom): `:before_tax` or `:after_tax` (Corresponds to GST checkboxes).
- `start_date` (date/datetime): Validity start.
- `end_date` (date/datetime): Validity end.
- `active` (boolean): Manual on/off switch.

**Relationships:**
- `many_to_many :organizations`: Whitelist of eligible organizations.
- `many_to_many :locations`: Whitelist of eligible clinics (locations).
- `many_to_many :products`: Whitelist of eligible products.
- `has_many :redemptions`: To track usage.

### 2. `Medishop.Shop.VoucherRedemption`
Tracks usage history to enforce limits.

**Attributes:**
- `order_id` (uuid)
- `voucher_id` (uuid)
- `location_id` (uuid)
- `user_id` (uuid)
- `discount_amount` (decimal): Snapshot of savings.
- `redeemed_at` (datetime)

## Implementation Steps

### Phase 1: Data Model & Logic ✅ COMPLETED

1.  **Create Resources:** ✅
    *   Create `Medishop.Shop.Voucher` with all attributes and validations.
    *   Create join resources for Organizations, Locations, and Products.
    *   Create `Medishop.Shop.VoucherRedemption`.
2.  **Logic - Validation:** ✅
    *   Implement a `validate_voucher(code, cart)` function.
    *   Checks: Code exists & active, Date range, Org/Location eligibility, Min purchase/quantity requirements.
    *   Checks: Usage limits (count existing redemptions).
3.  **Logic - Calculation:** ✅
    *   Implement `calculate_discount(voucher, cart)`.
    *   Handles Percentage vs Fixed.
    *   Handles Product eligibility (only discount eligible items?).
    *   *Clarification needed on Tax logic.*

### Phase 2: Cart Integration ✅ COMPLETED

4.  **Update Cart Resource:** ✅
    *   Add `applied_voucher_code` (string) or relationship to Voucher.
    *   Add `discount_total` (decimal) to Cart and Order.
5.  **Cart Calculations:** ✅
    *   Update `Shop.calculate_cart_totals` to subtract discount.
6.  **Order Creation:** ✅
    *   When converting Cart to Order, create a `VoucherRedemption` record.
    *   Snapshot the discount amount on the Order.

### Phase 3: Admin UI (Voucher Management)

7.  **Voucher List:** View all vouchers.
8.  **Voucher Form:**
    *   Implement the UI from the screenshot using Mishka components.
    *   Handle dynamic form sections (Radio buttons toggling inputs).
    *   Handle multi-selects for Organizations, Clinics, Products.

### Phase 4: Storefront UI (Cart)

9.  **Cart Input:**
    *   Add "Promo Code" input field and "Apply" button to `CartLive`.
    *   Display discount amount in the summary section.
    *   Display error messages (e.g., "Code expired", "Min spend not met").

## Clarifications & Assumptions

1.  **Tax/GST:** The UI mentions applying before/after GST.
    *   *Current State:* The system does not strictly track Tax/GST separate from totals yet.
    *   *Assumption:* We will add the `tax_application` field to the model for future use, but initially apply discounts to the Subtotal.
2.  **Clinics:**
    *   *Assumption:* "Clinics" in the UI refers to the `Medishop.Organizations.Location` resource.
3.  **Product Eligibility:**
    *   *Assumption:* If specific products are selected, the discount applies *only* to those items (if percentage) or requires those items to be present (if fixed). We will need to define the exact business rule for Fixed Amount + Specific Products.

## Testing Plan

*   **Unit Tests:**
    *   Test Voucher creation/validation.
    *   Test `calculate_discount` with various scenarios (Percent, Fixed, Min requirements).
    *   Test eligibility rules (Org mismatch, Location mismatch, Product mismatch).
*   **Integration Tests:**
    *   Test adding a valid voucher to a Cart.
    *   Test converting Cart with Voucher to Order (Redemption creation).
    *   Test usage limits (fail after N uses).
