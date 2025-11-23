defmodule Medishop.Organizations.OrganizationLocationMembership do
  @moduledoc """
  Location access resource that grants organization members access to specific locations within their organization.
  Represents the many-to-many relationship between organization memberships and locations for fine-grained access control.
  """

  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organization_location_memberships"
    repo Medishop.Repo

    identity_index_names unique_membership_location: "org_location_membership_unique_idx"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      argument :organization_membership_id, :uuid, allow_nil?: false
      argument :location_id, :uuid, allow_nil?: false

      change manage_relationship(:organization_membership_id, :organization_membership,
               type: :append_and_remove
             )

      change manage_relationship(:location_id, :location, type: :append_and_remove)
    end

    read :for_user do
      description "Get all location memberships for a user"

      argument :user_id, :uuid, allow_nil?: false

      filter expr(organization_membership.user_id == ^arg(:user_id))
    end

    read :for_location do
      description "Get all user memberships for a location"

      argument :location_id, :uuid, allow_nil?: false

      filter expr(location_id == ^arg(:location_id))
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

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization_membership, Medishop.Organizations.OrganizationMembership do
      public? true
      allow_nil? false
    end

    belongs_to :location, Medishop.Organizations.Location do
      public? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_membership_location, [:organization_membership_id, :location_id]
  end
end
