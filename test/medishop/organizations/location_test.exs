defmodule Medishop.Organizations.LocationTest do
  use Medishop.DataCase

  alias Medishop.Organizations.{Location, Organization}

  setup do
    # Create an organization for testing locations
    {:ok, organization} =
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "Test Organization"})
      |> Ash.create()

    %{organization: organization}
  end

  describe "create/1" do
    test "creates a location with valid attributes", %{organization: organization} do
      attrs = %{
        name: "Test Location",
        organization_id: organization.id,
        address: %{
          street: "100 Main St",
          city: "Seattle",
          state: "WA",
          zip: "98101",
          country: "USA"
        },
        contact_number: "+1-206-555-0100",
        store: true,
        test_location: false
      }

      assert {:ok, location} =
               Location
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create()

      assert location.name == "Test Location"
      assert location.organization_id == organization.id
      assert location.contact_number == "+1-206-555-0100"
      assert location.store == true
      assert location.test_location == false
    end

    test "creates location with minimal required fields", %{organization: organization} do
      attrs = %{
        name: "Minimal Location",
        organization_id: organization.id,
        address: %{
          street: "123 St",
          city: "City",
          state: "ST",
          zip: "12345",
          country: "USA"
        },
        contact_number: "555-0000"
      }

      assert {:ok, location} =
               Location
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create()

      assert location.name == "Minimal Location"
      assert location.store == false
      assert location.test_location == false
    end
  end

  describe "get_by_organization/1" do
    test "returns locations for a specific organization", %{organization: organization} do
      # Create another organization
      {:ok, other_org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Other Organization"})
        |> Ash.create()

      # Create locations for both organizations
      {:ok, location1} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Org 1 Location",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0001"
        })
        |> Ash.create()

      {:ok, _location2} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Other Org Location",
          organization_id: other_org.id,
          address: %{street: "456 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0002"
        })
        |> Ash.create()

      assert {:ok, locations} =
               Location
               |> Ash.Query.for_read(:get_by_organization, %{organization_id: organization.id})
               |> Ash.read()

      assert length(locations) == 1
      assert hd(locations).id == location1.id
    end
  end

  describe "update/1" do
    test "updates location attributes", %{organization: organization} do
      {:ok, location} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Original Location",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0000",
          store: false
        })
        |> Ash.create()

      assert {:ok, updated} =
               location
               |> Ash.Changeset.for_update(:update, %{
                 name: "Updated Location",
                 store: true
               })
               |> Ash.update()

      assert updated.name == "Updated Location"
      assert updated.store == true
    end
  end

  describe "display_name calculation" do
    test "returns location name with organization name", %{organization: organization} do
      {:ok, location} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Downtown Office",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0000"
        })
        |> Ash.create()

      {:ok, location_with_display} = Ash.load(location, :display_name)

      assert location_with_display.display_name == "Downtown Office (Test Organization)"
    end
  end

  describe "multitenancy" do
    test "locations belong to their organization tenant", %{organization: organization} do
      {:ok, location} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "Tenant Location",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0000"
        })
        |> Ash.create()

      assert location.organization_id == organization.id
    end
  end

  describe "destroy/0" do
    test "deletes a location", %{organization: organization} do
      {:ok, location} =
        Location
        |> Ash.Changeset.for_create(:create, %{
          name: "To Delete",
          organization_id: organization.id,
          address: %{street: "123 St", city: "City", state: "ST", zip: "12345", country: "USA"},
          contact_number: "555-0000"
        })
        |> Ash.create()

      assert :ok = Ash.destroy(location)

      assert {:ok, locations} = Ash.read(Location)
      refute Enum.any?(locations, &(&1.id == location.id))
    end
  end
end
