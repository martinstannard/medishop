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

    update :create_stripe_customer do
      require_atomic? false
      change before_action(fn changeset, _context ->
        if Ash.Changeset.get_data(changeset).stripe_customer_id do
          Ash.Changeset.add_error(changeset, :stripe_customer_id, "Stripe customer ID is already set.")
        else
          organization_name = Ash.Changeset.get_data(changeset).name
          organization_email = Ash.Changeset.get_data(changeset).invoice_email

          customer_attrs = %{name: organization_name, email: organization_email}

          case Medishop.StripeService.create_customer(customer_attrs) do
            {:ok, %{"id" => stripe_customer_id}} ->
              Ash.Changeset.set_attribute(changeset, :stripe_customer_id, stripe_customer_id)
            {:error, reason} ->
              Ash.Changeset.add_error(changeset, :stripe_customer_id, "Stripe customer creation failed: #{reason}")
          end
        end
      end)
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
