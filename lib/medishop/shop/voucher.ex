defmodule Medishop.Shop.Voucher do
  @moduledoc """
  Represents a promotional code or voucher that can be applied to a cart for discounts.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "vouchers"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :name,
        :code,
        :discount_type,
        :discount_value,
        :min_purchase_type,
        :min_purchase_value,
        :usage_limit_total,
        :usage_limit_per_location,
        :apply_to_shipping,
        :combinable,
        :tax_application,
        :start_date,
        :end_date,
        :active
      ]

      argument :organization_ids, {:array, :uuid}
      argument :location_ids, {:array, :uuid}
      argument :product_ids, {:array, :uuid}

      change manage_relationship(:organization_ids, :organizations, type: :append_and_remove)
      change manage_relationship(:location_ids, :locations, type: :append_and_remove)
      change manage_relationship(:product_ids, :products, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [
        :name,
        :code,
        :discount_type,
        :discount_value,
        :min_purchase_type,
        :min_purchase_value,
        :usage_limit_total,
        :usage_limit_per_location,
        :apply_to_shipping,
        :combinable,
        :tax_application,
        :start_date,
        :end_date,
        :active
      ]

      argument :organization_ids, {:array, :uuid}
      argument :location_ids, {:array, :uuid}
      argument :product_ids, {:array, :uuid}

      change manage_relationship(:organization_ids, :organizations, type: :append_and_remove)
      change manage_relationship(:location_ids, :locations, type: :append_and_remove)
      change manage_relationship(:product_ids, :products, type: :append_and_remove)
    end

    read :by_code do
      argument :code, :string, allow_nil?: false
      filter expr(code == ^arg(:code))
      get? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :code, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :discount_type, :atom do
      constraints [one_of: [:percentage, :fixed]]
      allow_nil? false
      public? true
    end

    attribute :discount_value, :decimal do
      allow_nil? false
      public? true
    end

    attribute :min_purchase_type, :atom do
      constraints [one_of: [:none, :amount, :quantity]]
      default :none
      public? true
    end

    attribute :min_purchase_value, :decimal do
      description "Required amount ($) or quantity (count) to apply"
      public? true
    end

    attribute :usage_limit_total, :integer do
      public? true
    end

    attribute :usage_limit_per_location, :integer do
      public? true
    end

    attribute :apply_to_shipping, :boolean do
      default false
      public? true
    end

    attribute :combinable, :boolean do
      default false
      public? true
    end

    attribute :tax_application, :atom do
      constraints [one_of: [:before_tax, :after_tax]]
      default :after_tax
      public? true
    end

    attribute :start_date, :date do
      public? true
    end

    attribute :end_date, :date do
      public? true
    end

    attribute :active, :boolean do
      default true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :organizations, Medishop.Organizations.Organization do
      through Medishop.Shop.VoucherOrganization
      source_attribute_on_join_resource :voucher_id
      destination_attribute_on_join_resource :organization_id
    end

    many_to_many :locations, Medishop.Organizations.Location do
      through Medishop.Shop.VoucherLocation
      source_attribute_on_join_resource :voucher_id
      destination_attribute_on_join_resource :location_id
    end

    many_to_many :products, Medishop.Products.Product do
      through Medishop.Shop.VoucherProduct
      source_attribute_on_join_resource :voucher_id
      destination_attribute_on_join_resource :product_id
    end

    has_many :redemptions, Medishop.Shop.VoucherRedemption
  end

  identities do
    identity :unique_code, [:code]
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
