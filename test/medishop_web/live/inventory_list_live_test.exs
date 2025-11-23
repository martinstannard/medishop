defmodule MedishopWeb.InventoryListLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Inventory

  describe "InventoryListLive - unauthenticated access" do
    test "redirects unauthenticated user to sign-in page", %{conn: conn} do
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      result = live(conn, ~p"/location/#{location.id}/inventory")

      case result do
        {:error, {:redirect, %{to: path}}} ->
          assert path == ~p"/sign-in"

        {:error, {:live_redirect, %{to: path}}} ->
          assert path == ~p"/sign-in"
      end
    end
  end

  describe "InventoryListLive - authorized user with no inventory" do
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

    test "displays inventory page with location name", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(view, "h1", "Inventory")
      assert has_element?(view, "p", location.name)
    end

    test "displays no inventory items message", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(view, "p", "No inventory items")
    end

    test "provides back to dashboard link", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(view, "a[href='/dashboard']", "Back to Dashboard")
    end

    test "provides search input", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(view, "input#search")
    end
  end

  describe "InventoryListLive - authorized user with inventory" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with location access
      membership = organization_membership(user_id: user.id, organization_id: org.id) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create products
      product1 = product(title: "Aspirin 100mg", sku: "ASP-100") |> Ash.Generator.generate()
      product2 = product(title: "Ibuprofen 200mg", sku: "IBU-200") |> Ash.Generator.generate()
      product3 = product(title: "Acetaminophen 500mg", sku: "ACE-500") |> Ash.Generator.generate()

      # Create inventory
      inv1 = location_inventory(location_id: location.id, product_id: product1.id) |> Ash.Generator.generate()
      inv2 = location_inventory(location_id: location.id, product_id: product2.id) |> Ash.Generator.generate()
      inv3 = location_inventory(location_id: location.id, product_id: product3.id) |> Ash.Generator.generate()

      # Create some inventory events to set quantities
      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product2.id,
          event_type: :purchase_received,
          quantity_change: 5,
          occurred_at: DateTime.utc_now()
        })

      # product3 stays at 0 (out of stock)

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org: org,
        location: location,
        product1: product1,
        product2: product2,
        product3: product3,
        inv1: inv1,
        inv2: inv2,
        inv3: inv3
      }
    end

    test "displays all inventory items for location", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(view, "td", product1.title)
      assert has_element?(view, "td", product1.sku)
      assert has_element?(view, "td", product2.title)
      assert has_element?(view, "td", product2.sku)
      assert has_element?(view, "td", product3.title)
      assert has_element?(view, "td", product3.sku)
    end

    test "displays current quantities", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Should show quantities
      assert view |> element("td", "100") |> has_element?()
      assert view |> element("td", "5") |> has_element?()
      assert view |> element("td", "0") |> has_element?()
    end

    test "displays stock status badges", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # In Stock (quantity 100)
      assert has_element?(view, "span", "In Stock")
      # Low Stock (quantity 5)
      assert has_element?(view, "span", "Low Stock")
      # Out of Stock (quantity 0)
      assert has_element?(view, "span", "Out of Stock")
    end

    test "provides view details links for each product", %{
      conn: conn,
      location: location,
      product1: product1
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      assert has_element?(
               view,
               "a[href='/location/#{location.id}/inventory/#{product1.id}']",
               "View Details"
            )
    end

    test "search filters products by title", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Search for "Aspirin"
      view
      |> form("form", %{search: "Aspirin"})
      |> render_change()

      assert has_element?(view, "td", "Aspirin 100mg")
      refute has_element?(view, "td", "Ibuprofen 200mg")
      refute has_element?(view, "td", "Acetaminophen 500mg")
    end

    test "search filters products by SKU", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Search for "IBU"
      view
      |> form("form", %{search: "IBU"})
      |> render_change()

      refute has_element?(view, "td", "Aspirin 100mg")
      assert has_element?(view, "td", "Ibuprofen 200mg")
      refute has_element?(view, "td", "Acetaminophen 500mg")
    end

    test "search is case insensitive", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Search for lowercase "aspirin"
      view
      |> form("form", %{search: "aspirin"})
      |> render_change()

      assert has_element?(view, "td", "Aspirin 100mg")
    end

    test "displays no results message when search has no matches", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      view
      |> form("form", %{search: "Nonexistent Product"})
      |> render_change()

      assert has_element?(view, "p", "No products found")
      assert has_element?(view, "p", "Try adjusting your search query")
    end

    test "can sort by product title ascending", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Default sort is already product_title:asc, so check initial render
      html = render(view)

      # Check that products appear in alphabetical order
      # Acetaminophen (product3) < Aspirin (product1) < Ibuprofen (product2)
      acetaminophen_pos = :binary.match(html, product3.title) |> elem(0)
      aspirin_pos = :binary.match(html, product1.title) |> elem(0)
      ibuprofen_pos = :binary.match(html, product2.title) |> elem(0)

      assert acetaminophen_pos < aspirin_pos
      assert aspirin_pos < ibuprofen_pos
    end

    test "can sort by product title descending", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Click sort by product title once (toggles from asc to desc)
      view
      |> element("th", "Product")
      |> render_click()

      html = render(view)

      # Check that products appear in reverse alphabetical order
      # Ibuprofen (product2) > Aspirin (product1) > Acetaminophen (product3)
      ibuprofen_pos = :binary.match(html, product2.title) |> elem(0)
      aspirin_pos = :binary.match(html, product1.title) |> elem(0)
      acetaminophen_pos = :binary.match(html, product3.title) |> elem(0)

      assert ibuprofen_pos < aspirin_pos
      assert aspirin_pos < acetaminophen_pos
    end

    test "can sort by quantity ascending", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Click sort by quantity
      view
      |> element("th", "Current Quantity")
      |> render_click()

      html = render(view)

      # Find positions of quantities in HTML
      qty_0_pos = :binary.match(html, "Out of Stock") |> elem(0)
      qty_5_pos = :binary.match(html, "Low Stock") |> elem(0)
      qty_100_pos = :binary.match(html, "In Stock") |> elem(0)

      # Quantities should appear in ascending order: 0, 5, 100
      assert qty_0_pos < qty_5_pos
      assert qty_5_pos < qty_100_pos
    end

    test "displays sort indicator on active column", %{conn: conn, location: location} do
      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/inventory")

      # Default sort is product_title:asc, so should show ascending arrow
      html = render(view)
      assert html =~ "↑"

      # Click to toggle to descending
      view
      |> element("th", "Product")
      |> render_click()

      html = render(view)
      assert html =~ "↓"
    end
  end
end