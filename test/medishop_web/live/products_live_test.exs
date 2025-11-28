defmodule MedishopWeb.ProductsLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  describe "ProductsLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/location/#{location.id}/products")
      assert path == ~p"/sign-in"
    end
  end

  describe "ProductsLive - unauthorized access" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # User has no membership to this organization
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "redirects user without buyer access to dashboard with error", %{
      conn: conn,
      location: location
    } do
      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               live(conn, ~p"/location/#{location.id}/products")
    end
  end

  describe "ProductsLive - authorized user with no products" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with org_buyer role
      membership = organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "displays no products message when database is empty", %{conn: conn, location: location} do
      # Delete dependent records first to avoid FK constraints
      for i <- Ash.read!(Medishop.Inventory.LocationInventory), do: Ash.destroy!(i)
      for s <- Ash.read!(Medishop.Products.ProductSupplier), do: Ash.destroy!(s)
      
      # Delete all products to ensure empty state for this test
      for product <- Ash.read!(Medishop.Products.Product) do
        Ash.destroy!(product)
      end

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "h2", "No products found")
      assert has_element?(view, "p", "There are currently no products available.")
    end

    test "shows location name in header", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "span", location.name)
    end

    test "provides links to cart and dashboard", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "a[href='/location/#{location.id}/cart']", "View Cart")
      assert has_element?(view, "a[href='/dashboard']", "Back to Dashboard")
    end
  end

  describe "ProductsLive - authorized user with active products" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with org_buyer role
      membership = organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create active products
      product1 =
        product(
          title: "Aspirin 100mg",
          sku: "ASP-100",
          description: "Pain relief medication",
          price: Decimal.new("10.99"),
          active: true
        ) |> Ash.Generator.generate()

      product2 =
        product(
          title: "Ibuprofen 200mg",
          sku: "IBU-200",
          description: "Anti-inflammatory medication",
          price: Decimal.new("15.50"),
          active: true
        ) |> Ash.Generator.generate()

      # Create inactive product (should not be displayed)
      _inactive_product =
        product(
          title: "Discontinued Product",
          sku: "DIS-001",
          price: Decimal.new("5.00"),
          active: false
        ) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org: org,
        location: location,
        product1: product1,
        product2: product2
      }
    end

    test "displays all active products", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "[data-testid='products-grid']")
      assert has_element?(view, "[data-testid='product-card-#{product1.id}']")
      assert has_element?(view, "[data-testid='product-card-#{product2.id}']")
    end

    test "does not display inactive products", %{conn: conn, location: location} do
      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/products")

      refute html =~ "Discontinued Product"
      refute html =~ "DIS-001"
    end

    test "displays product details correctly", %{
      conn: conn,
      location: location,
      product1: product1
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "h3", product1.title)
      assert has_element?(view, "p", product1.description)
      html = render(view)
      assert html =~ product1.sku
      assert html =~ "10.99"
    end

    test "shows generated thumbnail for products without images", %{
      conn: conn,
      location: location,
      product1: _product1
    } do
      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/products")

      # Should show generated SVG thumbnail
      assert html =~ "data:image/svg+xml"
      assert html =~ "linearGradient"
    end

    test "displays add to cart button for each product", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "[data-testid='add-to-cart-#{product1.id}']")
      assert has_element?(view, "[data-testid='add-to-cart-#{product2.id}']")
    end
  end

  describe "ProductsLive - search functionality" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with org_buyer role
      membership = organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create diverse products for search testing
      aspirin =
        product(
          title: "Aspirin 100mg Tablets",
          sku: "ASP-100",
          price: Decimal.new("10.00")
        ) |> Ash.Generator.generate()

      ibuprofen =
        product(
          title: "Ibuprofen 200mg Capsules",
          sku: "IBU-200",
          price: Decimal.new("15.00")
        ) |> Ash.Generator.generate()

      acetaminophen =
        product(
          title: "Acetaminophen 500mg",
          sku: "ACE-500",
          price: Decimal.new("12.00")
        ) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        location: location,
        aspirin: aspirin,
        ibuprofen: ibuprofen,
        acetaminophen: acetaminophen
      }
    end

    test "displays search input field", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      assert has_element?(view, "[data-testid='search-input']")
    end

    test "filters products by title when searching", %{
      conn: conn,
      location: location,
      aspirin: aspirin
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Search for "Aspirin"
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => "Aspirin"}})

      html = render(view)

      # Should show aspirin product
      assert html =~ aspirin.title

      # Should not show other products
      refute html =~ "Ibuprofen"
      refute html =~ "Acetaminophen"
    end

    test "shows all products when search is cleared", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # First, search for something
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => "Aspirin"}})

      # Then clear search
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => ""}})

      html = render(view)

      # Should show all products again
      assert html =~ "Aspirin"
      assert html =~ "Ibuprofen"
      assert html =~ "Acetaminophen"
    end

    test "shows no results message when search has no matches", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Search for non-existent product
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => "Nonexistent Medicine"}})

      html = render(view)

      assert html =~ "No products found"
      assert html =~ "Try adjusting your search terms"
    end

    test "search filters products by title", %{conn: conn, location: location, aspirin: aspirin} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Search for "Aspirin"
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => "Aspirin"}})

      html = render(view)
      assert html =~ aspirin.title
      # Should not show other products
      refute html =~ "Ibuprofen"
    end
  end

  describe "ProductsLive - add to cart functionality" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with org_buyer role
      membership = organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create product
      product =
        product(
          title: "Test Product",
          sku: "TEST-001",
          price: Decimal.new("20.00")
        ) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, location: location, product: product}
    end

    test "successfully adds product to cart", %{conn: conn, location: location, product: product} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Click add to cart button
      view
      |> element("[data-testid='add-to-cart-#{product.id}']")
      |> render_click()

      # Verify product was added to cart by checking the database
      alias Medishop.Shop
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

      assert length(cart_with_items.cart_items) == 1
      assert hd(cart_with_items.cart_items).product_id == product.id
    end

    test "adding same product twice creates single cart item", %{
      conn: conn,
      location: location,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Add to cart twice
      add_button = element(view, "[data-testid='add-to-cart-#{product.id}']")
      render_click(add_button)
      render_click(add_button)

      # Verify cart has exactly one cart item for this product
      # The add_or_update action sets quantity to 1 each time (doesn't increment)
      alias Medishop.Shop
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

      cart_items_for_product =
        Enum.filter(cart_with_items.cart_items, &(&1.product_id == product.id))

      # Should have exactly one cart item (not two separate ones)
      assert length(cart_items_for_product) == 1
      cart_item = hd(cart_items_for_product)
      # Quantity is 1 because add_or_update sets it, doesn't increment
      assert cart_item.quantity == 1
    end
  end
end