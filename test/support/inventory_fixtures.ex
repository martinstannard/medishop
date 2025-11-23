defmodule Medishop.InventoryFixtures do
  @moduledoc """
  This module defines test fixtures for the Inventory domain.
  """

  alias Medishop.Inventory

  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures

  @doc """
  Generate a location inventory record.
  Note: Current quantity is calculated from inventory events, not stored directly.
  """
  def location_inventory_fixture(location_id, product_id, _attrs \\ %{}) do
    {:ok, inventory} =
      Inventory.create_location_inventory(%{
        location_id: location_id,
        product_id: product_id
      })

    inventory
  end

  @doc """
  Generate a location inventory record with auto-created location and product.
  """
  def location_inventory_fixture(attrs \\ %{}) do
    organization = organization_fixture()
    location = location_fixture(organization.id)
    product = product_fixture()

    location_inventory_fixture(location.id, product.id, attrs)
  end
end
