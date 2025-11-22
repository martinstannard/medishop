defmodule Medishop.Shop.OrderItemTest do
  use Medishop.DataCase

  alias Medishop.Shop

  import Medishop.ProductsFixtures
  import Medishop.ShopFixtures

  describe "create_order_item/1 (from cart)" do
    test "order item created from cart item" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item =
        cart_item_fixture(cart.id, scenario.product.id, %{
          quantity: 2,
          price_at_addition: Decimal.new("15.00")
        })

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      assert order_item != nil
      assert order_item.order_id == order.id
      assert order_item.product_id == scenario.product.id
    end

    test "order_item has correct quantity" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 5})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      assert order_item.quantity == 5
    end

    test "order_item has correct unit_price" do
      scenario = setup_shop_scenario(%{product_attrs: %{price: Decimal.new("22.50")}})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 1})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      assert Decimal.eq?(order_item.unit_price, Decimal.new("22.50"))
    end

    test "order_item has correct line_total" do
      scenario = setup_shop_scenario(%{product_attrs: %{price: Decimal.new("12.00")}})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 4})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      # 4 * 12.00 = 48.00
      expected_total = Decimal.new("48.00")
      assert Decimal.eq?(order_item.line_total, expected_total)
    end

    test "line_total calculation (quantity * unit_price)" do
      scenario = setup_shop_scenario(%{product_attrs: %{price: Decimal.new("7.50")}})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 3})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      # 3 * 7.50 = 22.50
      expected = Decimal.mult(Decimal.new("7.50"), Decimal.new(3))
      assert Decimal.eq?(order_item.line_total, expected)
    end
  end

  describe "order_item immutability" do
    test "order_item update should fail (immutable)" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      order_item =
        order_item_fixture(order.id, scenario.product.id, %{quantity: 2})

      # Attempt to update - Ash doesn't define an update action, so this should raise
      # The :update action doesn't exist on OrderItem
      assert_raise ArgumentError, ~r/No such update action/, fn ->
        order_item
        |> Ash.Changeset.for_update(:update, %{quantity: 5})
        |> Ash.update()
      end
    end
  end

  describe "order_item relationships" do
    test "order_item belongs_to :order relationship" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 1})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      # Load order_item with order
      {:ok, item_with_order} = Shop.get_order_item(order_item.id, load: [:order])

      assert item_with_order.order.id == order.id
    end

    test "order_item belongs_to :product relationship" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      _item = cart_item_fixture(cart.id, scenario.product.id, %{quantity: 1})

      {:ok, order} = Shop.create_order_from_cart(cart.id, scenario.user.id)

      {:ok, order_with_items} = Shop.get_order(order.id, load: [:order_items])
      order_item = Enum.at(order_with_items.order_items, 0)

      # Load order_item with product
      {:ok, item_with_product} = Shop.get_order_item(order_item.id, load: [:product])

      assert item_with_product.product.id == scenario.product.id
      assert item_with_product.product.sku == scenario.product.sku
    end

    test "loading order_item with order preloaded" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      order_item =
        order_item_fixture(order.id, scenario.product.id, %{quantity: 1})

      {:ok, loaded_item} = Shop.get_order_item(order_item.id, load: [:order])

      assert loaded_item.order.id == order.id
      assert loaded_item.order.order_number == order.order_number
    end

    test "loading order_item with product preloaded" do
      scenario = setup_shop_scenario()
      order = order_fixture(scenario.location.id, scenario.user.id)

      order_item =
        order_item_fixture(order.id, scenario.product.id, %{quantity: 1})

      {:ok, loaded_item} = Shop.get_order_item(order_item.id, load: [:product])

      assert loaded_item.product.id == scenario.product.id
      assert loaded_item.product.title == scenario.product.title
    end
  end
end
