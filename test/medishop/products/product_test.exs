defmodule Medishop.Products.ProductTest do
  use Medishop.DataCase

  alias Medishop.Products

  import Medishop.Generator

  describe "create_product/1" do
    test "creates a product with all attributes" do
      assert {:ok, product} =
               Products.create_product(%{
                 sku: "TEST-001",
                 title: "Test Medication",
                 description: "A test medication for testing",
                 images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
                 price: Decimal.new("25.99"),
                 active: true
               })

      assert product.sku == "TEST-001"
      assert product.title == "Test Medication"
      assert product.description == "A test medication for testing"

      assert product.images == [
               "https://example.com/image1.jpg",
               "https://example.com/image2.jpg"
             ]

      assert Decimal.eq?(product.price, Decimal.new("25.99"))
      assert product.active == true
    end

    test "creates a product with minimal attributes" do
      assert {:ok, product} =
               Products.create_product(%{
                 sku: "MIN-001",
                 title: "Minimal Product",
                 price: Decimal.new("10.00")
               })

      assert product.sku == "MIN-001"
      assert product.title == "Minimal Product"
      assert product.description == nil
      assert product.images == []
      assert Decimal.eq?(product.price, Decimal.new("10.00"))
      assert product.active == true
    end

    test "enforces SKU uniqueness constraint" do
      {:ok, _product1} =
        Products.create_product(%{
          sku: "UNIQUE-001",
          title: "First Product",
          price: Decimal.new("10.00")
        })

      assert {:error, %Ash.Error.Invalid{}} =
               Products.create_product(%{
                 sku: "UNIQUE-001",
                 title: "Second Product",
                 price: Decimal.new("15.00")
               })
    end

    test "validates price must be positive" do
      assert {:error, %Ash.Error.Invalid{}} =
               Products.create_product(%{
                 sku: "NEG-001",
                 title: "Negative Price Product",
                 price: Decimal.new("-10.00")
               })
    end

    test "validates price cannot be zero" do
      assert {:error, %Ash.Error.Invalid{}} =
               Products.create_product(%{
                 sku: "ZERO-001",
                 title: "Zero Price Product",
                 price: Decimal.new("0.00")
               })
    end

    test "creates active product by default" do
      {:ok, product} =
        Products.create_product(%{
          sku: "ACTIVE-001",
          title: "Active Product",
          price: Decimal.new("10.00")
        })

      assert product.active == true
    end

    test "creates inactive product when specified" do
      {:ok, product} =
        Products.create_product(%{
          sku: "INACTIVE-001",
          title: "Inactive Product",
          price: Decimal.new("10.00"),
          active: false
        })

      assert product.active == false
    end
  end

  describe "update_product/2" do
    test "updates product attributes" do
      product = product() |> Ash.Generator.generate()

      assert {:ok, updated_product} =
               Products.update_product(product, %{
                 title: "Updated Title",
                 description: "Updated description",
                 price: Decimal.new("99.99"),
                 active: false
               })

      assert updated_product.title == "Updated Title"
      assert updated_product.description == "Updated description"
      assert Decimal.eq?(updated_product.price, Decimal.new("99.99"))
      assert updated_product.active == false
      # SKU should not change
      assert updated_product.sku == product.sku
    end
  end

  describe "destroy_product/1" do
    test "deletes a product" do
      product = product() |> Ash.Generator.generate()

      assert :ok = Products.destroy_product(product)

      assert {:ok, products} = Products.list_products()
      refute Enum.any?(products, &(&1.id == product.id))
    end
  end

  describe "list_products/0" do
    test "returns all products" do
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      assert {:ok, products} = Products.list_products()

      product_ids = Enum.map(products, & &1.id)
      assert product1.id in product_ids
      assert product2.id in product_ids
    end
  end

  describe "search_products/1" do
    setup do
      # Create test products for search
      {:ok, aspirin} =
        Products.create_product(%{
          sku: "MED-001",
          title: "Aspirin 100mg",
          price: Decimal.new("5.99"),
          active: true
        })

      {:ok, ibuprofen} =
        Products.create_product(%{
          sku: "MED-002",
          title: "Ibuprofen 200mg",
          price: Decimal.new("8.99"),
          active: true
        })

      {:ok, acetaminophen} =
        Products.create_product(%{
          sku: "MED-003",
          title: "Acetaminophen 500mg",
          price: Decimal.new("6.99"),
          active: false
        })

      %{aspirin: aspirin, ibuprofen: ibuprofen, acetaminophen: acetaminophen}
    end

    test "searches by title (partial match, case insensitive)", %{
      aspirin: aspirin
    } do
      # Search for "irin" which is contained in "Aspirin"
      assert {:ok, results} = Products.search_products(%{title: "irin"})

      result_ids = Enum.map(results, & &1.id)
      assert aspirin.id in result_ids
      assert length(results) >= 1
    end

    test "searches by SKU (exact match)", %{aspirin: aspirin} do
      assert {:ok, results} = Products.search_products(%{sku: "MED-001"})

      assert length(results) == 1
      assert hd(results).id == aspirin.id
    end

    test "searches by active status", %{aspirin: aspirin, ibuprofen: ibuprofen} do
      assert {:ok, active_results} = Products.search_products(%{active: true})

      active_ids = Enum.map(active_results, & &1.id)
      assert aspirin.id in active_ids
      assert ibuprofen.id in active_ids
      assert length(active_results) >= 2
    end

    test "searches by inactive status", %{acetaminophen: acetaminophen} do
      assert {:ok, inactive_results} = Products.search_products(%{active: false})

      inactive_ids = Enum.map(inactive_results, & &1.id)
      assert acetaminophen.id in inactive_ids
    end

    test "sorts by title ascending", %{aspirin: aspirin, ibuprofen: ibuprofen} do
      assert {:ok, results} =
               Products.search_products(%{active: true, sort_by: :title, sort_order: :asc})

      # Filter to just our test products
      test_results = Enum.filter(results, &(&1.id in [aspirin.id, ibuprofen.id]))

      titles = Enum.map(test_results, & &1.title)
      assert titles == Enum.sort(titles)
    end

    test "sorts by price descending", %{aspirin: aspirin, ibuprofen: ibuprofen} do
      assert {:ok, results} =
               Products.search_products(%{active: true, sort_by: :price, sort_order: :desc})

      # Filter to just our test products
      test_results = Enum.filter(results, &(&1.id in [aspirin.id, ibuprofen.id]))

      prices = Enum.map(test_results, & &1.price)
      assert prices == Enum.sort(prices, {:desc, Decimal})
    end

    test "combines multiple search filters" do
      assert {:ok, results} =
               Products.search_products(%{title: "Aspirin", active: true, sku: "MED-001"})

      assert length(results) == 1
      assert hd(results).title == "Aspirin 100mg"
    end
  end

  describe "relationship loading" do
    test "loads location_inventories relationship" do
      product = product() |> Ash.Generator.generate()
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Create inventory for this product at the location
      _inventory = location_inventory(location_id: location.id, product_id: product.id) |> Ash.Generator.generate()

      # Load product with location_inventories
      {:ok, product_with_inventories} = Products.get_product(product.id, load: [:location_inventories])

      assert length(product_with_inventories.location_inventories) == 1
      assert Enum.at(product_with_inventories.location_inventories, 0).product_id == product.id
      assert Enum.at(product_with_inventories.location_inventories, 0).location_id == location.id
    end

    test "loads cart_items relationship" do
      product = product() |> Ash.Generator.generate()
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Create cart and cart item
      cart = cart(location_id: location.id) |> Ash.Generator.generate()
      _cart_item = cart_item(cart_id: cart.id, product_id: product.id, quantity: 5) |> Ash.Generator.generate()

      # Load product with cart_items
      {:ok, product_with_cart_items} = Products.get_product(product.id, load: [:cart_items])

      assert length(product_with_cart_items.cart_items) == 1
      cart_item = Enum.at(product_with_cart_items.cart_items, 0)
      assert cart_item.product_id == product.id
      assert cart_item.quantity == 5
    end

    test "loads order_items relationship" do
      product = product() |> Ash.Generator.generate()
      user = user() |> Ash.Generator.generate()
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Create order with order item
      order = order(location_id: location.id, user_id: user.id) |> Ash.Generator.generate()
      _order_item = order_item(
        order_id: order.id,
        product_id: product.id,
        quantity: 3,
        unit_price: product.price,
        line_total: Decimal.mult(product.price, Decimal.new(3))
      ) |> Ash.Generator.generate()

      # Load product with order_items
      {:ok, product_with_order_items} = Products.get_product(product.id, load: [:order_items])

      assert length(product_with_order_items.order_items) == 1
      order_item = Enum.at(product_with_order_items.order_items, 0)
      assert order_item.product_id == product.id
      assert order_item.quantity == 3
    end

    test "loads multiple relationships at once" do
      product = product() |> Ash.Generator.generate()
      user = user() |> Ash.Generator.generate()
      organization = organization() |> Ash.Generator.generate()
      location = location(organization_id: organization.id) |> Ash.Generator.generate()

      # Create inventory, cart item, and order item
      _inventory = location_inventory(location_id: location.id, product_id: product.id) |> Ash.Generator.generate()

      cart = cart(location_id: location.id) |> Ash.Generator.generate()
      _cart_item = cart_item(cart_id: cart.id, product_id: product.id, quantity: 2) |> Ash.Generator.generate()

      order = order(location_id: location.id, user_id: user.id) |> Ash.Generator.generate()
      _order_item = order_item(
        order_id: order.id,
        product_id: product.id,
        quantity: 1,
        unit_price: product.price,
        line_total: product.price
      ) |> Ash.Generator.generate()

      # Load all relationships
      {:ok, product_fully_loaded} = Products.get_product(product.id, load: [:location_inventories, :cart_items, :order_items])

      assert length(product_fully_loaded.location_inventories) == 1
      assert length(product_fully_loaded.cart_items) == 1
      assert length(product_fully_loaded.order_items) == 1
    end
  end
end