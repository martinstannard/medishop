defmodule Medishop.Organizations.Organization do
  @moduledoc """
  Organization resource representing a business entity with locations, members, and billing information.
  Manages organizational settings including active status, test organization flag, invoice email, billing address, and tax ID.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organizations"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :active,
        :is_test_organization,
        :invoice_email,
        :billing_address,
        :tax_id,
        :stripe_customer_id
      ]
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :active,
        :is_test_organization,
        :invoice_email,
        :billing_address,
        :tax_id,
        :stripe_customer_id
      ]
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

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :active, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :is_test_organization, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :invoice_email, :string do
      allow_nil? true
      public? true
    end

    attribute :billing_address, :map do
      description "Billing address with keys: street, city, state, zip, country"
      allow_nil? true
      public? true
    end

    attribute :tax_id, :string do
      allow_nil? true
      public? true
    end

    attribute :stripe_customer_id, :string do
      allow_nil? true
      public? true
      description "The ID of the corresponding Stripe Customer object."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :locations, Medishop.Organizations.Location
    has_many :organization_memberships, Medishop.Organizations.OrganizationMembership
  end

  aggregates do
    count :locations_count, :locations do
      public? true
    end

    count :members_count, :organization_memberships do
      public? true
    end
  end
end
