defmodule MedishopWeb.StockTakeLiveTest do
  use MedishopWeb.ConnCase
  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Inventory

  setup do
    # Create organization, location, and user
    org = organization() |> Ash.Generator.generate()
    location = location(organization_id: org.id) |> Ash.Generator.generate()
    user = user() |> Ash.Generator.generate()
    
    # Add user to organization
    organization_membership(organization_id: org.id, user_id: user.id, org_roles: [:org_admin]) 
    |> Ash.Generator.generate()

    # Create some products and inventory
    product1 = product(title: "Paracetamol", sku: "PARA001", unit_of_measure: :tablets, storage_location: :cupboard) |> Ash.Generator.generate()
    product2 = product(title: "Ibuprofen", sku: "IBU001", unit_of_measure: :tablets, storage_location: :fridge) |> Ash.Generator.generate()

    # Create initial inventory (10 of each)
    inventory_event(location_id: location.id, product_id: product1.id, quantity_change: 10, event_type: :purchase_received) |> Ash.Generator.generate()
    inventory_event(location_id: location.id, product_id: product2.id, quantity_change: 10, event_type: :purchase_received) |> Ash.Generator.generate()

    %{org: org, location: location, user: user, product1: product1, product2: product2}
  end

  describe "Stock Take LiveView" do
    test "renders stock take page and products", %{conn: conn, location: location, user: user, product1: product1} do
      conn = conn |> log_in_user(user)

      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/stock-take")

      assert html =~ "Stock Take"
      assert html =~ location.name
      assert html =~ product1.title
      assert html =~ product1.sku
      assert html =~ "Cupboard" # Storage location
    end

    test "can filter products by storage location", %{conn: conn, location: location, user: user, product1: product1, product2: product2} do
      conn = conn |> log_in_user(user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/stock-take")

      # Initial view should show both (filter is all)
      assert has_element?(view, "tr", product1.title)
      assert has_element?(view, "tr", product2.title)

      # Filter by Fridge
      view
      |> element("select[name='storage']")
      |> render_change(%{"storage" => "fridge"})

      refute has_element?(view, "tr", product1.title) # Cupboard item hidden
      assert has_element?(view, "tr", product2.title) # Fridge item shown
    end

    test "can enter physical counts and save", %{conn: conn, location: location, user: user, product1: product1, product2: product2} do
      conn = conn |> log_in_user(user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/stock-take")

      # Enter counts (8 for product1 -> discrepancy of -2, 10 for product2 -> no discrepancy)
      
      # We need to find the inventory IDs to target the inputs
      {:ok, items} = Inventory.get_inventory_by_location(%{location_id: location.id})
      item1 = Enum.find(items, fn i -> i.product_id == product1.id end)
      item2 = Enum.find(items, fn i -> i.product_id == product2.id end)

      view
      |> element("input[name='physical_count'][phx-value-inventory_id='#{item1.id}']")
      |> render_change(%{physical_count: "8", inventory_id: item1.id})

      view
      |> element("input[name='physical_count'][phx-value-inventory_id='#{item2.id}']")
      |> render_change(%{physical_count: "10", inventory_id: item2.id})

      # Save and Review
      {:ok, conn} = 
        view
        |> element("button", "Save & Review")
        |> render_click()
        |> follow_redirect(conn)

      {:ok, review_view, _html} = live(conn)

      assert has_element?(review_view, "h1", "Review Stock Take")
      
      # Check for discrepancy
      assert has_element?(review_view, "td", "-2") # Discrepancy for product1
      assert has_element?(review_view, "td", "Verified") # product2 matched
    end
  end

  describe "Reconciliation Review LiveView" do
    setup %{location: location, product1: product1} do
      # Create an existing reconciliation with items
      reconciliation = stock_reconciliation(location_id: location.id, status: :in_progress) |> Ash.Generator.generate()
      
      # Item with discrepancy
      {:ok, inventory_item} = Inventory.get_location_inventory_by_location_and_product(location.id, product1.id)
      
      reconciliation_item(
        reconciliation_id: reconciliation.id, 
        product_id: product1.id, 
        location_inventory_id: inventory_item.id,
        system_quantity: 10,
        physical_quantity: 8,
        adjustment_reason: nil # No reason yet
      ) |> Ash.Generator.generate()

      %{reconciliation: reconciliation, inventory_item: inventory_item}
    end

    test "shows discrepancies and requires reason", %{conn: conn, location: location, user: user, reconciliation: reconciliation} do
      conn = conn |> log_in_user(user)

      {:ok, view, html} = live(conn, ~p"/location/#{location.id}/reconciliation/#{reconciliation.id}/review")

      assert html =~ "Review Stock Take"
      assert html =~ "Items with Discrepancies (1)"
      assert html =~ "Reason required"

      # Try to complete without reason
      view
      |> element("button", "Complete Stock Take")
      |> render_click()

      assert render(view) =~ "Please provide adjustment reasons"
    end

    test "can add reason and complete reconciliation", %{conn: conn, location: location, user: user, reconciliation: reconciliation, product1: product1} do
      conn = conn |> log_in_user(user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/reconciliation/#{reconciliation.id}/review")

      # Click "Add Reason" (or Edit if exists, but here it's nil so "Add Reason")
      # Finding the button by item ID is tricky without ID on row, but we have only one item.
      # The template uses `phx-click="edit_reason" phx-value-item_id={item.id}`
      
      # We need the item ID
      {:ok, [item]} = Inventory.get_items_by_reconciliation(%{reconciliation_id: reconciliation.id})
      
      view
      |> element("button[phx-click='edit_reason'][phx-value-item_id='#{item.id}']")
      |> render_click()

      # Form appears
      assert has_element?(view, "form[phx-submit='update_reason']")

      # Select reason and submit
      view
      |> form("form[phx-submit='update_reason']", %{
        "adjustment_reason" => "theft",
        "adjustment_notes" => "Missing from shelf"
      })
      |> render_submit()

      assert has_element?(view, "div", "Theft") # Reason shown
      refute has_element?(view, "span", "Reason required")

      # Complete Stock Take
      {:ok, conn} =
        view
        |> element("button", "Complete Stock Take")
        |> render_click()
        |> follow_redirect(conn, ~p"/location/#{location.id}/inventory")

      assert html_response(conn, 200) =~ "Stock take completed successfully"

      # Verify reconciliation is completed
      {:ok, updated_rec} = Inventory.get_reconciliation(reconciliation.id)
      assert updated_rec.status == :completed
      
      # Verify adjustment event created
      {:ok, events} = Inventory.get_events_by_location_and_product(%{location_id: location.id, product_id: product1.id})
      adjustment_event = Enum.find(events, fn e -> e.event_type == :adjustment end)
      
      assert adjustment_event
      assert adjustment_event.quantity_change == -2
      assert adjustment_event.reason =~ "Theft"
    end
  end
end
