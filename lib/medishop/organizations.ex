defmodule Medishop.Organizations do
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Organizations.Organization do
      define :create_organization, action: :create
      define :list_organizations, action: :read
      define :get_organization, action: :read, get_by: [:id]
      define :update_organization, action: :update
      define :destroy_organization, action: :destroy
    end

    resource Medishop.Organizations.Location do
      define :create_location, action: :create
      define :list_locations, action: :read
      define :get_location, action: :read, get_by: [:id]

      define :get_locations_by_organization,
        action: :get_by_organization,
        args: [:organization_id]

      define :update_location, action: :update
      define :destroy_location, action: :destroy
    end

    resource Medishop.Organizations.OrganizationMembership do
      define :create_membership, action: :create, args: [:user_id, :organization_id, :org_roles]
      define :list_memberships, action: :read
      define :get_membership, action: :read, get_by: [:id]
      define :get_memberships_for_user, action: :for_user, args: [:user_id]

      define :get_memberships_for_organization,
        action: :for_organization,
        args: [:organization_id]

      define :update_membership, action: :update
      define :destroy_membership, action: :destroy
    end

    resource Medishop.Organizations.OrganizationLocationMembership do
      define :create_location_membership,
        action: :create,
        args: [:organization_membership_id, :location_id]

      define :list_location_memberships, action: :read
      define :get_location_membership, action: :read, get_by: [:id]
      define :get_location_memberships_for_user, action: :for_user, args: [:user_id]
      define :get_location_memberships_for_location, action: :for_location, args: [:location_id]
      define :destroy_location_membership, action: :destroy
    end
  end
end
