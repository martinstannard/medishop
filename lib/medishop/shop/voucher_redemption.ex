defmodule Medishop.Shop.VoucherRedemption do
  @moduledoc """
  Tracks the usage of a voucher in an order.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "voucher_redemptions"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      accept [:order_id, :voucher_id, :location_id, :user_id, :discount_amount, :redeemed_at]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :discount_amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :redeemed_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :voucher, Medishop.Shop.Voucher do
      allow_nil? false
    end

    belongs_to :order, Medishop.Shop.Order do
      allow_nil? false
    end

    belongs_to :location, Medishop.Organizations.Location do
      allow_nil? false
    end

    belongs_to :user, Medishop.Accounts.User do
      allow_nil? false
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
