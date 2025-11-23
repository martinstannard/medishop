defmodule Medishop.Shop.OrderTest do
  use Medishop.DataCase

  alias Medishop.Shop

  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures
  import Medishop.ShopFixtures

  describe "create_order/1" do
    test "creates an order" do
      scenario = setup_shop_scenario()

      assert {:ok, order} =
               Shop.create_order(%{
                 location_id: scenario.location.id,
                 user_id: scenario.user.id,
                 status: :pending,
                 subtotal: Decimal.new("100.00"),
                 total: Decimal.new("100.00")
               })

      assert order.location_id == scenario.location.id
      assert order.user_id == scenario.user.id
      assert order.status == :pending
      assert Decimal.eq?(order.subtotal, Decimal.new("100.00"))
      assert Decimal.eq?(order.total, Decimal.new("100.00"))
    end

    test "order_number is auto-generated" do
      scenario = setup_shop_scenario()

      {:ok, order} =
        Shop.create_order(%{
          location_id: scenario.location.id,
          user_id: scenario.user.id,
          status: :pending,
          subtotal: Decimal.new("50.00"),
          total: Decimal.new("50.00")
        })

      assert order.order_number != nil
      assert String.starts_with?(order.order_number, "ORD-")
    end

    test "order_number is unique" do
      scenario = setup_shop_scenario()

      order1 = order_fixture(scenario.location.id, scenario.user.id)
      order2 = order_fixture(scenario.location.id, scenario.user.id)

      assert order1.order_number != order2.order_number
    end

    test "order_number format is consistent" do
      scenario = setup_shop_scenario()

      order = order_fixture(scenario.location.id, scenario.user.id)

      # Format: ORD-YYYYMMDD-XXXXXX
      assert String.match?(order.order_number, ~r/^ORD-\d{8}-[A-F0-9]{6}$/)
    end

    test "order status defaults to :pending" do
      scenario = setup_shop_scenario()

      {:ok, order} =
        Shop.create_order(%{
          location_id: scenario.location.id,
          user_id: scenario.user.id,
          subtotal: Decimal.new("50.00"),
          total: Decimal.new("50.00")
        })

      assert order.status == :pending
    end

    test "placed_at timestamp is set on creation" do
      scenario = setup_shop_scenario()

      order = order_fixture(scenario.location.id, scenario.user.id)

      assert order.placed_at != nil
      # Should be recent (within last minute)
      assert DateTime.diff(DateTime.utc_now(), order.placed_at) < 60
    end

    test "order with notes" do
      scenario = setup_shop_scenario()

      {:ok, order} =
        Shop.create_order(%{
          location_id: scenario.location.id,
          user_id: scenario.user.id,
          status: :pending,
          subtotal: Decimal.new("50.00"),
          total: Decimal.new("50.00"),
          notes: "Urgent delivery required"
        })

      assert order.notes == "Urgent delivery required"
    end
  end

  describe "create_order_from_cart/3" do
    test "creates order from cart" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      # Add items to cart
      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      assert order.location_id == scenario.location.id
      assert order.user_id == scenario.user.id
      assert order.status == :pending
    end

    test "create_from_cart copies all cart items correctly" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      product2 = product_fixture(%{sku: "PROD-002", price: Decimal.new("20.00")})

      _item1 = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})
      _item2 = cart_item_fixture(cart.id, product2.id, %{quantity: 3})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Load order with items
      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])

      assert length(order_with_items.order_items) == 2
    end

    test "create_from_cart calculates subtotal correctly" do
      scenario = setup_shop_scenario(%{product_attrs: %{price: Decimal.new("15.00")}})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      product2 = product_fixture(%{sku: "PROD-002", price: Decimal.new("25.00")})

      # 2 * 15.00 = 30.00
      _item1 = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})
      # 3 * 25.00 = 75.00
      _item2 = cart_item_fixture(cart.id, product2.id, %{quantity: 3})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Total should be 30.00 + 75.00 = 105.00
      expected_total = Decimal.new("105.00")
      assert Decimal.eq?(order.subtotal, expected_total)
    end

    test "create_from_cart calculates total correctly" do
      scenario = setup_shop_scenario(%{product_attrs: %{price: Decimal.new("10.00")}})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 5})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # For now, total equals subtotal
      expected = Decimal.new("50.00")
      assert Decimal.eq?(order.total, expected)
      assert Decimal.eq?(order.subtotal, order.total)
    end

    test "create_from_cart clears cart after order creation" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})

      {:ok, _order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Verify cart is empty
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
      assert cart_with_items.cart_items == []
    end
  end

  describe "update_order_status/2" do
    test "status transition: pending → confirmed" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :pending})

      assert {:ok, updated_order} = Shop.update_order_status(order, :confirmed)

      assert updated_order.status == :confirmed
    end

    test "status transition: confirmed → shipped" do
      scenario = setup_shop_scenario()

      order =
        order_fixture(scenario.location.id, scenario.user.id, %{status: :confirmed})

      assert {:ok, updated_order} = Shop.update_order_status(order, :shipped)

      assert updated_order.status == :shipped
    end

    test "status transition: shipped → delivered" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :shipped})

      assert {:ok, updated_order} = Shop.update_order_status(order, :delivered)

      assert updated_order.status == :delivered
    end

    test "status transition: pending → cancelled" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :pending})

      assert {:ok, updated_order} = Shop.update_order_status(order, :cancelled)

      assert updated_order.status == :cancelled
    end

    test "invalid status transition: delivered → pending (should fail)" do
      scenario = setup_shop_scenario()

      order =
        order_fixture(scenario.location.id, scenario.user.id, %{status: :delivered})

      assert {:error, _error} = Shop.update_order_status(order, :pending)
    end

    test "invalid status transition: cancelled → confirmed (should fail)" do
      scenario = setup_shop_scenario()

      order =
        order_fixture(scenario.location.id, scenario.user.id, %{status: :cancelled})

      assert {:error, _error} = Shop.update_order_status(order, :confirmed)
    end

    test "confirmed_at timestamp set on status update to :confirmed" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :pending})

      {:ok, updated_order} = Shop.update_order_status(order, :confirmed)

      assert updated_order.confirmed_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated_order.confirmed_at) < 60
    end

    test "shipped_at timestamp set on status update to :shipped" do
      scenario = setup_shop_scenario()

      order =
        order_fixture(scenario.location.id, scenario.user.id, %{status: :confirmed})

      {:ok, updated_order} = Shop.update_order_status(order, :shipped)

      assert updated_order.shipped_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated_order.shipped_at) < 60
    end

    test "delivered_at timestamp set on status update to :delivered" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :shipped})

      {:ok, updated_order} = Shop.update_order_status(order, :delivered)

      assert updated_order.delivered_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated_order.delivered_at) < 60
    end

    test "cancelled_at timestamp set on status update to :cancelled" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id, %{status: :pending})

      {:ok, updated_order} = Shop.update_order_status(order, :cancelled)

      assert updated_order.cancelled_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated_order.cancelled_at) < 60
    end
  end

  describe "order relationships" do
    test "order belongs_to :location relationship" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      {:ok, order_with_location} = Shop.get_order(order.id, load: [:location])

      assert order_with_location.location.id == scenario.location.id
      assert order_with_location.location.name == scenario.location.name
    end

    test "order belongs_to :user relationship" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      {:ok, order_with_user} = Shop.get_order(order.id, load: [:user])

      assert order_with_user.user.id == scenario.user.id
    end

    test "order has_many :order_items relationship" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      product2 = product_fixture(%{sku: "PROD-002"})

      _item1 = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 1})
      _item2 = cart_item_fixture(cart.id, product2.id, %{quantity: 2})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])

      assert length(order_with_items.order_items) == 2
    end
  end

  describe "get_orders_for_location/1" do
    test "filters correctly by location" do
      scenario = setup_shop_scenario()

      # Create another location
      location2 = location_fixture(scenario.organization.id, %{name: "Location 2"})

      # Create orders for different locations
      order1 = order_fixture(scenario.location.id, scenario.user.id)
      _order2 = order_fixture(location2.id, scenario.user.id)

      {:ok, orders} = Shop.get_orders_for_location(scenario.location.id)

      assert length(orders) == 1
      assert Enum.at(orders, 0).id == order1.id
    end
  end

  describe "get_orders_for_user/1" do
    test "filters correctly by user" do
      scenario = setup_shop_scenario()
      user2 = user_fixture(%{email: "user2@example.com"})

      # Create orders for different users
      order1 = order_fixture(scenario.location.id, scenario.user.id)
      _order2 = order_fixture(scenario.location.id, user2.id)

      {:ok, orders} = Shop.get_orders_for_user(scenario.user.id)

      assert length(orders) == 1
      assert Enum.at(orders, 0).id == order1.id
    end
  end

  describe "destroy_order/1" do
    test "deletes an order" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      assert :ok = Shop.destroy_order(order)

      # Verify order no longer exists
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               Shop.get_order(order.id)
    end
  end

  describe "loading order with all relationships" do
    test "loads order with location, user, and order_items" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, full_order} =
        Shop.get_order(order.id, load: [:location, :user, :order_items])

      assert full_order.location.id == scenario.location.id
      assert full_order.user.id == scenario.user.id
      assert length(full_order.order_items) == 1
    end
  end

  describe "inventory events on delivery" do
    test "creates inventory events when order status changes to delivered" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      # Add multiple products to cart
      product2 = product_fixture(%{sku: "PROD-002"})
      _item1 = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 3})
      _item2 = cart_item_fixture(cart.id, product2.id, %{quantity: 5})

      # Create order from cart
      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Transition order to shipped status first
      {:ok, shipped_order} = Shop.update_order_status(order, :confirmed)
      {:ok, shipped_order} = Shop.update_order_status(shipped_order, :shipped)

      # Verify no inventory events exist yet
      {:ok, events_before} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      assert Enum.empty?(events_before)

      # Transition to delivered - this should create inventory events
      {:ok, delivered_order} = Shop.update_order_status(shipped_order, :delivered)

      # Verify inventory events were created
      {:ok, events_after} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      assert length(events_after) == 2

      # Verify event details for first product
      event1 = Enum.find(events_after, fn e -> e.product_id == scenario.product.id end)
      assert event1.event_type == :purchase_received
      assert event1.quantity_change == 3
      assert event1.location_id == scenario.location.id
      assert event1.reference_type == "Order"
      assert event1.reference_id == delivered_order.id

      # Verify event details for second product
      event2 = Enum.find(events_after, fn e -> e.product_id == product2.id end)
      assert event2.event_type == :purchase_received
      assert event2.quantity_change == 5
      assert event2.location_id == scenario.location.id
      assert event2.reference_type == "Order"
      assert event2.reference_id == delivered_order.id
    end

    test "does not create duplicate events if status is already delivered" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Transition to delivered
      {:ok, order} = Shop.update_order_status(order, :confirmed)
      {:ok, order} = Shop.update_order_status(order, :shipped)
      {:ok, delivered_order} = Shop.update_order_status(order, :delivered)

      # Get events count
      {:ok, events} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      initial_count = length(events)

      # Try to update status to delivered again (should be idempotent)
      {:ok, _still_delivered} = Shop.update_order_status(delivered_order, :delivered)

      # Verify no new events were created
      {:ok, events_after} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      assert length(events_after) == initial_count
    end

    test "inventory events are not created for other status transitions" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 2})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Transition through various statuses (but not delivered)
      {:ok, confirmed_order} = Shop.update_order_status(order, :confirmed)
      {:ok, _shipped_order} = Shop.update_order_status(confirmed_order, :shipped)

      # Verify no inventory events were created
      {:ok, events} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      assert Enum.empty?(events)
    end

    test "creates correct inventory events for order with single item" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 10})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      # Deliver the order
      {:ok, order} = Shop.update_order_status(order, :confirmed)
      {:ok, order} = Shop.update_order_status(order, :shipped)
      {:ok, delivered_order} = Shop.update_order_status(order, :delivered)

      # Verify exactly one event was created
      {:ok, events} = Medishop.Inventory.get_events_by_location(%{location_id: scenario.location.id})
      assert length(events) == 1

      event = Enum.at(events, 0)
      assert event.product_id == scenario.product.id
      assert event.quantity_change == 10
      assert event.event_type == :purchase_received
      assert event.reference_id == delivered_order.id
    end
  end
end
