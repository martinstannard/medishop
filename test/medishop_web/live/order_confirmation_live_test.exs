defmodule MedishopWeb.OrderConfirmationLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Shop

  describe "OrderConfirmationLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      # Create a fake order ID
      order_id = Ash.UUID.generate()

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/orders/#{order_id}/confirmation")
      assert path == ~p"/sign-in"
    end
  end

  describe "OrderConfirmationLive - order not found" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      %{conn: conn, user: user}
    end

    test "redirects to dashboard with error when order doesn't exist", %{conn: conn} do
      # Use a non-existent order ID
      order_id = Ash.UUID.generate()

      {:ok, _view, html} = live(conn, ~p"/orders/#{order_id}/confirmation")

      assert html =~ "Order not found"
    end
  end

  describe "OrderConfirmationLive - unauthorized access" do
    setup %{conn: conn} do
      # Create two users
      user1 = user_fixture()
      user2 = user_fixture()

      # Create organization and location
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create product and order for user1
      product = product_fixture(%{title: "Test Product", price: Decimal.new("50.00")})
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item} = Shop.add_or_update_cart_item(cart.id, product.id, 2)
      {:ok, order} = Shop.create_order_from_cart(cart.id, user1.id)

      # Log in as user2 (different user)
      conn = log_in_user(conn, user2)

      %{conn: conn, user1: user1, user2: user2, order: order}
    end

    test "redirects to dashboard when user tries to access another user's order", %{
      conn: conn,
      order: order
    } do
      {:ok, _view, html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert html =~ "You don&#39;t have permission to view this order"
    end
  end

  describe "OrderConfirmationLive - successful order display" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id, %{name: "Main Pharmacy"})

      # Create products
      product1 =
        product_fixture(%{
          title: "Aspirin 100mg",
          sku: "ASP-100",
          price: Decimal.new("10.00")
        })

      product2 =
        product_fixture(%{
          title: "Ibuprofen 200mg",
          sku: "IBU-200",
          price: Decimal.new("25.00")
        })

      # Create cart and add items
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 3)
      {:ok, _item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 2)

      # Create order
      {:ok, order} = Shop.create_order_from_cart(cart.id, user.id)

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        order: order,
        location: location,
        product1: product1,
        product2: product2
      }
    end

    test "displays order confirmation message", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert has_element?(view, "h1", "Order Confirmed!")
      assert has_element?(view, "span", order.order_number)
    end

    test "displays order number prominently", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      html = render(view)
      assert html =~ order.order_number
    end

    test "displays delivery location details", %{conn: conn, order: order, location: location} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert has_element?(view, "div", location.name)
      html = render(view)
      assert html =~ location.address["street"]
      assert html =~ location.address["city"]
      assert html =~ location.address["state"]
      assert html =~ location.address["zip"]
    end

    test "displays order status badge", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      # Default status is "pending"
      html = render(view)
      assert html =~ "badge"
      assert html =~ "Pending"
    end

    test "displays order date", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      # Should show formatted date
      assert html =~ "Order Date"
    end

    test "displays order total", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      # Total: (3 × $10) + (2 × $25) = $30 + $50 = $80
      html = render(view)
      assert html =~ "80.00"
    end

    test "displays all order items with details", %{
      conn: conn,
      order: order,
      product1: product1,
      product2: product2
    } do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      # Check for items table
      assert has_element?(view, "[data-testid='order-items-table']")

      # Check product details
      assert has_element?(view, "div", product1.title)
      assert has_element?(view, "div", product1.sku)
      assert has_element?(view, "div", product2.title)
      assert has_element?(view, "div", product2.sku)

      html = render(view)
      # Check quantities
      assert html =~ "3"
      assert html =~ "2"
    end

    test "displays correct line totals for each item", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      # Product1: 3 × $10 = $30
      assert html =~ "30.00"
      # Product2: 2 × $25 = $50
      assert html =~ "50.00"
    end

    test "displays subtotal and total in footer", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      html = render(view)
      assert html =~ "Subtotal:"
      assert html =~ "Total:"
      assert html =~ "80.00"
    end

    test "provides link to continue shopping", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert has_element?(
               view,
               "a[href='/location/#{order.location_id}/products']",
               "Continue Shopping"
             )
    end

    test "provides link back to dashboard", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert has_element?(view, "a[href='/dashboard']", "Back to Dashboard")
    end
  end

  describe "OrderConfirmationLive - order with notes" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      product = product_fixture(%{price: Decimal.new("15.00")})
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item} = Shop.add_or_update_cart_item(cart.id, product.id, 1)

      # Create order with notes
      {:ok, order} = Shop.create_order_from_cart(cart.id, user.id, "Please deliver before 5 PM")

      conn = log_in_user(conn, user)

      %{conn: conn, order: order}
    end

    test "displays order notes when present", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert html =~ "Notes"
      assert html =~ order.notes
    end
  end

  describe "OrderConfirmationLive - different order statuses" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      product = product_fixture(%{price: Decimal.new("10.00")})
      {:ok, cart} = Shop.get_or_create_cart_for_location(location.id)
      {:ok, _item} = Shop.add_or_update_cart_item(cart.id, product.id, 1)
      {:ok, order} = Shop.create_order_from_cart(cart.id, user.id)

      conn = log_in_user(conn, user)

      %{conn: conn, order: order, user: user}
    end

    test "shows correct badge color for pending status", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/orders/#{order.id}/confirmation")

      assert html =~ "badge-warning"
    end

    test "shows correct badge color for confirmed status", %{conn: conn, order: order} do
      # Update order status to confirmed
      {:ok, updated_order} = Shop.update_order_status(order, "confirmed")

      {:ok, _view, html} = live(conn, ~p"/orders/#{updated_order.id}/confirmation")

      assert html =~ "badge-info"
      assert html =~ "Confirmed"
    end

    test "shows correct badge color for delivered status", %{conn: conn, order: order} do
      # Update order status through valid transitions: pending → confirmed → shipped → delivered
      {:ok, confirmed_order} = Shop.update_order_status(order, "confirmed")
      {:ok, shipped_order} = Shop.update_order_status(confirmed_order, "shipped")
      {:ok, delivered_order} = Shop.update_order_status(shipped_order, "delivered")

      {:ok, _view, html} = live(conn, ~p"/orders/#{delivered_order.id}/confirmation")

      assert html =~ "badge-success"
      assert html =~ "Delivered"
    end
  end
end
