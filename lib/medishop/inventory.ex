defmodule Medishop.Inventory do
  @moduledoc """
  The Inventory domain manages location-based product inventory.

  This domain handles:
  - Inventory levels per location
  - Stock tracking for each product at each location
  - Inventory queries by location or product
  """
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Inventory.LocationInventory do
      define :create_location_inventory, action: :create
      define :list_location_inventories, action: :read
      define :get_location_inventory, action: :read, get_by: [:id]
      define :get_inventory_by_location, action: :get_by_location
      define :get_inventory_by_product, action: :get_by_product
      define :update_location_inventory, action: :update
      define :destroy_location_inventory, action: :destroy
    end
  end
end
