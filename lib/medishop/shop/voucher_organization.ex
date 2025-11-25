defmodule Medishop.Shop.VoucherOrganization do
  @moduledoc """
  Join resource linking Vouchers and Organizations.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "voucher_organizations"
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

    belongs_to :organization, Medishop.Organizations.Organization do
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
