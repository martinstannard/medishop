defmodule Medishop.Organizations.OrganizationMembership do
  @moduledoc """
  Organization membership resource connecting users to organizations with role assignments.
  Manages user roles (org_admin, org_member, org_buyer) and provides calculations for permission checking and location access tracking.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organization_memberships"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :organization_id, :org_roles]
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:org_roles]
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
      prepare build(load: [:organization, organization_location_memberships: :location])
    end

    read :for_organization do
      argument :organization_id, :uuid, allow_nil?: false

      filter expr(organization_id == ^arg(:organization_id))
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

    attribute :org_roles, {:array, Medishop.Organizations.OrgRole} do
      description "Roles this user has in the organization: org_admin, org_member, org_buyer"
      allow_nil? false
      default [:org_member]
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Medishop.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :organization, Medishop.Organizations.Organization do
      public? true
      allow_nil? false
    end

    has_many :organization_location_memberships,
             Medishop.Organizations.OrganizationLocationMembership
  end

  calculations do
    calculate :is_admin,
              :boolean,
              expr(:org_admin in org_roles) do
      description "Returns true if user has org_admin role"
    end

    calculate :can_buy,
              :boolean,
              expr(:org_buyer in org_roles or :org_admin in org_roles) do
      description "Returns true if user can make purchases"
    end
  end

  identities do
    identity :unique_user_organization, [:user_id, :organization_id]
  end
end
