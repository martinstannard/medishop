defmodule Medishop.Organizations.OrganizationTest do
  use Medishop.DataCase

  alias Medishop.Organizations.Organization

  describe "create/1" do
    test "creates an organization with valid attributes" do
      attrs = %{
        name: "Test Medical Supply",
        active: true,
        is_test_organization: false,
        invoice_email: "billing@test.com",
        billing_address: %{
          street: "123 Test St",
          city: "Seattle",
          state: "WA",
          zip: "98101",
          country: "USA"
        },
        tax_id: "12-3456789"
      }

      assert {:ok, organization} =
               Organization
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create()

      assert organization.name == "Test Medical Supply"
      assert organization.active == true
      assert organization.invoice_email == "billing@test.com"
      assert organization.tax_id == "12-3456789"
    end

    test "creates organization with minimal required fields" do
      attrs = %{
        name: "Minimal Org"
      }

      assert {:ok, organization} =
               Organization
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create()

      assert organization.name == "Minimal Org"
      assert organization.active == false
      assert organization.is_test_organization == false
    end

    test "creates and updates organization with stripe_customer_id" do
      attrs = %{
        name: "Stripe Org",
        stripe_customer_id: "cus_test_123"
      }

      assert {:ok, organization} =
               Organization
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create()

      assert organization.stripe_customer_id == "cus_test_123"

      assert {:ok, updated_organization} =
               organization
               |> Ash.Changeset.for_update(:update, %{stripe_customer_id: "cus_test_456"})
               |> Ash.update()

      assert updated_organization.stripe_customer_id == "cus_test_456"
    end
  end

  describe "read/0" do
    test "lists all organizations" do
      # Create two organizations
      {:ok, org1} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org 1"})
        |> Ash.create()

      {:ok, org2} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org 2"})
        |> Ash.create()

      assert {:ok, organizations} = Ash.read(Organization)
      assert length(organizations) >= 2

      org_ids = Enum.map(organizations, & &1.id)
      assert org1.id in org_ids
      assert org2.id in org_ids
    end
  end

  describe "update/1" do
    test "updates organization attributes" do
      {:ok, organization} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Original Name"})
        |> Ash.create()

      assert {:ok, updated} =
               organization
               |> Ash.Changeset.for_update(:update, %{
                 name: "Updated Name",
                 active: true
               })
               |> Ash.update()

      assert updated.name == "Updated Name"
      assert updated.active == true
    end
  end

  describe "destroy/0" do
    test "deletes an organization" do
      {:ok, organization} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "To Delete"})
        |> Ash.create()

      assert :ok = Ash.destroy(organization)

      assert {:ok, organizations} = Ash.read(Organization)
      refute Enum.any?(organizations, &(&1.id == organization.id))
    end
  end

  describe "aggregates" do
    test "counts locations" do
      alias Medishop.Organizations.Location

      {:ok, organization} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org with Locations"})
        |> Ash.create()

      # Create two locations
      {:ok, _location1} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Location 1",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0001"
        })
        |> Ash.create()

      {:ok, _location2} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Location 2",
          organization_id: organization.id,
          address: %{street: "456 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0002"
        })
        |> Ash.create()

      # Load the aggregate
      {:ok, org_with_count} =
        organization
        |> Ash.load(:locations_count)

      assert org_with_count.locations_count == 2
    end
  end
end
