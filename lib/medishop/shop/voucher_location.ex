defmodule Medishop.Shop.VoucherLocation do
  @moduledoc """
  Join resource linking Vouchers and Locations.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "voucher_locations"
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

    belongs_to :location, Medishop.Organizations.Location do
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
