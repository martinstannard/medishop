defmodule Medishop.Inventory.ReconciliationWorkflowTest do
  use Medishop.DataCase, async: true
  import Medishop.Generator

  alias Medishop.Inventory

  describe "complete_reconciliation/2 with adjustment event creation" do
    test "creates inventory events for items with discrepancies" do
      # Setup: Create reconciliation with items
      location = location() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      # Create inventory with some initial stock
      _initial_event =
        inventory_event(
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 50
        )
        |> Ash.Generator.generate()

      loc_inv =
        location_inventory(location_id: location.id, product_id: product.id)
        |> Ash.Generator.generate()

      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      # Create reconciliation item with discrepancy
      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 50,
          physical_quantity: 45,
          adjustment_reason: :breakage,
          adjustment_notes: "Found damaged units"
        })

      # Complete the reconciliation
      {:ok, completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 1,
          total_discrepancies: 1,
          total_adjustments_made: 1
        })

      assert completed.status == :completed

      # Verify inventory event was created
      {:ok, events} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product.id
        })

      adjustment_events =
        Enum.filter(events, fn event -> event.event_type == :adjustment end)

      assert length(adjustment_events) == 1
      event = List.first(adjustment_events)

      assert event.quantity_change == -5
      assert event.event_type == :adjustment
      assert event.reason == "Breakage: Found damaged units"
      assert event.reference_type == "StockReconciliation"
      assert event.reference_id == reconciliation.id

      # Verify the reconciliation item was updated with the event ID
      {:ok, updated_item} = Inventory.get_reconciliation_item(item.id)
      assert updated_item.inventory_event_id == event.id
    end

    test "creates events for multiple discrepancies" do
      location = location() |> Ash.Generator.generate()
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      # Create initial inventory
      _event1 =
        inventory_event(
          location_id: location.id,
          product_id: product1.id,
          quantity_change: 100
        )
        |> Ash.Generator.generate()

      _event2 =
        inventory_event(
          location_id: location.id,
          product_id: product2.id,
          quantity_change: 50
        )
        |> Ash.Generator.generate()

      loc_inv1 =
        location_inventory(location_id: location.id, product_id: product1.id)
        |> Ash.Generator.generate()

      loc_inv2 =
        location_inventory(location_id: location.id, product_id: product2.id)
        |> Ash.Generator.generate()

      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      # Create items with different discrepancies
      {:ok, _item1} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product1.id,
          location_inventory_id: loc_inv1.id,
          system_quantity: 100,
          physical_quantity: 95,
          adjustment_reason: :theft
        })

      {:ok, _item2} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product2.id,
          location_inventory_id: loc_inv2.id,
          system_quantity: 50,
          physical_quantity: 52,
          adjustment_reason: :count_error
        })

      # Complete reconciliation
      {:ok, _completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 2,
          total_discrepancies: 2,
          total_adjustments_made: 2
        })

      # Verify both adjustment events were created
      {:ok, events1} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product1.id
        })

      {:ok, events2} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product2.id
        })

      adj_events1 = Enum.filter(events1, fn e -> e.event_type == :adjustment end)
      adj_events2 = Enum.filter(events2, fn e -> e.event_type == :adjustment end)

      assert length(adj_events1) == 1
      assert length(adj_events2) == 1

      event1 = List.first(adj_events1)
      event2 = List.first(adj_events2)

      assert event1.quantity_change == -5
      assert event1.reason == "Theft"

      assert event2.quantity_change == 2
      assert event2.reason == "Count Error"
    end

    test "does not create events for items without discrepancies" do
      location = location() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      _initial_event =
        inventory_event(
          location_id: location.id,
          product_id: product.id,
          quantity_change: 50
        )
        |> Ash.Generator.generate()

      loc_inv =
        location_inventory(location_id: location.id, product_id: product.id)
        |> Ash.Generator.generate()

      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      # Create item without discrepancy
      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 50,
          physical_quantity: 50
        })

      # Complete reconciliation
      {:ok, _completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 1,
          total_discrepancies: 0,
          total_adjustments_made: 0
        })

      # Verify no adjustment event was created
      {:ok, events} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product.id
        })

      adjustment_events =
        Enum.filter(events, fn event -> event.event_type == :adjustment end)

      assert length(adjustment_events) == 0

      # Verify the item was NOT updated with an event ID
      {:ok, updated_item} = Inventory.get_reconciliation_item(item.id)
      assert is_nil(updated_item.inventory_event_id)
    end

    test "updates inventory quantities correctly after completion" do
      location = location() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      # Create initial inventory of 100
      _initial_event =
        inventory_event(
          location_id: location.id,
          product_id: product.id,
          quantity_change: 100
        )
        |> Ash.Generator.generate()

      loc_inv =
        location_inventory(location_id: location.id, product_id: product.id)
        |> Ash.Generator.generate()

      # Verify initial quantity
      {:ok, initial_inv} =
        Inventory.get_inventory_by_location(%{location_id: location.id})

      initial = Enum.find(initial_inv, fn inv -> inv.product_id == product.id end)
      {:ok, initial_loaded} = Ash.load(initial, :current_quantity)
      assert initial_loaded.current_quantity == 100

      # Create reconciliation with discrepancy (found only 95)
      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      {:ok, _item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 100,
          physical_quantity: 95,
          adjustment_reason: :breakage
        })

      # Complete reconciliation
      {:ok, _completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 1,
          total_discrepancies: 1,
          total_adjustments_made: 1
        })

      # Verify quantity was updated to 95 (100 - 5)
      {:ok, updated_inv} =
        Inventory.get_inventory_by_location(%{location_id: location.id})

      updated = Enum.find(updated_inv, fn inv -> inv.product_id == product.id end)
      {:ok, updated_loaded} = Ash.load(updated, :current_quantity)
      assert updated_loaded.current_quantity == 95
    end

    test "formats adjustment reasons correctly" do
      location = location() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      _initial_event =
        inventory_event(
          location_id: location.id,
          product_id: product.id,
          quantity_change: 50
        )
        |> Ash.Generator.generate()

      loc_inv =
        location_inventory(location_id: location.id, product_id: product.id)
        |> Ash.Generator.generate()

      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      # Test reason with notes
      {:ok, _item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 50,
          physical_quantity: 48,
          adjustment_reason: :other,
          adjustment_notes: "Custom explanation for discrepancy"
        })

      {:ok, _completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 1,
          total_discrepancies: 1,
          total_adjustments_made: 1
        })

      # Verify reason was formatted with notes
      {:ok, events} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product.id
        })

      adjustment_event =
        Enum.find(events, fn event -> event.event_type == :adjustment end)

      assert adjustment_event.reason == "Other: Custom explanation for discrepancy"
    end

    test "sets occurred_at to reconciliation completed_at time" do
      location = location() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      _initial_event =
        inventory_event(
          location_id: location.id,
          product_id: product.id,
          quantity_change: 50
        )
        |> Ash.Generator.generate()

      loc_inv =
        location_inventory(location_id: location.id, product_id: product.id)
        |> Ash.Generator.generate()

      reconciliation =
        stock_reconciliation(location_id: location.id) |> Ash.Generator.generate()

      {:ok, _item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 50,
          physical_quantity: 45,
          adjustment_reason: :spillage
        })

      # Get time before completion
      before_complete = DateTime.utc_now()

      {:ok, completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 1,
          total_discrepancies: 1,
          total_adjustments_made: 1
        })

      # Verify the adjustment event occurred_at matches completed_at
      {:ok, events} =
        Inventory.get_events_by_location_and_product(%{
          location_id: location.id,
          product_id: product.id
        })

      adjustment_event =
        Enum.find(events, fn event -> event.event_type == :adjustment end)

      # The event should have occurred_at close to completed_at
      assert DateTime.compare(adjustment_event.occurred_at, before_complete) in [:gt, :eq]

      # Should be within a second of completed_at
      diff = DateTime.diff(adjustment_event.occurred_at, completed.completed_at, :second)
      assert abs(diff) <= 1
    end
  end
end
