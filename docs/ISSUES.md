# Known Issues

## Missed Notifications in Shop Actions

**Status:** Open
**Date:** 2025-11-28
**Priority:** High

### Description
Running tests produces multiple warnings about missed notifications in `Medishop.Shop` actions, particularly involving `Order`, `OrderItem`, `Cart`, and `CartItem`.

### Error Message
```
[warning] Missed 1 notifications in action Medishop.Shop.OrderItem.create.

This happens when the resources are in a transaction, and you did not pass
`return_notifications?: true`. If you are in a changeset hook, you can
return the notifications. If not, you can send the notifications using
`Ash.Notifier.notify/1` once your resources are out of a transaction.
```

### Affected Actions
- `Medishop.Shop.Order.create` (specifically `create_from_cart`)
- `Medishop.Shop.OrderItem.create`
- `Medishop.Shop.CartItem.destroy`
- `Medishop.Shop.Cart.update`

### Context
These warnings occur when resources are modified within a transaction (likely the `create_from_cart` transaction) without properly propagating notifications. This can lead to side effects (like email notifications or pubsub events) being lost.

### Proposed Solution
Update the calls to `Ash.create`, `Ash.update`, and `Ash.destroy` (or their domain interface equivalents) within the transaction logic to include `return_notifications?: true` and then ensure these notifications are returned or explicitly sent using `Ash.Notifier.notify/1` after the transaction commits.
