defmodule Medishop.Products.ProductSupplier do
  @moduledoc """
  Join resource linking Products and Suppliers.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Products,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "product_suppliers"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  relationships do
    belongs_to :product, Medishop.Products.Product do
      primary_key? true
      allow_nil? false
    end

    belongs_to :supplier, Medishop.Products.Supplier do
      primary_key? true
      allow_nil? false
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
