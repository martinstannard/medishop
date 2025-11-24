defmodule Medishop.Inventory.ReconciliationItemTest do
  use Medishop.DataCase, async: true
  import Medishop.Generator

  alias Medishop.Inventory

  describe "create_reconciliation_item/1" do
    test "creates a reconciliation item" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      location_inventory =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      assert {:ok, item} =
               Inventory.create_reconciliation_item(%{
                 reconciliation_id: reconciliation.id,
                 product_id: product.id,
                 location_inventory_id: location_inventory.id,
                 system_quantity: 10,
                 physical_quantity: 10
               })

      assert item.reconciliation_id == reconciliation.id
      assert item.product_id == product.id
      assert item.location_inventory_id == location_inventory.id
      assert item.system_quantity == 10
      assert item.physical_quantity == 10
    end

    test "creates item with adjustment reason when there's a discrepancy" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      location_inventory =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      assert {:ok, item} =
               Inventory.create_reconciliation_item(%{
                 reconciliation_id: reconciliation.id,
                 product_id: product.id,
                 location_inventory_id: location_inventory.id,
                 system_quantity: 10,
                 physical_quantity: 8,
                 adjustment_reason: :breakage,
                 adjustment_notes: "Two units damaged during inspection"
               })

      assert item.adjustment_reason == :breakage
      assert item.adjustment_notes == "Two units damaged during inspection"
    end

    test "requires adjustment_reason when system and physical quantities differ" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      location_inventory =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      assert {:error, %Ash.Error.Invalid{} = error} =
               Inventory.create_reconciliation_item(%{
                 reconciliation_id: reconciliation.id,
                 product_id: product.id,
                 location_inventory_id: location_inventory.id,
                 system_quantity: 10,
                 physical_quantity: 7
               })

      assert Exception.message(error) =~ "Adjustment reason is required"
    end

    test "requires adjustment_notes when reason is :other" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      location_inventory =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      assert {:error, %Ash.Error.Invalid{} = error} =
               Inventory.create_reconciliation_item(%{
                 reconciliation_id: reconciliation.id,
                 product_id: product.id,
                 location_inventory_id: location_inventory.id,
                 system_quantity: 10,
                 physical_quantity: 7,
                 adjustment_reason: :other
               })

      assert Exception.message(error) =~ "Additional notes are required"
    end

    test "accepts all valid adjustment reasons" do
      reasons = [
        :training_stock,
        :breakage,
        :expired,
        :theft,
        :count_error,
        :system_error,
        :spillage,
        :other
      ]

      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      Enum.each(reasons, fn reason ->
        # Generate a new product for each reason to avoid unique constraint violation
        prod = product() |> Ash.Generator.generate()

        loc_inv =
          location_inventory(
            location_id: reconciliation.location_id,
            product_id: prod.id
          )
          |> Ash.Generator.generate()

        notes = if reason == :other, do: "Some explanation", else: nil

        assert {:ok, _item} =
                 Inventory.create_reconciliation_item(%{
                   reconciliation_id: reconciliation.id,
                   product_id: prod.id,
                   location_inventory_id: loc_inv.id,
                   system_quantity: 10,
                   physical_quantity: 8,
                   adjustment_reason: reason,
                   adjustment_notes: notes
                 })
      end)
    end

    test "enforces unique reconciliation_id and product_id combination" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      location_inventory =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, _item1} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: location_inventory.id,
          system_quantity: 10,
          physical_quantity: 10
        })

      # Try to create another item for the same product in same reconciliation
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_reconciliation_item(%{
                 reconciliation_id: reconciliation.id,
                 product_id: product.id,
                 location_inventory_id: location_inventory.id,
                 system_quantity: 15,
                 physical_quantity: 15
               })
    end
  end

  describe "get_reconciliation_item/1" do
    test "retrieves a reconciliation item by id" do
      item = reconciliation_item() |> Ash.Generator.generate()

      assert {:ok, fetched} = Inventory.get_reconciliation_item(item.id)
      assert fetched.id == item.id
    end
  end

  describe "list_reconciliation_items/0" do
    test "returns all reconciliation items" do
      item1 = reconciliation_item() |> Ash.Generator.generate()
      item2 = reconciliation_item() |> Ash.Generator.generate()

      {:ok, items} = Inventory.list_reconciliation_items()

      ids = Enum.map(items, & &1.id)
      assert item1.id in ids
      assert item2.id in ids
    end
  end

  describe "get_items_by_reconciliation/1" do
    test "returns items for a specific reconciliation" do
      reconciliation1 = stock_reconciliation() |> Ash.Generator.generate()
      reconciliation2 = stock_reconciliation() |> Ash.Generator.generate()

      item1 =
        reconciliation_item(reconciliation_id: reconciliation1.id)
        |> Ash.Generator.generate()

      item2 =
        reconciliation_item(reconciliation_id: reconciliation2.id)
        |> Ash.Generator.generate()

      {:ok, items} =
        Inventory.get_items_by_reconciliation(%{reconciliation_id: reconciliation1.id})

      ids = Enum.map(items, & &1.id)
      assert item1.id in ids
      refute item2.id in ids
    end

    test "returns empty list for reconciliation with no items" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()

      {:ok, items} =
        Inventory.get_items_by_reconciliation(%{reconciliation_id: reconciliation.id})

      assert items == []
    end
  end

  describe "get_items_with_discrepancies/1" do
    test "returns only items with discrepancies" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product1 = product() |> Ash.Generator.generate()
      product2 = product() |> Ash.Generator.generate()

      loc_inv1 =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product1.id
        )
        |> Ash.Generator.generate()

      loc_inv2 =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product2.id
        )
        |> Ash.Generator.generate()

      # Item with no discrepancy
      {:ok, item_no_disc} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product1.id,
          location_inventory_id: loc_inv1.id,
          system_quantity: 10,
          physical_quantity: 10
        })

      # Item with discrepancy
      {:ok, item_with_disc} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product2.id,
          location_inventory_id: loc_inv2.id,
          system_quantity: 10,
          physical_quantity: 7,
          adjustment_reason: :breakage
        })

      {:ok, items} =
        Inventory.get_items_with_discrepancies(%{reconciliation_id: reconciliation.id})

      ids = Enum.map(items, & &1.id)
      assert item_with_disc.id in ids
      refute item_no_disc.id in ids
    end
  end

  describe "update_reconciliation_item/2" do
    test "updates physical_quantity without creating discrepancy" do
      # Start with a discrepancy, update to a different value with same discrepancy
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 8,
          adjustment_reason: :breakage
        })

      # Update physical_quantity to a new value (still has discrepancy but reason already provided)
      assert {:ok, updated} =
               Inventory.update_reconciliation_item(item, %{
                 physical_quantity: 7
               })

      assert updated.physical_quantity == 7
    end

    test "updates physical_quantity and requires adjustment_reason when creating new discrepancy" do
      # Start with no discrepancy, update to create one
      item = reconciliation_item(system_quantity: 10, physical_quantity: 10) |> Ash.Generator.generate()

      # This should fail because we're creating a discrepancy without providing a reason
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.update_reconciliation_item(item, %{
                 physical_quantity: 12
               })

      # Now provide the reason - should succeed
      assert {:ok, updated} =
               Inventory.update_reconciliation_item(item, %{
                 physical_quantity: 12,
                 adjustment_reason: :count_error
               })

      assert updated.physical_quantity == 12
      assert updated.adjustment_reason == :count_error
    end

    test "updates adjustment_reason and notes" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 8,
          adjustment_reason: :breakage
        })

      assert {:ok, updated} =
               Inventory.update_reconciliation_item(item, %{
                 adjustment_reason: :expired,
                 adjustment_notes: "Found expired during count"
               })

      assert updated.adjustment_reason == :expired
      assert updated.adjustment_notes == "Found expired during count"
    end
  end

  describe "discrepancy calculation" do
    test "calculates positive discrepancy (physical > system)" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 12,
          adjustment_reason: :count_error
        })

      {:ok, loaded} = item |> Ash.load(:discrepancy)
      assert loaded.discrepancy == 2
    end

    test "calculates negative discrepancy (physical < system)" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 7,
          adjustment_reason: :theft
        })

      {:ok, loaded} = item |> Ash.load(:discrepancy)
      assert loaded.discrepancy == -3
    end

    test "calculates zero discrepancy when quantities match" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 10
        })

      {:ok, loaded} = item |> Ash.load(:discrepancy)
      assert loaded.discrepancy == 0
    end
  end

  describe "has_discrepancy calculation" do
    test "returns true when there is a discrepancy" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 7,
          adjustment_reason: :breakage
        })

      {:ok, loaded} = item |> Ash.load(:has_discrepancy)
      assert loaded.has_discrepancy == true
    end

    test "returns false when there is no discrepancy" do
      reconciliation = stock_reconciliation() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()
      loc_inv =
        location_inventory(
          location_id: reconciliation.location_id,
          product_id: product.id
        )
        |> Ash.Generator.generate()

      {:ok, item} =
        Inventory.create_reconciliation_item(%{
          reconciliation_id: reconciliation.id,
          product_id: product.id,
          location_inventory_id: loc_inv.id,
          system_quantity: 10,
          physical_quantity: 10
        })

      {:ok, loaded} = item |> Ash.load(:has_discrepancy)
      assert loaded.has_discrepancy == false
    end
  end

  describe "destroy_reconciliation_item/1" do
    test "deletes a reconciliation item" do
      item = reconciliation_item() |> Ash.Generator.generate()

      assert :ok = Inventory.destroy_reconciliation_item(item)

      assert {:error, error} = Inventory.get_reconciliation_item(item.id)
      # Error may be wrapped in Ash.Error.Invalid
      assert match?(%Ash.Error.Query.NotFound{}, error) or
               match?(%Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}, error)
    end
  end
end
