defmodule MedishopWeb.OrdersLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.OrganizationsFixtures
  import Medishop.ShopFixtures
  import MedishopWeb.LiveViewTestHelpers

  describe "OrdersLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization_fixture()
      location = location_fixture(org.id)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/location/#{location.id}/orders")
      assert path == ~p"/sign-in"
    end
  end

  describe "OrdersLive - unauthorized access" do
    setup %{conn: conn} do
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

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
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with location access
      membership = organization_membership_fixture(user.id, org.id)
      organization_location_membership_fixture(membership.id, location.id)

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
      user = user_fixture()
      org = organization_fixture()
      location = location_fixture(org.id)

      # Create membership with location access
      membership = organization_membership_fixture(user.id, org.id)
      organization_location_membership_fixture(membership.id, location.id)

      # Create orders for this location
      order1 = order_fixture(location.id, user.id)
      order2 = order_fixture(location.id, user.id)

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
      user = user_fixture()
      org = organization_fixture()
      location1 = location_fixture(org.id, %{name: "Location 1"})
      location2 = location_fixture(org.id, %{name: "Location 2"})

      # Create membership with access to location1 only
      membership = organization_membership_fixture(user.id, org.id)
      organization_location_membership_fixture(membership.id, location1.id)

      # Create order for location2 (user shouldn't see this)
      _order_location2 = order_fixture(location2.id, user.id)

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
end
