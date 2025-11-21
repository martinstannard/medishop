defmodule Medishop.OrganizationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medishop.Organizations` context.
  """

  alias Medishop.Organizations
  alias Medishop.Accounts.User
  alias Medishop.Repo

  def user_fixture(attrs \\ %{}) do
    email = attrs[:email] || "user#{System.unique_integer([:positive])}@example.com"
    Repo.insert!(%User{email: email})
  end

  def organization_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Organization #{System.unique_integer([:positive])}"
      })

    {:ok, organization} = Organizations.create_organization(attrs)
    organization
  end

  def location_fixture(organization_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        organization_id: organization_id,
        name: "Test Location #{System.unique_integer([:positive])}",
        address: %{
          street: "123 Test St",
          city: "Test City",
          state: "TS",
          zip: "12345",
          country: "USA"
        },
        contact_number: "555-#{:rand.uniform(9999)}"
      })

    {:ok, location} = Organizations.create_location(attrs)
    location
  end

  def organization_membership_fixture(user_id, organization_id, attrs \\ %{}) do
    org_roles = Map.get(attrs, :org_roles, [:org_member])

    {:ok, membership} =
      Organizations.create_membership(
        user_id,
        organization_id,
        Map.put(attrs, :org_roles, org_roles),
        authorize?: false
      )

    membership
  end

  def organization_location_membership_fixture(membership_id, location_id) do
    {:ok, location_membership} =
      Organizations.create_location_membership(membership_id, location_id, authorize?: false)

    location_membership
  end
end
