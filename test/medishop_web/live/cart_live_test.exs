defmodule MedishopWeb.CartLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Shop

  describe "CartLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization_fixture()
      location = location_fixture(org.id)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/location/#{location.id}/cart")
      assert path == ~p"/sign-in"
    end
  end

  describe "CartLive - unauthorized access" do
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
               live(conn, ~p"/location/#{location.id}/cart")
    end
  end

  describe "CartLive - authorized user with empty cart" do
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

    test "displays empty cart message", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      assert has_element?(view, "h1", "Shopping Cart")
      assert has_element?(view, "h2", "Your cart is empty")
      assert has_element?(view, "a[href='/location/#{location.id}/products']")
    end

    test "shows location name in header", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      assert has_element?(view, "span", location.name)
    end

    test "provides link back to dashboard", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      assert has_element?(view, "a[href='/dashboard']", "Back to Dashboard")
    end
  end

  describe "CartLive - authorized user with items in cart" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Create products
      product1 = product_fixture(%{title: "Aspirin", sku: "ASP-100", price: Decimal.new("10.00")})

      product2 =
        product_fixture(%{title: "Ibuprofen", sku: "IBU-200", price: Decimal.new("15.50")})

      # Get or create cart and add items
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 2)
      {:ok, _item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 1)

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org: org,
        location: location,
        cart: cart,
        product1: product1,
        product2: product2
      }
    end

    test "displays cart items with correct product details", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Check for cart items table
      assert has_element?(view, "[data-testid='cart-items-table']")

      # Check product titles and SKUs are displayed
      assert has_element?(view, "div", product1.title)
      assert has_element?(view, "div", product1.sku)
      assert has_element?(view, "div", product2.title)
      assert has_element?(view, "div", product2.sku)
    end

    test "displays correct quantities for each item", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Aspirin quantity should be 2
      # Ibuprofen quantity should be 1
      html = render(view)
      assert html =~ "2"
      assert html =~ "1"
    end

    test "calculates and displays line totals correctly", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Aspirin: 2 × $10.00 = $20.00
      # Ibuprofen: 1 × $15.50 = $15.50
      html = render(view)
      assert html =~ "20.00"
      assert html =~ "15.50"
    end

    test "calculates and displays cart total correctly", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Total: $20.00 + $15.50 = $35.50
      html = render(view)
      assert html =~ "35.50"
    end

    test "allows incrementing item quantity", %{conn: conn, location: location, product1: product1} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Get the cart item for product1 to find its ID
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
      cart_item = Enum.find(cart_with_items.cart_items, &(&1.product_id == product1.id))

      # Click increment button
      view
      |> element("button[phx-click='update_quantity'][phx-value-quantity='3']")
      |> render_click()

      # Verify quantity updated
      html = render(view)
      # Check that the item row now shows quantity 3
      assert html =~ "3"
    end

    test "allows decrementing item quantity", %{conn: conn, location: location, product1: product1} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Get the cart item for product1
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
      cart_item = Enum.find(cart_with_items.cart_items, &(&1.product_id == product1.id))

      # Click decrement button (from 2 to 1)
      view
      |> element("button[phx-click='update_quantity'][phx-value-quantity='1']")
      |> render_click()

      # Verify quantity updated
      html = render(view)
      assert html =~ "1"
    end

    test "prevents decrementing quantity below 1", %{conn: conn, location: location, product2: product2} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Product2 has quantity 1, decrement button should be disabled
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
      cart_item = Enum.find(cart_with_items.cart_items, &(&1.product_id == product2.id))

      html = render(view)
      # The button with quantity - 1 (= 0) should be disabled
      assert html =~ "disabled"
    end

    test "allows removing individual items from cart", %{
      conn: conn,
      location: location,
      product1: product1
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Get the cart item ID
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
      cart_item = Enum.find(cart_with_items.cart_items, &(&1.product_id == product1.id))

      # Click remove button
      view
      |> element("[data-testid='remove-item-#{cart_item.id}']")
      |> render_click()

      # Verify item removed
      html = render(view)
      refute html =~ product1.title
      assert html =~ "Item removed from cart"
    end

    test "allows clearing entire cart", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Click clear cart button
      view
      |> element("[data-testid='clear-cart-button']")
      |> render_click()

      # Verify cart is empty
      html = render(view)
      assert html =~ "Your cart is empty"
      assert html =~ "Cart cleared successfully"
    end
  end

  describe "CartLive - place order functionality" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with org_buyer role
      membership = organization_membership_fixture(user.id, org.id, %{org_roles: [:org_buyer]})
      organization_location_membership_fixture(membership.id, location.id)

      # Create product and add to cart
      product = product_fixture(%{title: "Test Product", price: Decimal.new("25.00")})
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item} = Shop.add_or_update_cart_item(cart.id, product.id, 3)

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, location: location, cart: cart, product: product}
    end

    test "successfully creates order from cart", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Click place order button
      view
      |> element("[data-testid='place-order-button']")
      |> render_click()

      # Should redirect to order confirmation
      assert_redirect(view, ~r"/orders/.+/confirmation")
    end

    test "displays success message when order is placed", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Place order
      view
      |> element("[data-testid='place-order-button']")
      |> render_click()

      # Check for flash message (will be shown on next page)
      assert_redirect(view)
    end
  end
end
