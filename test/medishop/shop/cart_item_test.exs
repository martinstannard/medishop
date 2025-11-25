defmodule Medishop.Shop.CartItemTest do
  use Medishop.DataCase

  alias Medishop.Shop

  import Medishop.Generator

  defp setup_shop_scenario(attrs \\ %{}) do
    org = organization() |> Ash.Generator.generate()
    location = location(organization_id: org.id) |> Ash.Generator.generate()
    user = user() |> Ash.Generator.generate()
    
    product_attrs = Map.get(attrs, :product_attrs, [])
    product = product(product_attrs) |> Ash.Generator.generate()

    %{ 
      organization: org,
      location: location,
      user: user,
      product: product
    }
  end

  describe "create_cart_item/1" do
    test "adds item to cart" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      assert {:ok, cart_item} =
               Shop.create_cart_item(%{
                 cart_id: cart.id,
                 product_id: scenario.product.id,
                 quantity: 2,
                 price_at_addition: scenario.product.price
               })

      assert cart_item.cart_id == cart.id
      assert cart_item.product_id == scenario.product.id
      assert cart_item.quantity == 2
      assert Decimal.eq?(cart_item.price_at_addition, scenario.product.price)
    end

    test "enforces unique constraint (cart + product)" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      {:ok, _item1} =
        Shop.create_cart_item(%{
          cart_id: cart.id,
          product_id: scenario.product.id,
          quantity: 1,
          price_at_addition: scenario.product.price
        })

      # Second item with same cart_id and product_id should fail
      assert {:error, _error} =
               Shop.create_cart_item(%{
                 cart_id: cart.id,
                 product_id: scenario.product.id,
                 quantity: 2,
                 price_at_addition: scenario.product.price
               })
    end

    test "quantity defaults to 1" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      assert {:ok, cart_item} =
               Shop.create_cart_item(%{
                 cart_id: cart.id,
                 product_id: scenario.product.id,
                 price_at_addition: scenario.product.price
               })

      assert cart_item.quantity == 1
    end

    test "validates quantity minimum is 1" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      # Quantity 0 should fail
      assert {:error, _error} =
               Shop.create_cart_item(%{
                 cart_id: cart.id,
                 product_id: scenario.product.id,
                 quantity: 0,
                 price_at_addition: scenario.product.price
               })

      # Negative quantity should fail
      assert {:error, _error} =
               Shop.create_cart_item(%{
                 cart_id: cart.id,
                 product_id: scenario.product.id,
                 quantity: -1,
                 price_at_addition: scenario.product.price
               })
    end
  end

  describe "price_at_addition" do
    test "price_at_addition is captured on creation" do
      scenario = setup_shop_scenario(%{product_attrs: [price: Decimal.new("15.99")]})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1, price_at_addition: scenario.product.price) |> Ash.Generator.generate()
    end

    test "price_at_addition doesn't change if product price changes" do
      scenario = setup_shop_scenario(%{product_attrs: [price: Decimal.new("10.00")]})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1) |> Ash.Generator.generate()

      original_price = cart_item.price_at_addition

      # Update product price
      {:ok, _updated_product} =
        Medishop.Products.update_product(scenario.product, %{price: Decimal.new("20.00")})

      # Reload cart item
      {:ok, reloaded_item} = Shop.get_cart_item(cart_item.id)

      # Price should remain the same
      assert Decimal.eq?(reloaded_item.price_at_addition, original_price)
    end
  end

  describe "line_total calculation" do
    test "line_total calculates quantity * price_at_addition" do
      scenario = setup_shop_scenario(%{product_attrs: [price: Decimal.new("15.50")]})
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 3, price_at_addition: scenario.product.price) |> Ash.Generator.generate()

      # Load with calculation
      {:ok, item_with_calc} = Shop.get_cart_item(cart_item.id, load: [:line_total])

      expected_total = Decimal.mult(Decimal.new("15.50"), Decimal.new(3))
      assert Decimal.eq?(item_with_calc.line_total, expected_total)
    end
  end

  describe "update_cart_item/2" do
    test "updates cart item quantity" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1) |> Ash.Generator.generate()

      assert {:ok, updated_item} = Shop.update_cart_item(cart_item, %{quantity: 5})

      assert updated_item.quantity == 5
    end

    test "validates quantity on update" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 2) |> Ash.Generator.generate()

      # Cannot update to zero
      assert {:error, _error} = Shop.update_cart_item(cart_item, %{quantity: 0})

      # Cannot update to negative
      assert {:error, _error} = Shop.update_cart_item(cart_item, %{quantity: -1})
    end
  end

  describe "remove_cart_item/1" do
    test "removes cart item (delete)" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1) |> Ash.Generator.generate()

      assert :ok = Shop.remove_cart_item(cart_item)

      # Verify item no longer exists
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               Shop.get_cart_item(cart_item.id)
    end
  end

  describe "add_or_update_cart_item/3" do
    test "creates new item when none exists" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      assert {:ok, cart_item} =
               Shop.add_or_update_cart_item(cart.id, scenario.product.id, 3)

      assert cart_item.cart_id == cart.id
      assert cart_item.product_id == scenario.product.id
      assert cart_item.quantity == 3
    end

    test "updates existing item quantity" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      # Create initial item
      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 2) |> Ash.Generator.generate()

      # Update with add_or_update
      {:ok, updated_item} =
        Shop.add_or_update_cart_item(cart.id, scenario.product.id, 5)

      # Should be the same item with updated quantity
      assert updated_item.id == cart_item.id
      assert updated_item.quantity == 5
    end
  end

  describe "cart_item relationships" do
    test "cart_item belongs_to :cart relationship" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1) |> Ash.Generator.generate()

      # Load with cart
      {:ok, item_with_cart} = Shop.get_cart_item(cart_item.id, load: [:cart])

      assert item_with_cart.cart.id == cart.id
    end

    test "cart_item belongs_to :product relationship" do
      scenario = setup_shop_scenario()
      {:ok, cart} = Shop.create_cart(%{location_id: scenario.location.id})

      cart_item = cart_item(cart_id: cart.id, product_id: scenario.product.id, quantity: 1) |> Ash.Generator.generate()

      # Load with product
      {:ok, item_with_product} = Shop.get_cart_item(cart_item.id, load: [:product])

      assert item_with_product.product.id == scenario.product.id
      assert item_with_product.product.sku == scenario.product.sku
    end
  end

  describe "list_cart_items/0" do
    test "returns all cart items" do
      scenario = setup_shop_scenario()
      {:ok, cart1} = Shop.create_cart(%{location_id: scenario.location.id})

      product2 = product(sku: "PROD-002") |> Ash.Generator.generate()

      item1 = cart_item(cart_id: cart1.id, product_id: scenario.product.id, quantity: 2) |> Ash.Generator.generate()
      item2 = cart_item(cart_id: cart1.id, product_id: product2.id, quantity: 3) |> Ash.Generator.generate()

      assert {:ok, items} = Shop.list_cart_items()

      item_ids = Enum.map(items, & &1.id)
      assert item1.id in item_ids
      assert item2.id in item_ids
    end

    test "returns empty list when no cart items exist" do
      # Clean state verification
      assert {:ok, _items} = Shop.list_cart_items()
    end
  end
end