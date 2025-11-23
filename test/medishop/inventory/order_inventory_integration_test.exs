defmodule Medishop.Inventory.OrderInventoryIntegrationTest do
  use Medishop.DataCase

  alias Medishop.Inventory
  alias Medishop.Shop

  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures

  describe "order delivery creates inventory events" do
    setup do
      organization = organization_fixture()
      location = location_fixture(organization.id)
      user = user_fixture()
      product1 = product_fixture()
      product2 = product_fixture()

      # Create location inventory records (required for tracking)
      {:ok, _inv1} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product1.id
        })

      {:ok, _inv2} =
        Inventory.create_location_inventory(%{
          location_id: location.id,
          product_id: product2.id
        })

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
      {:ok, order} =
        Shop.create_order(%{
          location_id: location.id,
          user_id: user.id,
          status: :pending,
          subtotal: Decimal.new("150.00"),
          total: Decimal.new("150.00")
        })

      # Add order items
      {:ok, _item1} =
        Shop.create_order_item(%{
          order_id: order.id,
          product_id: product1.id,
          quantity: 100,
          unit_price: Decimal.new("1.00"),
          line_total: Decimal.new("100.00")
        })

      {:ok, _item2} =
        Shop.create_order_item(%{
          order_id: order.id,
          product_id: product2.id,
          quantity: 50,
          unit_price: Decimal.new("1.00"),
          line_total: Decimal.new("50.00")
        })

      # Initially, no inventory events should exist for these products at this location
      {:ok, events_before} = Inventory.list_inventory_events()
      location_events_before = Enum.filter(events_before, &(&1.location_id == location.id))
      assert length(location_events_before) == 0

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
      {:ok, order} =
        Shop.create_order(%{
          location_id: location.id,
          user_id: user.id,
          status: :pending,
          subtotal: Decimal.new("150.00"),
          total: Decimal.new("150.00")
        })

      {:ok, _item1} =
        Shop.create_order_item(%{
          order_id: order.id,
          product_id: product1.id,
          quantity: 100,
          unit_price: Decimal.new("1.00"),
          line_total: Decimal.new("100.00")
        })

      {:ok, _item2} =
        Shop.create_order_item(%{
          order_id: order.id,
          product_id: product2.id,
          quantity: 50,
          unit_price: Decimal.new("1.00"),
          line_total: Decimal.new("50.00")
        })

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
      {:ok, order} =
        Shop.create_order(%{
          location_id: location.id,
          user_id: user.id,
          status: :pending,
          subtotal: Decimal.new("100.00"),
          total: Decimal.new("100.00")
        })

      {:ok, _item} =
        Shop.create_order_item(%{
          order_id: order.id,
          product_id: product1.id,
          quantity: 100,
          unit_price: Decimal.new("1.00"),
          line_total: Decimal.new("100.00")
        })

      # Cancel the order (before delivery)
      {:ok, cancelled_order} = Shop.update_order_status(order, :cancelled)
      assert cancelled_order.status == :cancelled

      # No inventory events should be created
      {:ok, events} = Inventory.list_inventory_events()
      order_events = Enum.filter(events, &(&1.reference_id == order.id))
      assert length(order_events) == 0

      # Inventory should remain at 0
      {:ok, inv} =
        Inventory.get_inventory_by_location(%{location_id: location.id})
        |> then(fn {:ok, invs} -> {:ok, Enum.find(invs, &(&1.product_id == product1.id))} end)

      {:ok, inv} = Ash.load(inv, :current_quantity, reuse_values?: false)
      assert inv.current_quantity == 0
    end
  end
end
