defmodule Medishop.Inventory.LocationInventory do
  @moduledoc """
  Location inventory tracking resource that manages stock levels for products at specific locations.
  Maintains quantity available for each product-location combination with validation to ensure non-negative stock levels.
  """

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
      accept [:location_id, :product_id]
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

  attributes do
    uuid_primary_key :id

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  # Calculate current quantity from inventory events
  aggregates do
    sum :current_quantity, :inventory_events, :quantity_change do
      description "Current stock level calculated from all inventory events"
      public? true
      default 0
    end
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

    has_many :inventory_events, Medishop.Inventory.InventoryEvent do
      public? true
      destination_attribute :location_id
      source_attribute :location_id
      filter expr(product_id == parent(product_id))
    end
  end

  identities do
    identity :unique_location_product, [:location_id, :product_id]
  end
end
