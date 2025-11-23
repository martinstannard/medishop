defmodule MedishopWeb.OrdersLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  describe "OrdersLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/location/#{location.id}/orders")
      assert path == ~p"/sign-in"
    end
  end

  describe "OrdersLive - unauthorized access" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # User has no membership to this organization
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "redirects user without location access to dashboard with error", %{
      conn: conn,
      location: location
    } do
      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               live(conn, ~p"/location/#{location.id}/orders")
    end
  end

  describe "OrdersLive - authorized user with no orders" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with location access
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, org: org, location: location}
    end

    test "displays no orders message when there are no orders", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "h1", "Orders")
      assert has_element?(view, "p", location.name)
      assert has_element?(view, "p", "No orders yet")
    end

    test "provides back to dashboard link", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "a[href='/dashboard']", "Back to Dashboard")
    end
  end

  describe "OrdersLive - authorized user with orders" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with location access
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create orders for this location
      order1 = order(location_id: location.id, user_id: user.id) |> Ash.Generator.generate()
      order2 = order(location_id: location.id, user_id: user.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, location: location, order1: order1, order2: order2}
    end

    test "displays all orders for the location", %{
      conn: conn,
      location: location,
      order1: order1,
      order2: order2
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "h3", "Order ##{order1.order_number}")
      assert has_element?(view, "h3", "Order ##{order2.order_number}")
    end

    test "displays order status badges", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Should have status badges (order fixtures create pending orders by default)
      assert has_element?(view, "span", "Pending")
    end

    test "displays order totals", %{conn: conn, location: location, order1: order1} do
      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/orders")

      assert html =~ Decimal.to_string(order1.total, :normal)
    end

    test "provides view details link for each order", %{
      conn: conn,
      location: location,
      order1: order1
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "a[href='/orders/#{order1.id}/confirmation']", "View Details")
    end

    test "provides download pdf link for each order", %{
      conn: conn,
      location: location,
      order1: order1
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "a[href='/orders/#{order1.id}/pdf']", "Download PDF")
    end
  end

  describe "OrdersLive - does not show orders from other locations" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location1 = location(organization_id: org.id, name: "Location 1") |> Ash.Generator.generate()
      location2 = location(organization_id: org.id, name: "Location 2") |> Ash.Generator.generate()

      # Create membership with access to location1 only
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location1.id) |> Ash.Generator.generate()

      # Create order for location2 (user shouldn't see this)
      _order_location2 = order(location_id: location2.id, user_id: user.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, location1: location1, location2: location2}
    end

    test "only shows orders for the current location", %{
      conn: conn,
      location1: location1
    } do
      {:ok, _view, html} = live(conn, ~p"/location/#{location1.id}/orders")

      # Should show no orders message since the order is for location2
      assert html =~ "No orders yet"
    end
  end

  describe "OrdersLive - order status transitions" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with location access
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create a pending order
      order = order(location_id: location.id, user_id: user.id) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{conn: conn, user: user, location: location, order: order}
    end

    test "displays confirm order button for pending orders", %{
      conn: conn,
      location: location
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "button", "Confirm Order")
    end

    test "displays cancel order button for pending orders", %{
      conn: conn,
      location: location
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      assert has_element?(view, "button", "Cancel Order")
    end

    test "can confirm a pending order", %{conn: conn, location: location, order: _order} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Click confirm button
      view
      |> element("button", "Confirm Order")
      |> render_click()

      # Should show success message
      assert render(view) =~ "Order confirmed successfully"

      # Status should be updated
      assert has_element?(view, "span", "Confirmed")
    end

    test "can mark confirmed order as shipped", %{conn: conn, location: location, order: order, user: user} do
      # First confirm the order
      {:ok, _confirmed_order} = Medishop.Shop.update_order_status(order, :confirmed, actor: user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Should show "Mark as Shipped" button
      assert has_element?(view, "button", "Mark as Shipped")

      # Click shipped button
      view
      |> element("button", "Mark as Shipped")
      |> render_click()

      # Should show success message
      assert render(view) =~ "Order marked as shipped"

      # Status should be updated
      assert has_element?(view, "span", "Shipped")
    end

    test "can mark shipped order as delivered", %{conn: conn, location: location, order: order, user: user} do
      # First ship the order
      {:ok, confirmed_order} = Medishop.Shop.update_order_status(order, :confirmed, actor: user)
      {:ok, _shipped_order} = Medishop.Shop.update_order_status(confirmed_order, :shipped, actor: user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Should show "Mark as Delivered" button
      assert has_element?(view, "button", "Mark as Delivered")

      # Click delivered button
      view
      |> element("button", "Mark as Delivered")
      |> render_click()

      # Should show success message with inventory note
      assert render(view) =~ "Order delivered! Inventory has been updated."

      # Status should be updated
      assert has_element?(view, "span", "Delivered")
    end

    test "does not show status buttons for delivered orders", %{conn: conn, location: location, order: order, user: user} do
      # Deliver the order
      {:ok, confirmed_order} = Medishop.Shop.update_order_status(order, :confirmed, actor: user)
      {:ok, shipped_order} = Medishop.Shop.update_order_status(confirmed_order, :shipped, actor: user)
      {:ok, _delivered_order} = Medishop.Shop.update_order_status(shipped_order, :delivered, actor: user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Should not show any status transition buttons
      refute has_element?(view, "button", "Confirm Order")
      refute has_element?(view, "button", "Mark as Shipped")
      refute has_element?(view, "button", "Mark as Delivered")
      refute has_element?(view, "button", "Cancel Order")
    end

    test "can cancel a pending order", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Click cancel button
      view
      |> element("button", "Cancel Order")
      |> render_click()

      # Should show success message
      assert render(view) =~ "Order cancelled"

      # Status should be updated
      assert has_element?(view, "span", "Cancelled")
    end

    test "does not show status buttons for cancelled orders", %{conn: conn, location: location, order: order, user: user} do
      # Cancel the order
      {:ok, _cancelled_order} = Medishop.Shop.update_order_status(order, :cancelled, actor: user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/orders")

      # Should not show any status transition buttons
      refute has_element?(view, "button", "Confirm Order")
      refute has_element?(view, "button", "Mark as Shipped")
      refute has_element?(view, "button", "Mark as Delivered")
      refute has_element?(view, "button", "Cancel Order")
    end
  end
end