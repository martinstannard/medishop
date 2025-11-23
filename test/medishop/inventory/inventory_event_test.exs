defmodule Medishop.Inventory.InventoryEventTest do
  use Medishop.DataCase

  alias Medishop.Inventory

  import Medishop.OrganizationsFixtures
  import Medishop.ProductsFixtures

  defp setup_location_and_product(_context) do
    organization = organization_fixture()
    location = location_fixture(organization.id)
    product = product_fixture()
    %{location: location, product: product}
  end

  describe "create_inventory_event/1" do
    setup :setup_location_and_product

    test "creates a purchase_received event", %{location: location, product: product} do
      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :purchase_received,
                 quantity_change: 100,
                 occurred_at: DateTime.utc_now()
               })

      assert event.event_type == :purchase_received
      assert event.quantity_change == 100
      assert event.location_id == location.id
      assert event.product_id == product.id
      assert event.occurred_at != nil
    end

    test "creates an administered event", %{location: location, product: product} do
      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :administered,
                 quantity_change: -5,
                 occurred_at: DateTime.utc_now()
               })

      assert event.event_type == :administered
      assert event.quantity_change == -5
    end

    test "creates an expired event", %{location: location, product: product} do
      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :expired,
                 quantity_change: -10,
                 batch_number: "BATCH123",
                 expiration_date: ~D[2025-01-01],
                 occurred_at: DateTime.utc_now()
               })

      assert event.event_type == :expired
      assert event.quantity_change == -10
      assert event.batch_number == "BATCH123"
      assert event.expiration_date == ~D[2025-01-01]
    end

    test "creates a disposed event with reason", %{location: location, product: product} do
      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :disposed,
                 quantity_change: -25,
                 reason: "Damaged during transport",
                 occurred_at: DateTime.utc_now()
               })

      assert event.event_type == :disposed
      assert event.quantity_change == -25
      assert event.reason == "Damaged during transport"
    end

    test "creates an adjustment event with reason", %{location: location, product: product} do
      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :adjustment,
                 quantity_change: 15,
                 reason: "Physical count discrepancy",
                 occurred_at: DateTime.utc_now()
               })

      assert event.event_type == :adjustment
      assert event.quantity_change == 15
      assert event.reason == "Physical count discrepancy"
    end

    test "creates an event with reference to order", %{location: location, product: product} do
      order_id = Ash.UUID.generate()

      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :purchase_received,
                 quantity_change: 50,
                 reference_type: "Order",
                 reference_id: order_id,
                 occurred_at: DateTime.utc_now()
               })

      assert event.reference_type == "Order"
      assert event.reference_id == order_id
    end

    test "defaults occurred_at to current time if not provided", %{
      location: location,
      product: product
    } do
      before = DateTime.utc_now()

      assert {:ok, event} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :purchase_received,
                 quantity_change: 10
               })

      after_create = DateTime.utc_now()

      assert DateTime.compare(event.occurred_at, before) in [:gt, :eq]
      assert DateTime.compare(event.occurred_at, after_create) in [:lt, :eq]
    end

    test "requires reason for disposed events", %{location: location, product: product} do
      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :disposed,
                 quantity_change: -5,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :reason end)
    end

    test "requires reason for adjustment events", %{location: location, product: product} do
      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :adjustment,
                 quantity_change: 10,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :reason end)
    end

    test "requires event_type", %{location: location, product: product} do
      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 quantity_change: 10,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :event_type end)
    end

    test "requires quantity_change", %{location: location, product: product} do
      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 product_id: product.id,
                 event_type: :purchase_received,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :quantity_change end)
    end

    test "requires location_id" do
      product = product_fixture()

      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 product_id: product.id,
                 event_type: :purchase_received,
                 quantity_change: 10,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :location_id end)
    end

    test "requires product_id" do
      organization = organization_fixture()
      location = location_fixture(organization.id)

      assert {:error, error} =
               Inventory.create_inventory_event(%{
                 location_id: location.id,
                 event_type: :purchase_received,
                 quantity_change: 10,
                 occurred_at: DateTime.utc_now()
               })

      assert error.errors
             |> Enum.any?(fn e -> e.field == :product_id end)
    end
  end

  describe "list_inventory_events/0" do
    setup :setup_location_and_product

    test "returns all events", %{location: location, product: product} do
      {:ok, _event1} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event2} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :administered,
          quantity_change: -5,
          occurred_at: DateTime.utc_now()
        })

      assert {:ok, events} = Inventory.list_inventory_events()
      assert length(events) >= 2
    end
  end

  describe "get_events_by_location_and_product/2" do
    test "returns events filtered by location and product" do
      org1 = organization_fixture()
      location1 = location_fixture(org1.id)
      org2 = organization_fixture()
      location2 = location_fixture(org2.id)
      product1 = product_fixture()
      product2 = product_fixture()

      {:ok, event1} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event2} =
        Inventory.create_inventory_event(%{
          location_id: location2.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event3} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product2.id,
          event_type: :purchase_received,
          quantity_change: 75,
          occurred_at: DateTime.utc_now()
        })

      assert {:ok, events} =
               Inventory.get_events_by_location_and_product(%{
                 location_id: location1.id,
                 product_id: product1.id
               })

      assert length(events) == 1
      assert hd(events).id == event1.id
    end
  end

  describe "get_events_by_location/1" do
    test "returns events filtered by location" do
      org1 = organization_fixture()
      location1 = location_fixture(org1.id)
      org2 = organization_fixture()
      location2 = location_fixture(org2.id)
      product = product_fixture()

      {:ok, event1} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, event2} =
        Inventory.create_inventory_event(%{
          location_id: location1.id,
          product_id: product.id,
          event_type: :administered,
          quantity_change: -5,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event3} =
        Inventory.create_inventory_event(%{
          location_id: location2.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      assert {:ok, events} = Inventory.get_events_by_location(%{location_id: location1.id})

      assert length(events) == 2
      event_ids = Enum.map(events, & &1.id)
      assert event1.id in event_ids
      assert event2.id in event_ids
    end
  end

  describe "get_events_by_product/1" do
    setup :setup_location_and_product

    test "returns events filtered by product", %{location: location} do
      product1 = product_fixture()
      product2 = product_fixture()

      {:ok, event1} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product1.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      {:ok, event2} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product1.id,
          event_type: :administered,
          quantity_change: -5,
          occurred_at: DateTime.utc_now()
        })

      {:ok, _event3} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product2.id,
          event_type: :purchase_received,
          quantity_change: 50,
          occurred_at: DateTime.utc_now()
        })

      assert {:ok, events} = Inventory.get_events_by_product(%{product_id: product1.id})

      assert length(events) == 2
      event_ids = Enum.map(events, & &1.id)
      assert event1.id in event_ids
      assert event2.id in event_ids
    end
  end

  describe "net_change calculation" do
    setup :setup_location_and_product

    test "returns quantity_change as net_change", %{location: location, product: product} do
      {:ok, event} =
        Inventory.create_inventory_event(%{
          location_id: location.id,
          product_id: product.id,
          event_type: :purchase_received,
          quantity_change: 100,
          occurred_at: DateTime.utc_now()
        })

      # Load with calculation
      {:ok, event_with_calc} = Ash.load(event, :net_change)
      assert event_with_calc.net_change == 100
    end
  end
end
