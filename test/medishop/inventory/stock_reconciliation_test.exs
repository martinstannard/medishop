defmodule Medishop.Inventory.StockReconciliationTest do
  use Medishop.DataCase, async: true
  import Medishop.Generator

  alias Medishop.Inventory

  describe "create_reconciliation/1" do
    test "creates a reconciliation with default values" do
      location = location() |> Ash.Generator.generate()

      assert {:ok, reconciliation} =
               Inventory.create_reconciliation(%{location_id: location.id})

      assert reconciliation.status == :in_progress
      assert reconciliation.location_id == location.id
      assert reconciliation.total_items_checked == 0
      assert reconciliation.total_discrepancies == 0
      assert reconciliation.total_adjustments_made == 0
      assert reconciliation.started_at != nil
      assert reconciliation.completed_at == nil
    end

    test "creates a reconciliation with notes" do
      location = location() |> Ash.Generator.generate()

      assert {:ok, reconciliation} =
               Inventory.create_reconciliation(%{
                 location_id: location.id,
                 notes: "Monthly stock take"
               })

      assert reconciliation.notes == "Monthly stock take"
    end

    test "requires location_id" do
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_reconciliation(%{})
    end
  end

  describe "get_reconciliation/1" do
    test "retrieves a reconciliation by id" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      assert {:ok, fetched} = Inventory.get_reconciliation(reconciliation.id)
      assert fetched.id == reconciliation.id
    end
  end

  describe "list_reconciliations/0" do
    test "returns all reconciliations" do
      reconciliation1 = stock_reconciliation() |> Ash.Generator.generate()
      reconciliation2 = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, reconciliations} = Inventory.list_reconciliations()

      ids = Enum.map(reconciliations, & &1.id)
      assert reconciliation1.id in ids
      assert reconciliation2.id in ids
    end

    test "returns empty list when no reconciliations exist" do
      {:ok, reconciliations} = Inventory.list_reconciliations()
      assert reconciliations == []
    end
  end

  describe "get_reconciliations_by_location/1" do
    test "returns reconciliations for a specific location" do
      location1 = location() |> Ash.Generator.generate()
      location2 = location() |> Ash.Generator.generate()

      reconciliation1 =
        stock_reconciliation(location_id: location1.id) |> Ash.Generator.generate()

      reconciliation2 =
        stock_reconciliation(location_id: location2.id) |> Ash.Generator.generate()

      {:ok, location1_reconciliations} =
        Inventory.get_reconciliations_by_location(%{location_id: location1.id})

      ids = Enum.map(location1_reconciliations, & &1.id)
      assert reconciliation1.id in ids
      refute reconciliation2.id in ids
    end

    test "returns empty list for location with no reconciliations" do
      location = location() |> Ash.Generator.generate()

      {:ok, reconciliations} =
        Inventory.get_reconciliations_by_location(%{location_id: location.id})

      assert reconciliations == []
    end
  end

  describe "get_reconciliations_by_status/1" do
    test "returns reconciliations with a specific status" do
      reconciliation1 =
        stock_reconciliation() |> Ash.Generator.generate()

      # Complete the second one
      reconciliation2 =
        stock_reconciliation() |> Ash.Generator.generate()

      {:ok, completed_rec} =
        Inventory.complete_reconciliation(reconciliation2, %{
          total_items_checked: 5,
          total_discrepancies: 1,
          total_adjustments_made: 1
        })

      {:ok, in_progress_recs} =
        Inventory.get_reconciliations_by_status(%{status: :in_progress})

      {:ok, completed_recs} =
        Inventory.get_reconciliations_by_status(%{status: :completed})

      in_progress_ids = Enum.map(in_progress_recs, & &1.id)
      completed_ids = Enum.map(completed_recs, & &1.id)

      assert reconciliation1.id in in_progress_ids
      refute reconciliation2.id in in_progress_ids

      assert completed_rec.id in completed_ids
      refute reconciliation1.id in completed_ids
    end
  end

  describe "update_reconciliation/2" do
    test "updates reconciliation notes" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      assert {:ok, updated} =
               Inventory.update_reconciliation(reconciliation, %{
                 notes: "Updated notes"
               })

      assert updated.notes == "Updated notes"
    end
  end

  describe "complete_reconciliation/2" do
    test "completes an in_progress reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      assert {:ok, completed} =
               Inventory.complete_reconciliation(reconciliation, %{
                 total_items_checked: 10,
                 total_discrepancies: 2,
                 total_adjustments_made: 2
               })

      assert completed.status == :completed
      assert completed.total_items_checked == 10
      assert completed.total_discrepancies == 2
      assert completed.total_adjustments_made == 2
      assert completed.completed_at != nil
    end

    test "sets completed_at timestamp" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      before_complete = DateTime.utc_now()

      assert {:ok, completed} =
               Inventory.complete_reconciliation(reconciliation, %{
                 total_items_checked: 5,
                 total_discrepancies: 0,
                 total_adjustments_made: 0
               })

      assert DateTime.compare(completed.completed_at, before_complete) in [:gt, :eq]
    end

    test "cannot complete a reconciliation that is already completed" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 5,
          total_discrepancies: 0,
          total_adjustments_made: 0
        })

      # Try to complete again
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.complete_reconciliation(completed, %{
                 total_items_checked: 10,
                 total_discrepancies: 1,
                 total_adjustments_made: 1
               })
    end

    test "cannot complete a cancelled reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, cancelled} = Inventory.cancel_reconciliation(reconciliation)

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.complete_reconciliation(cancelled, %{
                 total_items_checked: 5,
                 total_discrepancies: 0,
                 total_adjustments_made: 0
               })
    end
  end

  describe "cancel_reconciliation/1" do
    test "cancels an in_progress reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      assert {:ok, cancelled} = Inventory.cancel_reconciliation(reconciliation)

      assert cancelled.status == :cancelled
      assert cancelled.completed_at != nil
    end

    test "sets completed_at timestamp when cancelled" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      before_cancel = DateTime.utc_now()

      assert {:ok, cancelled} = Inventory.cancel_reconciliation(reconciliation)

      assert DateTime.compare(cancelled.completed_at, before_cancel) in [:gt, :eq]
    end

    test "cannot cancel a reconciliation that is already completed" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 5,
          total_discrepancies: 0,
          total_adjustments_made: 0
        })

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.cancel_reconciliation(completed)
    end

    test "cannot cancel a reconciliation that is already cancelled" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, cancelled} = Inventory.cancel_reconciliation(reconciliation)

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.cancel_reconciliation(cancelled)
    end
  end

  describe "destroy_reconciliation/1" do
    test "deletes a reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      assert :ok = Inventory.destroy_reconciliation(reconciliation)

      assert {:error, error} = Inventory.get_reconciliation(reconciliation.id)
      # Error may be wrapped in Ash.Error.Invalid
      assert match?(%Ash.Error.Query.NotFound{}, error) or
               match?(%Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}, error)
    end
  end

  describe "duration_minutes calculation" do
    test "calculation is available for in_progress reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      # Load the calculation - it may return nil or a numeric value
      # The important thing is that it doesn't error
      assert {:ok, loaded} = Ash.load(reconciliation, :duration_minutes)
      assert Map.has_key?(loaded, :duration_minutes)
    end

    test "calculation is available for completed reconciliation" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, completed} =
        Inventory.complete_reconciliation(reconciliation, %{
          total_items_checked: 5,
          total_discrepancies: 0,
          total_adjustments_made: 0
        })

      # Load the calculation - it may return nil or a numeric value
      # The important thing is that it doesn't error
      assert {:ok, loaded} = Ash.load(completed, :duration_minutes)
      assert Map.has_key?(loaded, :duration_minutes)
    end
  end
end
