defmodule Medishop.Inventory.OrderInventoryIntegrationTest do
  use Medishop.DataCase

  alias Medishop.Inventory
  alias Medishop.Shop

  import Medishop.Generator

  describe "order delivery creates inventory events" do
    setup do
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()
      user = user() |> Ash.Generator.generate()
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      # Create location inventory records (required for tracking)
      _inv1 = location_inventory(location_id: location.id, product_id: product1.id) |> Ash.Generator.generate()
      _inv2 = location_inventory(location_id: location.id, product_id: product2.id) |> Ash.Generator.generate()

      %{
        location: location,
        user: user,
        product1: product1,
        product2: product2
      }
    end

    test "marking order as delivered creates inventory events", %{
      location: location,
      user: user,
      product1: product1,
      product2: product2
    } do
      # Create an order
      order = order(
        location_id: location.id,
        user_id: user.id,
        status: :pending,
        subtotal: Decimal.new("150.00"),
        total: Decimal.new("150.00")
      ) |> Ash.Generator.generate()

      # Add order items
      _item1 = order_item(
        order_id: order.id,
        product_id: product1.id,
        quantity: 100,
        unit_price: Decimal.new("1.00"),
        line_total: Decimal.new("100.00")
      ) |> Ash.Generator.generate()

      _item2 = order_item(
        order_id: order.id,
        product_id: product2.id,
        quantity: 50,
        unit_price: Decimal.new("1.00"),
        line_total: Decimal.new("50.00")
      ) |> Ash.Generator.generate()

      # Initially, no inventory events should exist for these products at this location
      {:ok, events_before} = Inventory.list_inventory_events()
      location_events_before = Enum.filter(events_before, &(&1.location_id == location.id))
      assert Enum.empty?(location_events_before)

      # Mark order as delivered (must follow proper workflow)
      {:ok, order} = Shop.update_order_status(order, :confirmed)
      {:ok, order} = Shop.update_order_status(order, :shipped)
      {:ok, _delivered_order} = Shop.update_order_status(order, :delivered)

      # Verify events were created
      {:ok, events_after} = Inventory.list_inventory_events()
      location_events_after = Enum.filter(events_after, &(&1.location_id == location.id))
      assert length(location_events_after) == 2

      # Verify event details
      order_events = Enum.filter(location_events_after, &(&1.reference_id == order.id))
      assert length(order_events) == 2

      # Check quantities
      event1 = Enum.find(order_events, &(&1.product_id == product1.id))
      event2 = Enum.find(order_events, &(&1.product_id == product2.id))

      assert event1.quantity_change == 100
      assert event1.event_type == :purchase_received
      assert event2.quantity_change == 50
      assert event2.event_type == :purchase_received
    end

    test "inventory quantities are updated after order delivery", %{
      location: location,
      user: user,
      product1: product1,
      product2: product2
    } do
      # Create an order with items
      order = order(
        location_id: location.id,
        user_id: user.id,
        status: :pending,
        subtotal: Decimal.new("150.00"),
        total: Decimal.new("150.00")
      ) |> Ash.Generator.generate()

      _item1 = order_item(
        order_id: order.id,
        product_id: product1.id,
        quantity: 100,
        unit_price: Decimal.new("1.00"),
        line_total: Decimal.new("100.00")
      ) |> Ash.Generator.generate()

      _item2 = order_item(
        order_id: order.id,
        product_id: product2.id,
        quantity: 50,
        unit_price: Decimal.new("1.00"),
        line_total: Decimal.new("50.00")
      ) |> Ash.Generator.generate()

      # Check initial inventory (should be 0)
      {:ok, inv1_before} =
        Inventory.get_inventory_by_location(%{location_id: location.id})
        |> then(fn {:ok, invs} -> {:ok, Enum.find(invs, &(&1.product_id == product1.id))} end)

      {:ok, inv1_before} = Ash.load(inv1_before, :current_quantity, reuse_values?: false)
      assert inv1_before.current_quantity == 0

      # Mark order as delivered (must follow proper workflow)
      {:ok, order} = Shop.update_order_status(order, :confirmed)
      {:ok, order} = Shop.update_order_status(order, :shipped)
      {:ok, _delivered_order} = Shop.update_order_status(order, :delivered)

      # Check updated inventory
      {:ok, inv1_after} =
        Inventory.get_inventory_by_location(%{location_id: location.id})
        |> then(fn {:ok, invs} -> {:ok, Enum.find(invs, &(&1.product_id == product1.id))} end)

      {:ok, inv2_after} =
        Inventory.get_inventory_by_location(%{location_id: location.id})
        |> then(fn {:ok, invs} -> {:ok, Enum.find(invs, &(&1.product_id == product2.id))} end)

      {:ok, inv1_after} = Ash.load(inv1_after, :current_quantity, reuse_values?: false)
      {:ok, inv2_after} = Ash.load(inv2_after, :current_quantity, reuse_values?: false)

      assert inv1_after.current_quantity == 100
      assert inv2_after.current_quantity == 50
    end

    test "cancelled orders before delivery do not create inventory events", %{
      location: location,
      user: user,
      product1: product1
    } do
      # Create an order
      order = order(
        location_id: location.id,
        user_id: user.id,
        status: :pending,
        subtotal: Decimal.new("100.00"),
        total: Decimal.new("100.00")
      ) |> Ash.Generator.generate()

      _item = order_item(
        order_id: order.id,
        product_id: product1.id,
        quantity: 100,
        unit_price: Decimal.new("1.00"),
        line_total: Decimal.new("100.00")
      ) |> Ash.Generator.generate()

      # Cancel the order (before delivery)
      {:ok, cancelled_order} = Shop.update_order_status(order, :cancelled)
      assert cancelled_order.status == :cancelled

      # No inventory events should be created
      {:ok, events} = Inventory.list_inventory_events()
      order_events = Enum.filter(events, &(&1.reference_id == order.id))
      assert Enum.empty?(order_events)

      # Inventory should remain at 0
      {:ok, inv} =
        Inventory.get_inventory_by_location(%{location_id: location.id})
        |> then(fn {:ok, invs} -> {:ok, Enum.find(invs, &(&1.product_id == product1.id))} end)

      {:ok, inv} = Ash.load(inv, :current_quantity, reuse_values?: false)
      assert inv.current_quantity == 0
    end
  end
end