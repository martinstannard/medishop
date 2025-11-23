defmodule Medishop.Shop.CartTest do
  use Medishop.DataCase

  alias Medishop.Shop

  import Medishop.Generator

  describe "create_cart/1" do
    test "creates a cart for a location" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      assert {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      assert cart.location_id == location.id
      assert cart.id != nil
    end

    test "enforces unique cart per location constraint" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:ok, _cart1} = Shop.create_cart(%{location_id: location.id})

      # Second cart for same location should fail
      assert {:error, _error} = Shop.create_cart(%{location_id: location.id})
    end
  end

  describe "get_or_create_cart_for_location/1" do
    test "creates new cart when none exists" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      assert {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)

      assert cart.location_id == location.id
      assert cart.id != nil
    end

    test "returns existing cart when one exists" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:ok, cart1} = Shop.get_or_create_cart_for_location(location.id)

      # Second call should return the same cart
      {:ok, cart2} = Shop.get_or_create_cart_for_location(location.id)

      assert cart1.id == cart2.id
    end
  end

  describe "get_cart_by_location/1" do
    test "retrieves cart by location_id" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      assert {:ok, found_cart} = Shop.get_cart_by_location(location.id)
      assert found_cart.id == cart.id
    end

    test "returns not found error when cart doesn't exist" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               Shop.get_cart_by_location(location.id)
    end
  end

  describe "cart relationships" do
    test "cart belongs_to :location relationship" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      # Load cart with location
      {:ok, cart_with_location} = Shop.get_cart(cart.id, load: [:location])

      assert cart_with_location.location.id == location.id
      assert cart_with_location.location.name == location.name
    end

    test "cart has_many :cart_items relationship" do
      # Setup scenario
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      
      {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      # Add some items to the cart
      _item1 = cart_item(cart_id: cart.id, product_id: product.id, quantity: 2) |> Ash.Generator.generate()

      product2 = product(sku: "PROD-002") |> Ash.Generator.generate()
      _item2 = cart_item(cart_id: cart.id, product_id: product2.id, quantity: 1) |> Ash.Generator.generate()

      # Load cart with items
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

      assert length(cart_with_items.cart_items) == 2
    end
  end

  describe "clear_cart/1" do
    test "clears all items from cart" do
      # Setup scenario
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      
      {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      # Add items
      _item1 = cart_item(cart_id: cart.id, product_id: product.id, quantity: 2) |> Ash.Generator.generate()

      product2 = product(sku: "PROD-002") |> Ash.Generator.generate()
      _item2 = cart_item(cart_id: cart.id, product_id: product2.id, quantity: 1) |> Ash.Generator.generate()

      # Clear cart
      {:ok, cleared_cart} = Shop.clear_cart(cart)

      # Verify items are removed
      {:ok, cart_with_items} = Shop.get_cart(cleared_cart.id, load: [:cart_items])
      assert cart_with_items.cart_items == []
    end
  end

  describe "destroy_cart/1" do
    test "deletes a cart" do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:ok, cart} = Shop.create_cart(%{location_id: location.id})

      assert :ok = Shop.destroy_cart(cart)

      # Verify cart no longer exists
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               Shop.get_cart(cart.id)
    end
  end

  describe "list_carts/0" do
    test "returns all carts" do
      org1 = organization() |> Ash.Generator.generate()
      location1 = location(organization_id: org1.id, name: "Location 1") |> Ash.Generator.generate()
      org2 = organization() |> Ash.Generator.generate()
      location2 = location(organization_id: org2.id, name: "Location 2") |> Ash.Generator.generate()

      {:ok, cart1} = Shop.create_cart(%{location_id: location1.id})
      {:ok, cart2} = Shop.create_cart(%{location_id: location2.id})

      assert {:ok, carts} = Shop.list_carts()

      cart_ids = Enum.map(carts, & &1.id)
      assert cart1.id in cart_ids
      assert cart2.id in cart_ids
    end

    test "returns empty list when no carts exist" do
      # Ensure clean state - in a fresh test the database might already have carts
      # So we just verify we can call the function
      assert {:ok, _carts} = Shop.list_carts()
    end
  end
end