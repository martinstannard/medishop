defmodule Medishop.ShopFixtures do
  @moduledoc """
  This module defines test fixtures for the Shop domain.
  """

  alias Medishop.Shop
  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures

  @doc """
  Generate a cart for a location.
  """
  def cart_fixture(location_id, attrs \\ %{}) do
    {:ok, cart} =
      Shop.create_cart(
        Map.merge(
          %{
            location_id: location_id
          },
          attrs
        )
      )

    cart
  end

  @doc """
  Generate a cart item.
  """
  def cart_item_fixture(cart_id, product_id, attrs \\ %{}) do
    quantity = Map.get(attrs, :quantity, 1)

    # Get product to capture price
    {:ok, product} = Medishop.Products.get_product(product_id)
    price_at_addition = Map.get(attrs, :price_at_addition, product.price)

    {:ok, cart_item} =
      Shop.create_cart_item(
        Map.merge(
          %{
            cart_id: cart_id,
            product_id: product_id,
            quantity: quantity,
            price_at_addition: price_at_addition
          },
          attrs
        )
      )

    cart_item
  end

  @doc """
  Generate an order directly (without cart).
  """
  def order_fixture(location_id, user_id, attrs \\ %{}) do
    status = Map.get(attrs, :status, :pending)
    subtotal = Map.get(attrs, :subtotal, Decimal.new("100.00"))
    total = Map.get(attrs, :total, subtotal)

    {:ok, order} =
      Shop.create_order(
        Map.merge(
          %{
            location_id: location_id,
            user_id: user_id,
            status: status,
            subtotal: subtotal,
            total: total
          },
          attrs
        )
      )

    order
  end

  @doc """
  Generate an order from a cart.
  """
  def order_from_cart_fixture(cart_id, user_id, attrs \\ %{}) do
    notes = Map.get(attrs, :notes)

    {:ok, order} =
      Shop.create_order_from_cart(
        cart_id,
        user_id,
        notes
      )

    order
  end

  @doc """
  Generate an order item.
  """
  def order_item_fixture(order_id, product_id, attrs \\ %{}) do
    quantity = Map.get(attrs, :quantity, 1)

    # Get product to capture price
    {:ok, product} = Medishop.Products.get_product(product_id)
    unit_price = Map.get(attrs, :unit_price, product.price)
    line_total = Map.get(attrs, :line_total, Decimal.mult(unit_price, Decimal.new(quantity)))

    {:ok, order_item} =
      Shop.create_order_item(
        Map.merge(
          %{
            order_id: order_id,
            product_id: product_id,
            quantity: quantity,
            unit_price: unit_price,
            line_total: line_total
          },
          attrs
        )
      )

    order_item
  end

  @doc """
  Helper to create a complete test scenario:
  - Creates organization, location, user, and product
  - Returns a map with all created resources
  """
  def setup_shop_scenario(attrs \\ %{}) do
    org = organization_fixture()
    location = location_fixture(org.id)
    user = user_fixture()
    product = product_fixture(Map.get(attrs, :product_attrs, %{}))

    %{
      organization: org,
      location: location,
      user: user,
      product: product
    }
  end
end
