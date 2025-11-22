defmodule Medishop.Shop.OrderItem do
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "order_items"
    repo Medishop.Repo
  end

  actions do
    # Order items are immutable - only create and read actions
    defaults [:read]

    create :create do
      primary? true
      accept [:order_id, :product_id, :quantity, :unit_price, :line_total]
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

    attribute :quantity, :integer do
      allow_nil? false
      constraints min: 1
      public? true
    end

    attribute :unit_price, :decimal do
      allow_nil? false
      public? true
    end

    attribute :line_total, :decimal do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :order, Medishop.Shop.Order do
      allow_nil? false
      public? true
    end

    belongs_to :product, Medishop.Products.Product do
      allow_nil? false
      public? true
    end
  end
end
