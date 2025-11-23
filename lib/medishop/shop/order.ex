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
      accept [:location_id, :user_id, :status, :subtotal, :total, :notes]

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

        # Load cart with items and location
        case Medishop.Shop.get_cart(cart_id, load: [:cart_items, :location]) do
          {:ok, cart} ->
            if Enum.empty?(cart.cart_items) do
              {:error, "Cannot create order from empty cart"}
            else
              # Calculate totals
              subtotal =
                Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
                  line_total = Decimal.mult(item.price_at_addition, Decimal.new(item.quantity))
                  Decimal.add(acc, line_total)
                end)

              # Create order
              order_result =
                Medishop.Shop.create_order(%{
                  location_id: cart.location_id,
                  user_id: user_id,
                  status: :pending,
                  subtotal: subtotal,
                  total: subtotal,
                  notes: notes
                })

              case order_result do
                {:ok, order} ->
                  # Create order items from cart items
                  order_items_result =
                    Enum.reduce_while(cart.cart_items, {:ok, []}, fn cart_item, {:ok, items} ->
                      case Medishop.Shop.create_order_item(%{
                             order_id: order.id,
                             product_id: cart_item.product_id,
                             quantity: cart_item.quantity,
                             unit_price: cart_item.price_at_addition,
                             line_total:
                               Decimal.mult(
                                 cart_item.price_at_addition,
                                 Decimal.new(cart_item.quantity)
                               )
                           }) do
                        {:ok, order_item} -> {:cont, {:ok, [order_item | items]}}
                        {:error, error} -> {:halt, {:error, error}}
                      end
                    end)

                  case order_items_result do
                    {:ok, _order_items} ->
                      # Clear the cart after successful order creation
                      # For now, we'll delete all cart items
                      Enum.each(cart.cart_items, fn item ->
                        Medishop.Shop.remove_cart_item(item)
                      end)

                      # Return the order with items loaded
                      Medishop.Shop.get_order(order.id, load: [:order_items])

                    {:error, error} ->
                      {:error, error}
                  end

                {:error, error} ->
                  {:error, error}
              end
            end

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

    has_many :order_items, Medishop.Shop.OrderItem do
      public? true
    end
  end

  identities do
    identity :unique_order_number, [:order_number]
  end

  # Private helper functions
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
