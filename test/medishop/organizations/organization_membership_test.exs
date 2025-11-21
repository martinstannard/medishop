defmodule Medishop.Organizations.OrganizationMembershipTest do
  use Medishop.DataCase

  alias Medishop.Organizations

  import Medishop.OrganizationsFixtures

  setup do
    # Create a user and organization for testing
    user = user_fixture()
    organization = organization_fixture()

    %{user: user, organization: organization}
  end

  describe "create_membership/2" do
    test "creates a membership with org_admin role", %{user: user, organization: organization} do
      assert {:ok, membership} =
               Organizations.create_membership(
                 user.id,
                 organization.id,
                 %{org_roles: [:org_admin]},
                 authorize?: false
               )

      assert membership.user_id == user.id
      assert membership.organization_id == organization.id
      assert :org_admin in membership.org_roles
    end

    test "creates a membership with multiple roles", %{user: user, organization: organization} do
      assert {:ok, membership} =
               Organizations.create_membership(
                 user.id,
                 organization.id,
                 %{org_roles: [:org_admin, :org_buyer]},
                 authorize?: false
               )

      assert :org_admin in membership.org_roles
      assert :org_buyer in membership.org_roles
    end

    test "defaults to org_member role when no roles specified", %{
      user: user,
      organization: organization
    } do
      assert {:ok, membership} =
               Organizations.create_membership(
                 user.id,
                 organization.id,
                 %{},
                 authorize?: false
               )

      assert membership.org_roles == [:org_member]
    end

    test "enforces unique constraint on user_id and organization_id", %{
      user: user,
      organization: organization
    } do
      # Create first membership
      assert {:ok, _membership} =
               Organizations.create_membership(
                 user.id,
                 organization.id,
                 %{org_roles: [:org_member]},
                 authorize?: false
               )

      # Try to create duplicate
      assert {:error, _error} =
               Organizations.create_membership(
                 user.id,
                 organization.id,
                 %{org_roles: [:org_member]},
                 authorize?: false
               )
    end
  end

  describe "get_memberships_for_user/1" do
    test "returns memberships for a specific user", %{user: user, organization: organization} do
      # Create another user and organization
      other_user = user_fixture()
      other_org = organization_fixture()

      # Create memberships for both users
      {:ok, membership1} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      {:ok, _membership2} =
        Organizations.create_membership(
          other_user.id,
          other_org.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      assert {:ok, memberships} = Organizations.get_memberships_for_user(%{user_id: user.id})

      assert length(memberships) == 1
      assert hd(memberships).id == membership1.id
    end
  end

  describe "get_memberships_for_organization/1" do
    test "returns memberships for a specific organization", %{
      user: user,
      organization: organization
    } do
      other_user = user_fixture()

      # Create memberships for same organization with different users
      {:ok, membership1} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_admin]},
          authorize?: false
        )

      {:ok, membership2} =
        Organizations.create_membership(
          other_user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      assert {:ok, memberships} =
               Organizations.get_memberships_for_organization(%{
                 organization_id: organization.id
               })

      assert length(memberships) == 2

      membership_ids = Enum.map(memberships, & &1.id)
      assert membership1.id in membership_ids
      assert membership2.id in membership_ids
    end
  end

  describe "update_membership/2" do
    test "updates membership roles", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      assert {:ok, updated} =
               Organizations.update_membership(membership, %{
                 org_roles: [:org_admin, :org_buyer]
               })

      assert :org_admin in updated.org_roles
      assert :org_buyer in updated.org_roles
      refute :org_member in updated.org_roles
    end
  end

  describe "calculations" do
    test "is_admin returns true for org_admin role", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_admin]},
          authorize?: false
        )

      {:ok, membership_with_calc} = Ash.load(membership, :is_admin)
      assert membership_with_calc.is_admin == true
    end

    test "is_admin returns false for non-admin roles", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      {:ok, membership_with_calc} = Ash.load(membership, :is_admin)
      assert membership_with_calc.is_admin == false
    end

    test "can_buy returns true for org_buyer role", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_buyer]},
          authorize?: false
        )

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == true
    end

    test "can_buy returns true for org_admin role", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_admin]},
          authorize?: false
        )

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == true
    end

    test "can_buy returns false for org_member role", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == false
    end
  end

  describe "destroy_membership/1" do
    test "deletes a membership", %{user: user, organization: organization} do
      {:ok, membership} =
        Organizations.create_membership(
          user.id,
          organization.id,
          %{org_roles: [:org_member]},
          authorize?: false
        )

      assert :ok = Organizations.destroy_membership(membership)

      assert {:ok, memberships} = Organizations.list_memberships()
      refute Enum.any?(memberships, &(&1.id == membership.id))
    end
  end
end
