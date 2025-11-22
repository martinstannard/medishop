defmodule Medishop.Inventory.LocationInventoryTest do
  use Medishop.DataCase

  alias Medishop.Inventory

  import Medishop.InventoryFixtures
  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures

  describe "create_location_inventory/1" do
    test "creates inventory for location+product combination" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      assert {:ok, inventory} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id,
                 quantity_available: 50
               })

      assert inventory.location_id == location.id
      assert inventory.product_id == product.id
      assert inventory.quantity_available == 50
    end

    test "quantity_available defaults to 0" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      assert {:ok, inventory} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id
               })

      assert inventory.quantity_available == 0
    end

    test "enforces unique constraint on location+product" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      {:ok, _inventory1} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id,
          quantity_available: 50
        })

      # Try to create duplicate
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id,
                 quantity_available: 100
               })
    end

    test "validates quantity_available must be non-negative" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id,
                 quantity_available: -10
               })
    end

    test "allows quantity_available to be zero" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      assert {:ok, inventory} =
               Inventory.create_location_inventory(%{
                 location_id: location.id,
                 product_id: product.id,
                 quantity_available: 0
               })

      assert inventory.quantity_available == 0
    end
  end

  describe "update_location_inventory/2" do
    test "updates quantity_available" do
      inventory = location_inventory_fixture()

      assert {:ok, updated_inventory} =
               Inventory.update_location_inventory(inventory, %{
                 quantity_available: 200
               })

      assert updated_inventory.quantity_available == 200
    end
  end

  describe "destroy_location_inventory/1" do
    test "deletes inventory record" do
      inventory = location_inventory_fixture()

      assert :ok = Inventory.destroy_location_inventory(inventory)

      assert {:ok, inventories} = Inventory.list_location_inventories()
      refute Enum.any?(inventories, &(&1.id == inventory.id))
    end
  end

  describe "relationships" do
    test "belongs_to :location relationship" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id,
          quantity_available: 50
        })

      assert {:ok, loaded_inventory} = Ash.load(inventory, :location)
      assert loaded_inventory.location.id == location.id
      assert loaded_inventory.location.name == location.name
    end

    test "belongs_to :product relationship" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id,
          quantity_available: 50
        })

      assert {:ok, loaded_inventory} = Ash.load(inventory, :product)
      assert loaded_inventory.product.id == product.id
      assert loaded_inventory.product.sku == product.sku
    end

    test "loads inventory with location preloaded" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id,
          quantity_available: 50
        })

      assert {:ok, loaded_inventory} = Ash.load(inventory, [:location])
      assert loaded_inventory.location.id == location.id
    end

    test "loads inventory with product preloaded" do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      product = product_fixture()

      {:ok, inventory} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product.id,
          quantity_available: 50
        })

      assert {:ok, loaded_inventory} = Ash.load(inventory, [:product])
      assert loaded_inventory.product.id == product.id
    end
  end

  describe "get_inventory_by_location/1" do
    test "filters inventory by location correctly" do
      organization = organization_fixture()
      location1 = location_fixture(organization.id)
      location2 = location_fixture(organization.id)
      product1 = product_fixture()
      product2 = product_fixture()

      {:ok, inv1} =
        Inventory.create_location_inventory(%{
          location_id: location1.id,
          product_id: product1.id,
          quantity_available: 50
        })

      {:ok, _inv2} =
        Inventory.create_location_inventory(%{
          location_id: location2.id,
          product_id: product2.id,
          quantity_available: 75
        })

      assert {:ok, results} = Inventory.get_inventory_by_location(%{location_id: location1.id})

      result_ids = Enum.map(results, & &1.id)
      assert inv1.id in result_ids
      assert length(results) == 1
    end
  end

  describe "get_inventory_by_product/1" do
    test "filters inventory by product correctly" do
      organization = organization_fixture()
      location1 = location_fixture(organization.id)
      location2 = location_fixture(organization.id)
      product1 = product_fixture()
      product2 = product_fixture()

      {:ok, inv1} =
        Inventory.create_location_inventory(%{
          location_id: location1.id,
          product_id: product1.id,
          quantity_available: 50
        })

      {:ok, _inv2} =
        Inventory.create_location_inventory(%{
          location_id: location2.id,
          product_id: product2.id,
          quantity_available: 75
        })

      assert {:ok, results} = Inventory.get_inventory_by_product(%{product_id: product1.id})

      result_ids = Enum.map(results, & &1.id)
      assert inv1.id in result_ids
      assert length(results) == 1
    end
  end
end
