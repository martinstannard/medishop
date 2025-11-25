defmodule Medishop.Products.Supplier do
  @moduledoc """
  Represents a supplier of products.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Products,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "suppliers"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :address, :sage_id, :contact_email, :contact_number]
    end

    update :update do
      primary? true
      accept [:name, :address, :sage_id, :contact_email, :contact_number]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :address, :string do
      public? true
    end

    attribute :sage_id, :string do
      description "External ID from Sage accounting system"
      public? true
    end

    attribute :contact_email, :string do
      public? true
    end

    attribute :contact_number, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :products, Medishop.Products.Product do
      through Medishop.Products.ProductSupplier
      source_attribute_on_join_resource :supplier_id
      destination_attribute_on_join_resource :product_id
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
