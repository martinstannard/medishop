defmodule Medishop.Inventory.LocationInventory do
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "location_inventories"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:location_id, :product_id, :quantity_available]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:quantity_available]
    end

    read :get_by_location do
      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id))
    end

    read :get_by_product do
      argument :product_id, :uuid, allow_nil?: false

      filter expr(product_id == ^arg(:product_id))
    end
  end

  policies do
    # Allow all actions for now (we'll add proper authorization later)
    policy always() do
      authorize_if always()
    end
  end

  validations do
    validate compare(:quantity_available, greater_than_or_equal_to: 0),
      message: "Quantity available must be non-negative"
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity_available, :integer do
      description "Current stock level for this product at this location"
      allow_nil? false
      default 0
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :location, Medishop.Organizations.Location do
      public? true
      allow_nil? false
    end

    belongs_to :product, Medishop.Products.Product do
      public? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_location_product, [:location_id, :product_id]
  end
end
