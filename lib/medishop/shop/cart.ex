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
        require Ash.Query
        location_id = input.arguments.location_id

        # Try to find existing cart
        case Medishop.Shop.Cart
             |> Ash.Query.filter(location_id == ^location_id)
             |> Ash.read_one() do
          {:ok, cart} when not is_nil(cart) ->
            {:ok, cart}

          {:ok, nil} ->
            # Create new cart if none exists
            Medishop.Shop.Cart
            |> Ash.Changeset.for_create(:create, %{location_id: location_id})
            |> Ash.create()

          {:error, error} ->
            {:error, error}
        end
      end
    end

    update :clear do
      # Logic to be added when CartItem resource exists
      # Will use a manual action or manage_relationship to remove items
      accept []
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

    # has_many :cart_items will be added in Step 10
  end

  identities do
    identity :unique_cart_per_location, [:location_id]
  end
end
