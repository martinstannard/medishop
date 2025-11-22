defmodule Medishop.OrganizationsFixtures do
  @moduledoc """
  This module defines test fixtures for the Organizations domain.
  """

  alias Medishop.Accounts.User
  alias Medishop.Organizations

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email, unique_user_email())
    password = Map.get(attrs, :password, "password123456")

    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: email,
        password: password
      })
      |> Ash.create(authorize?: false)

    user
  end

  @doc """
  Generate an organization.
  """
  def organization_fixture(attrs \\ %{}) do
    name = Map.get(attrs, :name, "Test Organization #{System.unique_integer([:positive])}")

    {:ok, organization} =
      Organizations.create_organization(%{
        name: name
      })

    organization
  end

  @doc """
  Generate a location.
  """
  def location_fixture(organization_id, attrs \\ %{}) do
    name = Map.get(attrs, :name, "Test Location #{System.unique_integer([:positive])}")
    store = Map.get(attrs, :store, true)

    address =
      Map.get(attrs, :address, %{
        street: "123 Test St",
        city: "Test City",
        state: "TC",
        zip: "12345",
        country: "USA"
      })

    contact_number = Map.get(attrs, :contact_number, "+1-555-555-5555")

    {:ok, location} =
      Organizations.create_location(%{
        name: name,
        store: store,
        address: address,
        contact_number: contact_number,
        organization_id: organization_id
      })

    location
  end

  @doc """
  Generate an organization membership.
  """
  def organization_membership_fixture(user_id, organization_id, attrs \\ %{}) do
    org_roles = Map.get(attrs, :org_roles, [:org_member])

    {:ok, membership} =
      Organizations.create_membership(
        user_id,
        organization_id,
        org_roles,
        authorize?: false
      )

    membership
  end

  @doc """
  Generate an organization location membership.
  """
  def organization_location_membership_fixture(
        organization_membership_id,
        location_id,
        _attrs \\ %{}
      ) do
    {:ok, location_membership} =
      Organizations.create_location_membership(
        organization_membership_id,
        location_id,
        authorize?: false
      )

    location_membership
  end
end
