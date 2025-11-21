defmodule Medishop.Organizations.OrganizationMembershipTest do
  use Medishop.DataCase

  alias Medishop.Organizations
  alias Medishop.Generator

  describe "create_membership/2" do
    test "creates a membership with org_admin role" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_admin]))

      assert :org_admin in membership.org_roles
    end

    test "creates a membership with multiple roles" do
      membership =
        Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_admin, :org_buyer]))

      assert :org_admin in membership.org_roles
      assert :org_buyer in membership.org_roles
    end

    test "defaults to org_member role when no roles specified" do
      membership = Ash.Generator.generate(Generator.organization_membership())

      assert membership.org_roles == [:org_member]
    end

    test "enforces unique constraint on user_id and organization_id" do
      user = Ash.Generator.generate(Generator.user())
      organization = Ash.Generator.generate(Generator.organization())

      # Create first membership
      Ash.Generator.generate(
        Generator.organization_membership(user_id: user.id, organization_id: organization.id)
      )

      # Try to create duplicate
      assert_raise Ash.Error.Invalid, fn ->
        Ash.Generator.generate(
          Generator.organization_membership(user_id: user.id, organization_id: organization.id)
        )
      end
    end
  end

  describe "get_memberships_for_user/1" do
    test "returns memberships for a specific user" do
      user = Ash.Generator.generate(Generator.user())
      organization = Ash.Generator.generate(Generator.organization())
      membership1 =
        Ash.Generator.generate(
          Generator.organization_membership(user_id: user.id, organization_id: organization.id)
        )

      # Create another membership for a different user
      Ash.Generator.generate(Generator.organization_membership())

      assert {:ok, memberships} = Organizations.get_memberships_for_user(%{user_id: user.id})

      assert length(memberships) == 1
      assert hd(memberships).id == membership1.id
    end
  end

  describe "get_memberships_for_organization/1" do
    test "returns memberships for a specific organization" do
      organization = Ash.Generator.generate(Generator.organization())
      user1 = Ash.Generator.generate(Generator.user())
      user2 = Ash.Generator.generate(Generator.user())

      membership1 =
        Ash.Generator.generate(
          Generator.organization_membership(
            user_id: user1.id,
            organization_id: organization.id,
            org_roles: [:org_admin]
          )
        )

      membership2 =
        Ash.Generator.generate(
          Generator.organization_membership(user_id: user2.id, organization_id: organization.id)
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
    test "updates membership roles" do
      membership = Ash.Generator.generate(Generator.organization_membership())

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
    test "is_admin returns true for org_admin role" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_admin]))

      {:ok, membership_with_calc} = Ash.load(membership, :is_admin)
      assert membership_with_calc.is_admin == true
    end

    test "is_admin returns false for non-admin roles" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_member]))

      {:ok, membership_with_calc} = Ash.load(membership, :is_admin)
      assert membership_with_calc.is_admin == false
    end

    test "can_buy returns true for org_buyer role" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_buyer]))

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == true
    end

    test "can_buy returns true for org_admin role" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_admin]))

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == true
    end

    test "can_buy returns false for org_member role" do
      membership = Ash.Generator.generate(Generator.organization_membership(org_roles: [:org_member]))

      {:ok, membership_with_calc} = Ash.load(membership, :can_buy)
      assert membership_with_calc.can_buy == false
    end
  end

  describe "destroy_membership/1" do
    test "deletes a membership" do
      membership = Ash.Generator.generate(Generator.organization_membership())

      assert :ok = Organizations.destroy_membership(membership)

      assert {:ok, memberships} = Organizations.list_memberships()
      refute Enum.any?(memberships, &(&1.id == membership.id))
    end
  end
end
