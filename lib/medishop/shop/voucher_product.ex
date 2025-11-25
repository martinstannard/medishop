defmodule Medishop.Shop.VoucherProduct do
  @moduledoc """
  Join resource linking Vouchers and Products.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "voucher_products"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  relationships do
    belongs_to :voucher, Medishop.Shop.Voucher do
      primary_key? true
      allow_nil? false
    end

    belongs_to :product, Medishop.Products.Product do
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
