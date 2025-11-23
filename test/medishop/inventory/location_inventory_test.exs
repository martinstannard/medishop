defmodule Medishop.Inventory.LocationInventoryTest do
  use Medishop.DataCase

  alias Medishop.Inventory

  import Medishop.Generator

  describe "create_location_inventory/1" do
    test "creates inventory for location+product combination" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      assert {:ok, inventory} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id
               })

      assert inventory.location_id == location.id
      assert inventory.product_id == product.id
    end

    test "current_quantity defaults to 0 when no events exist" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Load with aggregate
      {:ok, inventory} = Ash.load(inventory, :current_quantity)
      assert inventory.current_quantity == 0
    end

    test "upserts when location+product combination already exists" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory1} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Try to create duplicate - should return existing record (upsert)
      {:ok, inventory2} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Should return the same record ID
      assert inventory1.id == inventory2.id
    end
  end

  describe "current_quantity calculation from events" do
    test "calculates quantity from single purchase event" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Create purchase event
      {:ok, _event} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      # Reload with aggregate
      {:ok, inventory} = Ash.load(inventory, :current_quantity, reuse_values?: false)
      assert inventory.current_quantity == 100
    end

    test "calculates quantity from multiple events (additions and removals)" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Purchase 100 units
      {:ok, _event1} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      # Administer 25 units
      {:ok, _event2} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :administered,
          quantity_change: -25,
          occurred_at: DateTime.utc_now()
        })

      # Purchase another 50 units
      {:ok, _event3} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      # Dispose 10 units
      {:ok, _event4} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :disposed,
          quantity_change: -10,
          reason: "Damaged",
          occurred_at: DateTime.utc_now()
        })

      # Reload with aggregate: 100 - 25 + 50 - 10 = 115
      {:ok, inventory} = Ash.load(inventory, :current_quantity, reuse_values?: false)
      assert inventory.current_quantity == 115
    end

    test "only includes events for the specific location and product" do
      org1 = organization() |> Ash.Generator.generate()
      location1 = location(organization_id: org1.id) |> Ash.Generator.generate()
      org2 = organization() |> Ash.Generator.generate()
      location2 = location(organization_id: org2.id) |> Ash.Generator.generate()
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      # Create inventory for location1 + product1
      {:ok, inventory1} =
        Inventory.create_location_inventory(%{
          location_id: location1.id,
          product_id: product1.id
        })

      # Create inventory for location2 + product1
      {:ok, inventory2} =
        Inventory.create_location_inventory(%{
          location_id: location2.id,
          product_id: product1.id
        })

      # Create inventory for location1 + product2
      {:ok, inventory3} =
        Inventory.create_location_inventory(%{
          location_id: location1.id,
          product_id: product2.id
        })

      # Add events for location1 + product1
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      # Add events for location2 + product1 (different location)
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location2.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      # Add events for location1 + product2 (different product)
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product2.id,
          event_type: :purchase_received,
          quantity_change: 75,
          occurred_at: DateTime.utc_now()
        })

      # Reload and check each inventory
      {:ok, inventory1} = Ash.load(inventory1, :current_quantity, reuse_values?: false)
      {:ok, inventory2} = Ash.load(inventory2, :current_quantity, reuse_values?: false)
      {:ok, inventory3} = Ash.load(inventory3, :current_quantity, reuse_values?: false)

      assert inventory1.current_quantity == 100
      assert inventory2.current_quantity == 50
      assert inventory3.current_quantity == 75
    end

    test "handles adjustments (both positive and negative)" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Initial purchase
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      # Positive adjustment (found additional stock)
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :adjustment,
          quantity_change: 10,
          reason: "Found in secondary storage",
          occurred_at: DateTime.utc_now()
        })

      # Negative adjustment (physical count discrepancy)
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :adjustment,
          quantity_change: -5,
          reason: "Physical count discrepancy",
          occurred_at: DateTime.utc_now()
        })

      # Reload: 100 + 10 - 5 = 105
      {:ok, inventory} = Ash.load(inventory, :current_quantity, reuse_values?: false)
      assert inventory.current_quantity == 105
    end
  end

  describe "get_inventory_by_location/1" do
    test "returns inventories filtered by location" do
      org1 = organization() |> Ash.Generator.generate()
      location1 = location(organization_id: org1.id) |> Ash.Generator.generate()
      org2 = organization() |> Ash.Generator.generate()
      location2 = location(organization_id: org2.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inv1} =
        Inventory.create_location_inventory(%{
          location_id: location1.id,
          product_id: product.id
        })

      {:ok, _inv2} =
        Inventory.create_location_inventory(%{
          location_id: location2.id,
          product_id: product.id
        })

      assert {:ok, inventories} = Inventory.get_inventory_by_location(%{location_id: location1.id})

      assert length(inventories) == 1
      assert hd(inventories).id == inv1.id
    end
  end

  describe "get_inventory_by_product/1" do
    test "returns inventories filtered by product" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      {:ok, inv1} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product1.id
        })

      {:ok, _inv2} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product2.id
        })

      assert {:ok, inventories} = Inventory.get_inventory_by_product(%{product_id: product1.id})

      assert length(inventories) == 1
      assert hd(inventories).id == inv1.id
    end
  end

  describe "destroy_location_inventory/1" do
    test "deletes an inventory record" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      assert :ok = Inventory.destroy_location_inventory(inventory)

      assert {:ok, inventories} = Inventory.list_location_inventories()
      refute Enum.any?(inventories, &(&1.id == inventory.id))
    end
  end

  describe "relationship loading" do
    test "loads location relationship" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id, name: "Test Location") |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Load with location relationship
      {:ok, inventory_with_location} = Inventory.get_location_inventory(inventory.id, load: [:location])

      assert inventory_with_location.location.id == location.id
      assert inventory_with_location.location.name == "Test Location"
    end

    test "loads product relationship" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product(title: "Test Product") |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Load with product relationship
      {:ok, inventory_with_product} = Inventory.get_location_inventory(inventory.id, load: [:product])

      assert inventory_with_product.product.id == product.id
      assert inventory_with_product.product.title == "Test Product"
    end

    test "loads inventory_events relationship" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Create some inventory events
      {:ok, _event1} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event2} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :administered,
          quantity_change: -10,
          occurred_at: DateTime.utc_now()
        })

      # Load with inventory_events relationship
      {:ok, inventory_with_events} = Inventory.get_location_inventory(inventory.id, load: [:inventory_events])

      assert length(inventory_with_events.inventory_events) == 2
      event_types = Enum.map(inventory_with_events.inventory_events, & &1.event_type)
      assert :purchase_received in event_types
      assert :administered in event_types
    end

    test "loads all relationships at once" do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id, name: "Full Test Location") |> Ash.Generator.generate()
      product = product(title: "Full Test Product") |> Ash.Generator.generate()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id
        })

      # Create an inventory event
      {:ok, _event} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      # Load all relationships
      {:ok, fully_loaded} = Inventory.get_location_inventory(inventory.id, load: [:location, :product, :inventory_events])

      assert fully_loaded.location.name == "Full Test Location"
      assert fully_loaded.product.title == "Full Test Product"
      assert length(fully_loaded.inventory_events) == 1
    end
  end
end