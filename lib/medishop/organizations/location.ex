defmodule Medishop.Organizations.Location do
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "locations"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :get_by_organization do
      argument :organization_id, :uuid, allow_nil?: false

      filter expr(organization_id == ^arg(:organization_id))
    end

    create :create do
      primary? true

      accept [
        :name,
        :address,
        :contact_number,
        :store,
        :test_location
      ]

      argument :organization_id, :uuid, allow_nil?: false

      change manage_relationship(:organization_id, :organization, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :address,
        :contact_number,
        :store,
        :test_location
      ]
    end
  end

  policies do
    # Allow all actions for now (we'll add proper authorization later)
    policy always() do
      authorize_if always()
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :address, :map do
      description "Location address with keys: street, city, state, zip, country"
      allow_nil? false
      public? true
    end

    attribute :contact_number, :string do
      allow_nil? false
      public? true
    end

    attribute :store, :boolean do
      description "Indicates if this location is a store"
      default false
      public? true
    end

    attribute :test_location, :boolean do
      default false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, Medishop.Organizations.Organization do
      public? true
      allow_nil? false
    end

    has_many :organization_location_memberships,
             Medishop.Organizations.OrganizationLocationMembership

    has_many :location_inventories, Medishop.Inventory.LocationInventory
  end

  calculations do
    calculate :display_name,
              :string,
              expr(name <> " (" <> organization.name <> ")") do
      description "Location name formatted with organization name for disambiguation"
      load [:organization]
    end
  end
end
