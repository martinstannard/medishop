defmodule Medishop.Organizations.OrganizationLocationMembershipTest do
  use Medishop.DataCase

  alias Medishop.Organizations

  import Medishop.Generator

  setup do
    # Create user, organization, location, and membership for testing
    user = user() |> Ash.Generator.generate()
    organization = organization() |> Ash.Generator.generate()
    location = location(organization_id: organization.id) |> Ash.Generator.generate()

    org_membership = organization_membership(
      user_id: user.id,
      organization_id: organization.id,
      org_roles: [:org_buyer]
    ) |> Ash.Generator.generate()

    %{
      user: user,
      organization: organization,
      location: location,
      org_membership: org_membership
    }
  end

  describe "create_location_membership/2" do
    test "creates a location membership", %{org_membership: org_membership, location: location} do
      assert {:ok, location_membership} =
               Organizations.create_location_membership(
                 org_membership.id,
                 location.id,
                 authorize?: false
               )

      assert location_membership.organization_membership_id == org_membership.id
      assert location_membership.location_id == location.id
    end

    test "enforces unique constraint on membership_id and location_id", %{
      org_membership: org_membership,
      location: location
    } do
      # Create first location membership
      assert {:ok, _location_membership} =
               Organizations.create_location_membership(
                 org_membership.id,
                 location.id,
                 authorize?: false
               )

      # Try to create duplicate
      assert {:error, _error} =
               Organizations.create_location_membership(
                 org_membership.id,
                 location.id,
                 authorize?: false
               )
    end
  end

  describe "get_location_memberships_for_user/1" do
    test "returns location memberships for a specific user", %{
      user: user,
      organization: organization,
      org_membership: org_membership,
      location: location
    } do
      # Create another user and their memberships
      other_user = user() |> Ash.Generator.generate()

      other_org_membership = organization_membership(
          user_id: other_user.id,
          organization_id: organization.id,
          org_roles: [:org_buyer]
        ) |> Ash.Generator.generate()

      # Create location memberships for both users
      {:ok, location_membership1} =
        Organizations.create_location_membership(
          org_membership.id,
          location.id,
          authorize?: false
        )

      {:ok, _location_membership2} =
        Organizations.create_location_membership(
          other_org_membership.id,
          location.id,
          authorize?: false
        )

      assert {:ok, location_memberships} =
               Organizations.get_location_memberships_for_user(user.id)

      assert length(location_memberships) == 1
      assert hd(location_memberships).id == location_membership1.id
    end
  end

  describe "get_location_memberships_for_location/1" do
    test "returns memberships for a specific location", %{
      organization: organization,
      org_membership: org_membership,
      location: location
    } do
      # Create another location
      other_location = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Create location memberships for both locations
      {:ok, location_membership1} =
        Organizations.create_location_membership(
          org_membership.id,
          location.id,
          authorize?: false
        )

      {:ok, _location_membership2} =
        Organizations.create_location_membership(
          org_membership.id,
          other_location.id,
          authorize?: false
        )

      assert {:ok, location_memberships} =
               Organizations.get_location_memberships_for_location(location.id)

      assert length(location_memberships) == 1
      assert hd(location_memberships).id == location_membership1.id
    end
  end

  describe "user can buy for multiple locations" do
    test "allows user to be assigned to multiple locations in same organization", %{
      organization: organization,
      org_membership: org_membership
    } do
      # Create two locations
      location1 = location(organization_id: organization.id) |> Ash.Generator.generate()
      location2 = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Assign user to both locations
      {:ok, _loc_membership1} =
        Organizations.create_location_membership(
          org_membership.id,
          location1.id,
          authorize?: false
        )

      {:ok, _loc_membership2} =
        Organizations.create_location_membership(
          org_membership.id,
          location2.id,
          authorize?: false
        )

      # Verify user has access to both locations
      assert {:ok, memberships} =
               Ash.load(org_membership, :organization_location_memberships)

      assert length(memberships.organization_location_memberships) == 2
    end
  end

  describe "destroy_location_membership/1" do
    test "deletes a location membership", %{org_membership: org_membership, location: location} do
      {:ok, location_membership} =
        Organizations.create_location_membership(
          org_membership.id,
          location.id,
          authorize?: false
        )

      assert :ok = Organizations.destroy_location_membership(location_membership)

      assert {:ok, memberships} = Organizations.list_location_memberships()
      refute Enum.any?(memberships, &(&1.id == location_membership.id))
    end
  end
end