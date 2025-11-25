defmodule MedishopWeb.StockTakeLive do
  @moduledoc """
  LiveView for performing physical stock takes and recording reconciliation data.
  Allows users to enter physical counts for all products at a location.
  """

  use MedishopWeb, :live_view

  alias Medishop.{Inventory, Organizations}

  @impl true
  def mount(%{"location_id" => location_id}, _session, socket) do
    if socket.assigns[:current_user] do
      case Organizations.get_location(location_id) do
        {:ok, location} ->
          # Load all inventory for this location first
          {:ok, inventory_items} =
            Inventory.get_inventory_by_location(%{location_id: location.id})

          # Load current quantities and products
          inventory_items =
            Enum.map(inventory_items, fn item ->
              {:ok, item_loaded} = Ash.load(item, [:current_quantity, :product])
              item_loaded
            end)

          # Check for existing reconciliation or create new one
          {reconciliation, existing_items} =
            case Inventory.get_in_progress_reconciliation(%{location_id: location.id}) do
              {:ok, [existing | _]} ->
                {:ok, items} =
                  Inventory.get_items_by_reconciliation(%{reconciliation_id: existing.id})

                {existing, items}

              _ ->
                {:ok, new_rec} =
                  Inventory.create_reconciliation(%{
                    location_id: location.id,
                    notes: ""
                  })

                {new_rec, []}
            end

          # Populate initial reconciliation_items map from existing_items
          initial_reconciliation_items =
            Enum.reduce(existing_items, %{}, fn item, acc ->
              inventory_item =
                Enum.find(inventory_items, fn inv -> inv.id == item.location_inventory_id end)

              if inventory_item do
                Map.put(acc, inventory_item.id, %{
                  inventory_item: inventory_item,
                  physical_quantity: item.physical_quantity,
                  existing_item_id: item.id
                })
              else
                acc
              end
            end)

          socket =
            socket
            |> assign(:location, location)
            |> assign(:reconciliation, reconciliation)
            |> assign(:inventory_items, inventory_items)
            |> assign(:reconciliation_items, initial_reconciliation_items)
            |> assign(:search_query, "")
            |> assign(:storage_filter, :all)
            |> assign(:page_title, "Stock Take - #{location.name}")

          {:ok, socket}

        {:error, _} ->
          socket =
            socket
            |> put_flash(:error, "Location not found")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}
      end
    else
      {:ok, socket |> redirect(to: ~p"/sign-in")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("filter_storage", %{"storage" => storage}, socket) do
    storage_atom =
      case storage do
        "all" -> :all
        "cupboard" -> :cupboard
        "fridge" -> :fridge
        "controlled_drugs_cabinet" -> :controlled_drugs_cabinet
        _ -> :all
      end

    {:noreply, assign(socket, :storage_filter, storage_atom)}
  end

  def handle_event(
        "update_count",
        %{"inventory_id" => inventory_id, "physical_count" => physical_count},
        socket
      ) do
    # Parse the physical count
    case Integer.parse(physical_count) do
      {count, _} when count >= 0 ->
        inventory_item =
          Enum.find(socket.assigns.inventory_items, fn item ->
            item.id == inventory_id
          end)

        if inventory_item do
          # Get existing item data if present
          existing_data = Map.get(socket.assigns.reconciliation_items, inventory_id, %{})

          # Update the count in reconciliation_items map
          reconciliation_items =
            Map.put(socket.assigns.reconciliation_items, inventory_id, %{
              inventory_item: inventory_item,
              physical_quantity: count,
              existing_item_id: Map.get(existing_data, :existing_item_id)
            })

          {:noreply, assign(socket, :reconciliation_items, reconciliation_items)}
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save_and_review", _params, socket) do
    reconciliation = socket.assigns.reconciliation
    reconciliation_items = socket.assigns.reconciliation_items

    # Create or update reconciliation items for all counted products
    results =
      Enum.map(reconciliation_items, fn {_inventory_id, item_data} ->
        inventory_item = item_data.inventory_item
        physical_quantity = item_data.physical_quantity
        system_quantity = inventory_item.current_quantity
        existing_item_id = Map.get(item_data, :existing_item_id)

        # Prepare base params
        params = %{
          physical_quantity: physical_quantity
        }

        # Add discrepancy related params if needed (mostly for create)
        # We don't set default reason anymore to force user to select one in review
        
        if existing_item_id do
          # Update existing item
          {:ok, existing_item} = Inventory.get_reconciliation_item(existing_item_id)
          Inventory.update_reconciliation_item(existing_item, params)
        else
          # Create new item
          create_params =
            Map.merge(params, %{
              reconciliation_id: reconciliation.id,
              product_id: inventory_item.product_id,
              location_inventory_id: inventory_item.id,
              system_quantity: system_quantity
            })

          Inventory.create_reconciliation_item(create_params)
        end
      end)

    # Check if all items were processed successfully
    errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

    if Enum.empty?(errors) do
      # Navigate to review screen
      socket =
        socket
        |> put_flash(:info, "Stock take saved. Please review discrepancies.")
        |> redirect(
          to: ~p"/location/#{socket.assigns.location.id}/reconciliation/#{reconciliation.id}/review"
        )

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Error saving stock take. Please try again.")

      {:noreply, socket}
    end
  end

  def handle_event("cancel", _params, socket) do
    # Cancel the reconciliation
    {:ok, _cancelled} =
      Inventory.cancel_reconciliation(socket.assigns.reconciliation)

    socket =
      socket
      |> put_flash(:info, "Stock take cancelled")
      |> redirect(to: ~p"/location/#{socket.assigns.location.id}/inventory")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:filtered_items, filter_items(assigns))
      |> assign(:progress, calculate_progress(assigns))

    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-4xl font-bold text-gray-900 dark:text-white">
              Stock Take
            </h1>
            <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
              <%= @location.name %>
            </p>
          </div>
          <div class="flex gap-4">
            <button
              phx-click="cancel"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </button>
            <button
              phx-click="save_and_review"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600"
            >
              Save & Review
            </button>
          </div>
        </div>

        <!-- Progress Indicator -->
        <div class="mt-4">
          <div class="flex items-center justify-between text-sm text-gray-600 dark:text-gray-400 mb-2">
            <span>Progress: <%= @progress.counted %> of <%= @progress.total %> products counted</span>
            <span><%= @progress.percentage %>%</span>
          </div>
          <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
            <div
              class="bg-blue-600 dark:bg-blue-500 h-2 rounded-full transition-all duration-300"
              style={"width: #{@progress.percentage}%"}
            >
            </div>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <!-- Search -->
        <div class="flex-1">
          <input
            type="text"
            phx-change="search"
            name="search"
            value={@search_query}
            placeholder="Search products..."
            class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Storage Location Filter -->
        <div>
          <select
            phx-change="filter_storage"
            name="storage"
            class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="all" selected={@storage_filter == :all}>All Locations</option>
            <option value="cupboard" selected={@storage_filter == :cupboard}>Cupboard</option>
            <option value="fridge" selected={@storage_filter == :fridge}>Fridge</option>
            <option value="controlled_drugs_cabinet" selected={@storage_filter == :controlled_drugs_cabinet}>
              Controlled Drugs Cabinet
            </option>
          </select>
        </div>
      </div>

      <!-- Stock Take Table -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead class="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Product
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Storage
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Unit
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                System Count
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Physical Count
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
            <%= if Enum.empty?(@filtered_items) do %>
              <tr>
                <td colspan="5" class="px-6 py-12 text-center text-gray-500 dark:text-gray-400">
                  No products found matching your criteria
                </td>
              </tr>
            <% else %>
              <%= for item <- @filtered_items do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-6 py-4">
                    <div class="text-sm font-medium text-gray-900 dark:text-white">
                      <%= item.product.title %>
                    </div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      SKU: <%= item.product.sku %>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <%= if item.product.storage_location do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                        <%= format_storage_location(item.product.storage_location) %>
                      </span>
                    <% else %>
                      <span class="text-sm text-gray-400 dark:text-gray-500">Not set</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-white">
                    <%= if item.product.unit_of_measure do %>
                      <%= format_unit_of_measure(item.product.unit_of_measure) %>
                    <% else %>
                      <span class="text-gray-400 dark:text-gray-500">-</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900 dark:text-white">
                    <%= item.current_quantity %>
                  </td>
                  <td class="px-6 py-4">
                    <input
                      type="number"
                      min="0"
                      phx-change="update_count"
                      phx-value-inventory_id={item.id}
                      name="physical_count"
                      value={get_physical_count(@reconciliation_items, item.id)}
                      placeholder="Enter count..."
                      class="w-32 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Helper functions

  defp filter_items(assigns) do
    items = assigns.inventory_items
    search = String.downcase(assigns.search_query)
    storage_filter = assigns.storage_filter

    items
    |> Enum.filter(fn item ->
      # Search filter
      search_match =
        search == "" ||
          String.contains?(String.downcase(item.product.title), search) ||
          String.contains?(String.downcase(item.product.sku), search)

      # Storage filter
      storage_match =
        storage_filter == :all ||
          item.product.storage_location == storage_filter

      search_match && storage_match
    end)
    |> Enum.sort_by(fn item -> item.product.title end)
  end

  defp calculate_progress(assigns) do
    total = length(assigns.inventory_items)
    counted = map_size(assigns.reconciliation_items)

    percentage =
      if total > 0 do
        round(counted / total * 100)
      else
        0
      end

    %{total: total, counted: counted, percentage: percentage}
  end

  defp get_physical_count(reconciliation_items, inventory_id) do
    case Map.get(reconciliation_items, inventory_id) do
      nil -> ""
      item_data -> item_data.physical_quantity
    end
  end

  defp format_storage_location(location) do
    case location do
      :cupboard -> "Cupboard"
      :fridge -> "Fridge"
      :controlled_drugs_cabinet -> "Controlled Drugs"
      _ -> to_string(location)
    end
  end

  defp format_unit_of_measure(unit) do
    case unit do
      :tablets -> "Tablets"
      :milliliters -> "mL"
      :vials -> "Vials"
      :boxes -> "Boxes"
      :bottles -> "Bottles"
      :syringes -> "Syringes"
      _ -> to_string(unit)
    end
  end
end
