defmodule MedishopWeb.ReconciliationReviewLive do
  @moduledoc """
  LiveView for reviewing stock take results and providing adjustment reasons.
  Displays discrepancies and allows editing of adjustment reasons before finalizing.
  """

  use MedishopWeb, :live_view

  alias Medishop.{Inventory, Organizations}

  @impl true
  def mount(%{"location_id" => location_id, "id" => reconciliation_id}, _session, socket) do
    if socket.assigns[:current_user] do
      with {:ok, location} <- Organizations.get_location(location_id),
           {:ok, reconciliation} <- Inventory.get_reconciliation(reconciliation_id) do
        # Verify reconciliation belongs to this location
        if reconciliation.location_id == location.id do
          # Load reconciliation items with all needed data
          {:ok, items} =
            Inventory.get_items_by_reconciliation(%{reconciliation_id: reconciliation.id})

          # Load products and discrepancy calculations
          items_loaded =
            Enum.map(items, fn item ->
              {:ok, loaded} = Ash.load(item, [:product, :discrepancy, :has_discrepancy])
              loaded
            end)

          # Split items into those with/without discrepancies
          {items_with_discrepancies, items_without_discrepancies} =
            Enum.split_with(items_loaded, fn item -> item.has_discrepancy end)

          socket =
            socket
            |> assign(:location, location)
            |> assign(:reconciliation, reconciliation)
            |> assign(:items_with_discrepancies, items_with_discrepancies)
            |> assign(:items_without_discrepancies, items_without_discrepancies)
            |> assign(:editing_item, nil)
            |> assign(:page_title, "Review Stock Take - #{location.name}")

          {:ok, socket}
        else
          socket =
            socket
            |> put_flash(:error, "Reconciliation not found for this location")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}
        end
      else
        {:error, _} ->
          socket =
            socket
            |> put_flash(:error, "Reconciliation not found")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}
      end
    else
      {:ok, socket |> redirect(to: ~p"/sign-in")}
    end
  end

  @impl true
  def handle_event("edit_reason", %{"item_id" => item_id}, socket) do
    item =
      Enum.find(socket.assigns.items_with_discrepancies, fn i ->
        i.id == item_id
      end)

    {:noreply, assign(socket, :editing_item, item)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_item, nil)}
  end

  def handle_event(
        "update_reason",
        %{"item_id" => item_id, "adjustment_reason" => reason, "adjustment_notes" => notes},
        socket
      ) do
    item =
      Enum.find(socket.assigns.items_with_discrepancies, fn i ->
        i.id == item_id
      end)

    if item do
      reason_atom = String.to_existing_atom(reason)

      case Inventory.update_reconciliation_item(item, %{
             adjustment_reason: reason_atom,
             adjustment_notes: notes
           }) do
        {:ok, updated_item} ->
          # Reload the item with relationships
          {:ok, updated_loaded} = Ash.load(updated_item, [:product, :discrepancy, :has_discrepancy])

          # Update the items list
          updated_items =
            Enum.map(socket.assigns.items_with_discrepancies, fn i ->
              if i.id == item_id, do: updated_loaded, else: i
            end)

          socket =
            socket
            |> assign(:items_with_discrepancies, updated_items)
            |> assign(:editing_item, nil)
            |> put_flash(:info, "Adjustment reason updated")

          {:noreply, socket}

        {:error, _error} ->
          socket =
            socket
            |> put_flash(:error, "Failed to update adjustment reason")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("complete_reconciliation", _params, socket) do
    reconciliation = socket.assigns.reconciliation
    items_with_discrepancies = socket.assigns.items_with_discrepancies
    items_without_discrepancies = socket.assigns.items_without_discrepancies

    total_items = length(items_with_discrepancies) + length(items_without_discrepancies)
    total_discrepancies = length(items_with_discrepancies)

    # Check that all discrepancies have adjustment reasons
    missing_reasons =
      Enum.filter(items_with_discrepancies, fn item ->
        is_nil(item.adjustment_reason)
      end)

    if Enum.empty?(missing_reasons) do
      # Complete the reconciliation
      case Inventory.complete_reconciliation(reconciliation, %{
             total_items_checked: total_items,
             total_discrepancies: total_discrepancies,
             total_adjustments_made: total_discrepancies
           }) do
        {:ok, _completed} ->
          socket =
            socket
            |> put_flash(:info, "Stock take completed successfully")
            |> redirect(to: ~p"/location/#{socket.assigns.location.id}/inventory")

          {:noreply, socket}

        {:error, _error} ->
          socket =
            socket
            |> put_flash(:error, "Failed to complete stock take")

          {:noreply, socket}
      end
    else
      socket =
        socket
        |> put_flash(
          :error,
          "Please provide adjustment reasons for all discrepancies before completing"
        )

      {:noreply, socket}
    end
  end

  def handle_event("back_to_stock_take", _params, socket) do
    socket =
      socket
      |> redirect(to: ~p"/location/#{socket.assigns.location.id}/stock-take")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :summary, calculate_summary(assigns))

    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-4xl font-bold text-gray-900 dark:text-white">
              Review Stock Take
            </h1>
            <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
              <%= @location.name %>
            </p>
          </div>
          <div class="flex gap-4">
            <button
              phx-click="back_to_stock_take"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Back to Stock Take
            </button>
            <button
              phx-click="complete_reconciliation"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600"
            >
              Complete Stock Take
            </button>
          </div>
        </div>

        <!-- Summary Cards -->
        <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Total Items Checked
            </div>
            <div class="mt-2 text-3xl font-bold text-gray-900 dark:text-white">
              <%= @summary.total_items %>
            </div>
          </div>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Discrepancies Found
            </div>
            <div class="mt-2 text-3xl font-bold text-red-600 dark:text-red-400">
              <%= @summary.total_discrepancies %>
            </div>
          </div>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Items Matching
            </div>
            <div class="mt-2 text-3xl font-bold text-green-600 dark:text-green-400">
              <%= @summary.items_matching %>
            </div>
          </div>
        </div>
      </div>

      <!-- Items with Discrepancies -->
      <%= if Enum.empty?(@items_with_discrepancies) do %>
        <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-6 mb-8">
          <div class="flex items-center">
            <svg
              class="h-6 w-6 text-green-600 dark:text-green-400 mr-3"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <div>
              <h3 class="text-lg font-medium text-green-900 dark:text-green-100">
                No discrepancies found
              </h3>
              <p class="text-sm text-green-700 dark:text-green-300 mt-1">
                All physical counts match the system records.
              </p>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mb-8">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
            Items with Discrepancies (<%= length(@items_with_discrepancies) %>)
          </h2>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Product
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    System
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Physical
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Difference
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Adjustment Reason
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for item <- @items_with_discrepancies do %>
                  <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                    <td class="px-6 py-4">
                      <div class="text-sm font-medium text-gray-900 dark:text-white">
                        <%= item.product.title %>
                      </div>
                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        SKU: <%= item.product.sku %>
                      </div>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900 dark:text-white">
                      <%= item.system_quantity %>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900 dark:text-white">
                      <%= item.physical_quantity %>
                    </td>
                    <td class="px-6 py-4">
                      <span class={[
                        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                        if(item.discrepancy < 0,
                          do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200",
                          else: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                        )
                      ]}>
                        <%= if item.discrepancy > 0, do: "+#{item.discrepancy}", else: item.discrepancy %>
                      </span>
                    </td>
                    <td class="px-6 py-4">
                      <%= if @editing_item && @editing_item.id == item.id do %>
                        <form phx-submit="update_reason" class="space-y-2">
                          <input type="hidden" name="item_id" value={item.id} />
                          <select
                            name="adjustment_reason"
                            class="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                          >
                            <option value="training_stock" selected={item.adjustment_reason == :training_stock}>
                              Training Stock
                            </option>
                            <option value="breakage" selected={item.adjustment_reason == :breakage}>
                              Breakage
                            </option>
                            <option value="expired" selected={item.adjustment_reason == :expired}>
                              Expired
                            </option>
                            <option value="theft" selected={item.adjustment_reason == :theft}>
                              Theft
                            </option>
                            <option value="count_error" selected={item.adjustment_reason == :count_error}>
                              Count Error
                            </option>
                            <option value="system_error" selected={item.adjustment_reason == :system_error}>
                              System Error
                            </option>
                            <option value="spillage" selected={item.adjustment_reason == :spillage}>
                              Spillage
                            </option>
                            <option value="other" selected={item.adjustment_reason == :other}>
                              Other
                            </option>
                          </select>
                          <input
                            type="text"
                            name="adjustment_notes"
                            value={item.adjustment_notes || ""}
                            placeholder="Additional notes (optional)"
                            class="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                          />
                          <div class="flex gap-2">
                            <button
                              type="submit"
                              class="px-3 py-1 text-xs font-medium text-white bg-blue-600 rounded hover:bg-blue-700"
                            >
                              Save
                            </button>
                            <button
                              type="button"
                              phx-click="cancel_edit"
                              class="px-3 py-1 text-xs font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded hover:bg-gray-50 dark:hover:bg-gray-700"
                            >
                              Cancel
                            </button>
                          </div>
                        </form>
                      <% else %>
                        <%= if item.adjustment_reason do %>
                          <div>
                            <div class="text-sm font-medium text-gray-900 dark:text-white">
                              <%= format_adjustment_reason(item.adjustment_reason) %>
                            </div>
                            <%= if item.adjustment_notes && item.adjustment_notes != "" do %>
                              <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                <%= item.adjustment_notes %>
                              </div>
                            <% end %>
                          </div>
                        <% else %>
                          <span class="text-sm text-red-600 dark:text-red-400 font-medium">
                            Reason required
                          </span>
                        <% end %>
                      <% end %>
                    </td>
                    <td class="px-6 py-4">
                      <%= if !@editing_item || @editing_item.id != item.id do %>
                        <button
                          phx-click="edit_reason"
                          phx-value-item_id={item.id}
                          class="text-sm font-medium text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
                        >
                          <%= if item.adjustment_reason, do: "Edit", else: "Add Reason" %>
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
      <!-- Items Without Discrepancies -->
      <%= if !Enum.empty?(@items_without_discrepancies) do %>
        <div class="mb-8">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
            Items Matching (<%= length(@items_without_discrepancies) %>)
          </h2>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Product
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Quantity
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for item <- @items_without_discrepancies do %>
                  <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                    <td class="px-6 py-4">
                      <div class="text-sm font-medium text-gray-900 dark:text-white">
                        <%= item.product.title %>
                      </div>
                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        SKU: <%= item.product.sku %>
                      </div>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900 dark:text-white">
                      <%= item.system_quantity %>
                    </td>
                    <td class="px-6 py-4">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                        Verified
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp calculate_summary(assigns) do
    total_items =
      length(assigns.items_with_discrepancies) + length(assigns.items_without_discrepancies)

    total_discrepancies = length(assigns.items_with_discrepancies)
    items_matching = length(assigns.items_without_discrepancies)

    %{
      total_items: total_items,
      total_discrepancies: total_discrepancies,
      items_matching: items_matching
    }
  end

  defp format_adjustment_reason(reason) do
    case reason do
      :training_stock -> "Training Stock"
      :breakage -> "Breakage"
      :expired -> "Expired"
      :theft -> "Theft"
      :count_error -> "Count Error"
      :system_error -> "System Error"
      :spillage -> "Spillage"
      :other -> "Other"
      _ -> to_string(reason)
    end
  end
end
