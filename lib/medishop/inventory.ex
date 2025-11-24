defmodule Medishop.Inventory do
  @moduledoc """
  The Inventory domain manages location-based product inventory and stock reconciliation.

  This domain handles:
  - Inventory levels per location
  - Stock tracking for each product at each location
  - Inventory queries by location or product
  - Event-sourced inventory movements (purchases, usage, adjustments)
  - Physical stock take reconciliations
  - Discrepancy tracking and adjustment event creation
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
      define :get_location_inventory_by_location_and_product, action: :read, get_by: [:location_id, :product_id]
      define :destroy_location_inventory, action: :destroy
    end

    resource Medishop.Inventory.InventoryEvent do
      define :create_inventory_event, action: :create
      define :list_inventory_events, action: :read
      define :get_inventory_event, action: :read, get_by: [:id]
      define :get_events_by_location_and_product, action: :by_location_and_product
      define :get_events_by_location, action: :by_location
      define :get_events_by_product, action: :by_product
    end

    resource Medishop.Inventory.StockReconciliation do
      define :create_reconciliation, action: :create
      define :list_reconciliations, action: :read
      define :get_reconciliation, action: :read, get_by: [:id]
      define :get_reconciliations_by_location, action: :by_location
      define :get_reconciliations_by_status, action: :by_status
      define :get_in_progress_reconciliation, action: :in_progress_by_location
      define :update_reconciliation, action: :update
      define :complete_reconciliation, action: :complete
      define :cancel_reconciliation, action: :cancel
      define :destroy_reconciliation, action: :destroy
    end

    resource Medishop.Inventory.ReconciliationItem do
      define :create_reconciliation_item, action: :create
      define :list_reconciliation_items, action: :read
      define :get_reconciliation_item, action: :read, get_by: [:id]
      define :get_items_by_reconciliation, action: :by_reconciliation
      define :get_items_with_discrepancies, action: :with_discrepancies
      define :update_reconciliation_item, action: :update
      define :bulk_create_reconciliation_items, action: :bulk_create
      define :destroy_reconciliation_item, action: :destroy
    end
  end
end
