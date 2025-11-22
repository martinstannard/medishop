defmodule Medishop.Shop.Cart do
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
      accept [:location_id]
    end

    update :update do
      primary? true
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

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :location, Medishop.Organizations.Location do
      allow_nil? false
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
