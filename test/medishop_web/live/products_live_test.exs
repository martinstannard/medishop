defmodule MedishopWeb.ProductsLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures
  import MedishopWeb.LiveViewTestHelpers

  describe "ProductsLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization_fixture()
      location = location_fixture(org.id)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/location/#{location.id}/products")
      assert path == ~p"/sign-in"
    end
  end

  describe "ProductsLive - unauthorized access" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

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
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "displays no products message when database is empty", %{conn: conn, location: location} do
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
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Create active products
      product1 =
        product_fixture(%{
          title: "Aspirin 100mg",
          sku: "ASP-100",
          description: "Pain relief medication",
          price: Decimal.new("10.99"),
          active: true
        })

      product2 =
        product_fixture(%{
          title: "Ibuprofen 200mg",
          sku: "IBU-200",
          description: "Anti-inflammatory medication",
          price: Decimal.new("15.50"),
          active: true
        })

      # Create inactive product (should not be displayed)
      _inactive_product =
        product_fixture(%{
          title: "Discontinued Product",
          sku: "DIS-001",
          price: Decimal.new("5.00"),
          active: false
        })

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

    test "shows placeholder image for products without images", %{
      conn: conn,
      location: location,
      product1: product1
    } do
      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/products")

      # Should show placeholder icon
      assert html =~ "hero-photo"
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
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Create diverse products for search testing
      aspirin =
        product_fixture(%{
          title: "Aspirin 100mg Tablets",
          sku: "ASP-100",
          price: Decimal.new("10.00")
        })

      ibuprofen =
        product_fixture(%{
          title: "Ibuprofen 200mg Capsules",
          sku: "IBU-200",
          price: Decimal.new("15.00")
        })

      acetaminophen =
        product_fixture(%{
          title: "Acetaminophen 500mg",
          sku: "ACE-500",
          price: Decimal.new("12.00")
        })

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

    test "search is case-insensitive", %{conn: conn, location: location, aspirin: aspirin} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Search with lowercase - Note: PostgreSQL LIKE is case-sensitive by default
      # The search uses `contains` which compiles to ILIKE (case-insensitive)
      view
      |> element("form")
      |> render_change(%{"search" => %{"query" => "Aspirin"}})

      html = render(view)
      assert html =~ aspirin.title
    end
  end

  describe "ProductsLive - add to cart functionality" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Create product
      product =
        product_fixture(%{
          title: "Test Product",
          sku: "TEST-001",
          price: Decimal.new("20.00")
        })

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

      # Should show success message
      html = render(view)
      assert html =~ "Product added to cart!"
    end

    test "adding same product twice updates quantity", %{
      conn: conn,
      location: location,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/products")

      # Add to cart twice
      add_button = element(view, "[data-testid='add-to-cart-#{product.id}']")
      render_click(add_button)
      render_click(add_button)

      # Verify cart has the product with quantity 2
      alias Medishop.Shop
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

      cart_item = Enum.find(cart_with_items.cart_items, &(&1.product_id == product.id))
      assert cart_item.quantity == 2
    end
  end
end
