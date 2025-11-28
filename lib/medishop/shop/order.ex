defmodule Medishop.Shop.Order do
  @moduledoc """
  Order resource representing a customer purchase with status tracking through the fulfillment lifecycle.
  Supports creating orders from carts, managing status transitions (pending, confirmed, shipped, delivered, cancelled), and generating unique order numbers.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:location_id, :user_id, :status, :subtotal, :total, :notes, :voucher_id, :discount_total]

      change fn changeset, _context ->
        # Generate unique order number
        order_number = generate_order_number()
        Ash.Changeset.force_change_attribute(changeset, :order_number, order_number)
      end

      change fn changeset, _context ->
        # Set placed_at timestamp
        Ash.Changeset.force_change_attribute(changeset, :placed_at, DateTime.utc_now())
      end
    end

    update :update do
      primary? true
      accept [:status, :notes, :confirmed_at, :shipped_at, :delivered_at, :cancelled_at]
    end

    update :update_status do
      require_atomic? false
      argument :status, :atom, allow_nil?: false

      change fn changeset, _context ->
        new_status = Ash.Changeset.get_argument(changeset, :status)
        changeset = Ash.Changeset.force_change_attribute(changeset, :status, new_status)

        # Set appropriate timestamp based on status
        timestamp_field =
          case new_status do
            :confirmed -> :confirmed_at
            :shipped -> :shipped_at
            :delivered -> :delivered_at
            :cancelled -> :cancelled_at
            _ -> nil
          end

        if timestamp_field do
          Ash.Changeset.force_change_attribute(changeset, timestamp_field, DateTime.utc_now())
        else
          changeset
        end
      end

      validate fn changeset, _context ->
        current_status = changeset.data.status
        new_status = Ash.Changeset.get_attribute(changeset, :status)

        if valid_status_transition?(current_status, new_status) do
          :ok
        else
          {:error,
           field: :status,
           message: "Invalid status transition from #{current_status} to #{new_status}"}
        end
      end

      # After successfully changing to :delivered, create inventory events
      change after_action(fn changeset, result, context ->
        old_status = changeset.data.status
        new_status = Ash.Changeset.get_attribute(changeset, :status)

        if new_status == :delivered and old_status != :delivered do
          case create_inventory_events_for_order(result, context) do
            :ok -> {:ok, result}
            {:error, error} -> {:error, error}
          end
        else
          {:ok, result}
        end
      end)
    end

    action :create_from_cart do
      argument :cart_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :notes, :string, allow_nil?: true
      returns :struct

      run fn input, _context ->
        cart_id = input.arguments.cart_id
        user_id = input.arguments.user_id
        notes = input.arguments[:notes]

        transaction_result =
          Medishop.Repo.transaction(fn ->
            # Load cart with items and location
            case Medishop.Shop.get_cart(cart_id, load: [:cart_items, :location]) do
              {:ok, cart} ->
                if Enum.empty?(cart.cart_items) do
                  Medishop.Repo.rollback("Cannot create order from empty cart")
                else
                  # Calculate totals
                  subtotal =
                    Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
                      line_total = Decimal.mult(item.price_at_addition, Decimal.new(item.quantity))
                      Decimal.add(acc, line_total)
                    end)

                  # Create order
                  order_result =
                    Medishop.Shop.create_order(
                      %{
                        location_id: cart.location_id,
                        user_id: user_id,
                        status: :pending,
                        subtotal: subtotal,
                        total: Decimal.sub(subtotal, cart.discount_total),
                        notes: notes,
                        voucher_id: cart.voucher_id,
                        discount_total: cart.discount_total
                      },
                      return_notifications?: true
                    )

                  case order_result do
                    {:ok, order, notifications} ->
                      # Create order items from cart items
                      # Accumulate notifications from each step
                      order_items_result =
                        Enum.reduce_while(
                          cart.cart_items,
                          {:ok, [], notifications},
                          fn cart_item, {:ok, items, acc_notifications} ->
                            case Medishop.Shop.create_order_item(
                                   %{
                                     order_id: order.id,
                                     product_id: cart_item.product_id,
                                     quantity: cart_item.quantity,
                                     unit_price: cart_item.price_at_addition,
                                     line_total:
                                       Decimal.mult(
                                         cart_item.price_at_addition,
                                         Decimal.new(cart_item.quantity)
                                       )
                                   },
                                   return_notifications?: true
                                 ) do
                              {:ok, order_item, item_notifications} ->
                                {:cont,
                                 {:ok, [order_item | items],
                                  acc_notifications ++ item_notifications}}

                              {:error, error} ->
                                {:halt, {:error, error}}
                            end
                          end
                        )

                      case order_items_result do
                        {:ok, _order_items, current_notifications} ->
                          # Handle voucher redemption
                          voucher_result =
                            if cart.voucher_id do
                              # Reload voucher to get code
                              {:ok, voucher} = Medishop.Shop.get_voucher(cart.voucher_id)

                              # Create negative order item for discount
                              discount_amount = cart.discount_total
                              negative_amount = Decimal.negate(discount_amount)

                              with {:ok, _, item_notifs} <-
                                     Medishop.Shop.create_order_item(
                                       %{
                                         order_id: order.id,
                                         product_id: nil,
                                         description: "Voucher: #{voucher.code}",
                                         quantity: 1,
                                         unit_price: negative_amount,
                                         line_total: negative_amount
                                       },
                                       return_notifications?: true
                                     ),
                                   {:ok, _, redemption_notifs} <-
                                     Medishop.Shop.create_voucher_redemption(
                                       %{
                                         order_id: order.id,
                                         voucher_id: cart.voucher_id,
                                         location_id: cart.location_id,
                                         user_id: user_id,
                                         discount_amount: cart.discount_total
                                       },
                                       return_notifications?: true
                                     ) do
                                {:ok, current_notifications ++ item_notifs ++ redemption_notifs}
                              else
                                {:error, error} -> {:error, error}
                              end
                            else
                              {:ok, current_notifications}
                            end

                          case voucher_result do
                            {:ok, current_notifications} ->
                              # Clear the cart after successful order creation
                              # We'll delete all cart items and clear voucher info
                              cart_items_result =
                                Enum.reduce_while(
                                  cart.cart_items,
                                  {:ok, current_notifications},
                                  fn item, {:ok, acc_notifs} ->
                                    case Medishop.Shop.remove_cart_item(item,
                                           return_notifications?: true
                                         ) do
                                      {:ok, destroy_notifs} ->
                                        {:cont, {:ok, acc_notifs ++ destroy_notifs}}

                                      {:error, error} ->
                                        {:halt, {:error, error}}
                                    end
                                  end
                                )

                              case cart_items_result do
                                {:ok, current_notifications} ->
                                  case Medishop.Shop.update_cart(
                                         cart,
                                         %{
                                           voucher_id: nil,
                                           discount_total: Decimal.new("0.00")
                                         },
                                         return_notifications?: true
                                       ) do
                                    {:ok, _, update_notifs} ->
                                      # Return the order with items and voucher loaded, AND all notifications
                                      {:ok, order} =
                                        Medishop.Shop.get_order(order.id,
                                          load: [:order_items, :voucher]
                                        )

                                      {order, current_notifications ++ update_notifs}

                                    {:error, error} ->
                                      Medishop.Repo.rollback(error)
                                  end

                                {:error, error} ->
                                  Medishop.Repo.rollback(error)
                              end

                            {:error, error} ->
                              Medishop.Repo.rollback(error)
                          end

                        {:error, error} ->
                          Medishop.Repo.rollback(error)
                      end

                    {:error, error} ->
                      Medishop.Repo.rollback(error)
                  end
                end

              {:error, error} ->
                Medishop.Repo.rollback(error)
            end
          end)

        case transaction_result do
          {:ok, {order, notifications}} ->
            # Send notifications now that transaction is committed
            Ash.Notifier.notify(notifications)
            {:ok, order}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    read :get_by_location do
      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id))
    end

    read :get_by_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    # Allow all actions for now (will implement proper authorization in Phase 4)
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :order_number, :string do
      allow_nil? false
      public? true
    end

    attribute :discount_total, :decimal do
      default Decimal.new("0.00")
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :confirmed, :shipped, :delivered, :cancelled]
      public? true
    end

    attribute :subtotal, :decimal do
      allow_nil? false
      public? true
    end

    attribute :total, :decimal do
      allow_nil? false
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    attribute :placed_at, :utc_datetime_usec do
      public? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      public? true
    end

    attribute :shipped_at, :utc_datetime_usec do
      public? true
    end

    attribute :delivered_at, :utc_datetime_usec do
      public? true
    end

    attribute :cancelled_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :location, Medishop.Organizations.Location do
      allow_nil? false
      public? true
    end

    belongs_to :user, Medishop.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :voucher, Medishop.Shop.Voucher do
      allow_nil? true
      public? true
    end

    has_many :order_items, Medishop.Shop.OrderItem do
      public? true
    end
  end

  identities do
    identity :unique_order_number, [:order_number]
  end

  # Private helper functions
  defp create_inventory_events_for_order(order, context) do
    # Load order items with products
    case Medishop.Shop.get_order(order.id, load: [:order_items], actor: context.actor) do
      {:ok, order_with_items} ->
        # Create inventory event for each order item
        results =
          Enum.map(order_with_items.order_items, fn item ->
            Medishop.Inventory.create_inventory_event(
              %{
                location_id: order.location_id,
                product_id: item.product_id,
                event_type: :purchase_received,
                quantity_change: item.quantity,
                reference_type: "Order",
                reference_id: order.id,
                occurred_at: DateTime.utc_now()
              },
              actor: context.actor
            )
          end)

        # Check if all events were created successfully
        case Enum.find(results, fn result -> match?({:error, _}, result) end) do
          nil -> :ok
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp generate_order_number do
    # Format: ORD-YYYYMMDD-XXXXXX (where X is random)
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :crypto.strong_rand_bytes(3) |> Base.encode16()
    "ORD-#{date}-#{random}"
  end

  defp valid_status_transition?(current, new) do
    # Same status is allowed (idempotent)
    if current == new do
      true
    else
      terminal_status?(current) == false and allowed_transition?(current, new)
    end
  end

  defp terminal_status?(status), do: status in [:delivered, :cancelled]

  defp allowed_transition?(:pending, new), do: new in [:confirmed, :cancelled]
  defp allowed_transition?(:confirmed, new), do: new in [:shipped, :cancelled]
  defp allowed_transition?(:shipped, new), do: new == :delivered
  defp allowed_transition?(_, _), do: false
end
