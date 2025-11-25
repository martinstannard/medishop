defmodule MedishopWeb.ReconciliationHistoryLiveTest do
  use MedishopWeb.ConnCase
  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Inventory

  setup do
    org = organization() |> Ash.Generator.generate()
    location = location(organization_id: org.id) |> Ash.Generator.generate()
    user = user() |> Ash.Generator.generate()
    organization_membership(organization_id: org.id, user_id: user.id, org_roles: [:org_admin]) |> Ash.Generator.generate()

    # Create past reconciliations
    # 1. Completed
    {:ok, rec1} = Inventory.create_reconciliation(%{location_id: location.id})
    
    # We need to create items and complete it properly or just force update for test data if possible?
    # Since create forces defaults, we should use the actions.
    # But complete requires items to exist? No, checks are 0 by default.
    {:ok, rec1} = Inventory.complete_reconciliation(rec1, %{
      total_items_checked: 50,
      total_discrepancies: 2,
      total_adjustments_made: 2
    })
    
    # Force update timestamps for test stability (started_at was just set to now)
    # We can use Ash.Changeset to force attributes bypassing actions for test data setup
    rec1 = 
      rec1
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now() |> DateTime.add(-2, :day))
      |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.add(1, :hour))
      |> Ash.update!()

    # 2. Cancelled
    {:ok, rec2} = Inventory.create_reconciliation(%{location_id: location.id})
    {:ok, rec2} = Inventory.cancel_reconciliation(rec2)
    
    rec2 =
      rec2
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now() |> DateTime.add(-5, :day))
      |> Ash.update!()

    %{org: org, location: location, user: user, rec1: rec1, rec2: rec2}
  end

  describe "Reconciliation History LiveView" do
    test "lists past reconciliations", %{conn: conn, location: location, user: user, rec1: rec1, rec2: rec2} do
      conn = conn |> log_in_user(user)

      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/reconciliation/history")

      assert html =~ "Reconciliation History"
      assert html =~ "Completed"
      assert html =~ "Cancelled"
      
      # Check for dates (formatted roughly)
      assert html =~ Calendar.strftime(rec1.started_at, "%b %d")
      assert html =~ Calendar.strftime(rec2.started_at, "%b %d")

      # Check stats
      assert html =~ "50" # items checked
      assert html =~ "2" # discrepancies
    end

    test "can navigate to details", %{conn: conn, location: location, user: user, rec1: rec1} do
      conn = conn |> log_in_user(user)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/reconciliation/history")

      {:ok, _detail_view, html} =
        view
        |> element("a[href='/location/#{location.id}/reconciliation/#{rec1.id}']")
        |> render_click()
        |> follow_redirect(conn, ~p"/location/#{location.id}/reconciliation/#{rec1.id}")

      assert html =~ "Reconciliation Details"
      assert html =~ "Completed"
    end
  end

  describe "Reconciliation Detail LiveView" do
    setup %{location: location, rec1: rec1} do
      # Create some items for the completed reconciliation
      product1 = product(title: "Paracetamol") |> Ash.Generator.generate()
      {:ok, inventory_item} = inventory_event(location_id: location.id, product_id: product1.id) |> Ash.Generator.generate() 
        |> then(fn _ -> Inventory.get_location_inventory_by_location_and_product(location.id, product1.id) end)

      reconciliation_item(
        reconciliation_id: rec1.id,
        product_id: product1.id,
        location_inventory_id: inventory_item.id,
        system_quantity: 10,
        physical_quantity: 8,
        adjustment_reason: :theft
      ) |> Ash.Generator.generate()

      %{product1: product1}
    end

    test "shows details and discrepancies", %{conn: conn, location: location, user: user, rec1: rec1, product1: product1} do
      conn = conn |> log_in_user(user)

      {:ok, _view, html} = live(conn, ~p"/location/#{location.id}/reconciliation/#{rec1.id}")

      assert html =~ "Reconciliation Details"
      assert html =~ "Total Items"
      assert html =~ "Discrepancies"
      
      # Check item details
      assert html =~ product1.title
      assert html =~ "-2" # Discrepancy
      assert html =~ "Theft" # Reason
    end
  end
end
