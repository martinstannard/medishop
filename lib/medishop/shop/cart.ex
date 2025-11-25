defmodule Medishop.Shop.Cart do
  @moduledoc """
  Shopping cart resource that holds items selected for purchase at a specific location.
  Each location has one cart, which can be retrieved or created on-demand and cleared when orders are placed.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "carts"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:location_id, :voucher_id, :discount_total]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:voucher_id, :discount_total]

      change after_action(fn changeset, result, _context ->
        # Only recalculate if voucher_id was changed or it was cleared
        if Ash.Changeset.retrieve_set_attribute(changeset, :voucher_id) || Ash.Changeset.retrieve_set_attribute(changeset, :discount_total) do
          # Load cart with items and voucher to calculate totals
          case Medishop.Shop.get_cart(result.id, load: [:cart_items, :voucher]) do
            {:ok, cart_with_relations} ->
              case Medishop.Shop.calculate_cart_totals(cart_with_relations) do
                {:ok, %{discount_total: new_discount_total}} ->
                  # Update the cart itself with the new discount total
                  Medishop.Shop.update_cart(result, %{discount_total: new_discount_total})
                _ ->
                  # If calculation fails or no voucher, ensure discount is 0
                  Medishop.Shop.update_cart(result, %{discount_total: Decimal.new("0.00")})
              end
            {:error, _} ->
              # Handle error loading cart, ensure discount is 0
              Medishop.Shop.update_cart(result, %{discount_total: Decimal.new("0.00")})
          end
        end
        {:ok, result}
      end)
    end

    action :get_or_create_for_location do
      argument :location_id, :uuid, allow_nil?: false
      returns :struct

      run fn input, _context ->
        location_id = input.arguments.location_id

        # Try to find existing cart using code interface
        case Medishop.Shop.get_cart_by_location(location_id) do
          {:ok, cart} ->
            {:ok, cart}

          {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
            # Create new cart if none exists using code interface
            Medishop.Shop.create_cart(%{location_id: location_id})

          {:error, %Ash.Error.Query.NotFound{}} ->
            # Direct NotFound error
            Medishop.Shop.create_cart(%{location_id: location_id})

          {:error, error} ->
            {:error, error}
        end
      end
    end

    update :clear do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        cart = changeset.data

        # Load cart with items
        {:ok, cart_with_items} = Medishop.Shop.get_cart(cart.id, load: [:cart_items])

        # Delete all cart items
        Enum.each(cart_with_items.cart_items, fn item ->
          Medishop.Shop.remove_cart_item(item)
        end)

        changeset
      end
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

    attribute :discount_total, :decimal do
      default Decimal.new("0.00")
      allow_nil? false
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

    belongs_to :voucher, Medishop.Shop.Voucher do
      allow_nil? true
      public? true
    end

    has_many :cart_items, Medishop.Shop.CartItem do
      public? true
    end
  end

  identities do
    identity :unique_cart_per_location, [:location_id]
  end
end
