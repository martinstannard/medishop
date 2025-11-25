defmodule MedishopWeb.ReconciliationDetailLive do
  @moduledoc """
  LiveView for viewing details of a specific stock reconciliation.
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
          # Load reconciliation items
          {:ok, items} =
            Inventory.get_items_by_reconciliation(%{reconciliation_id: reconciliation.id})

          # Load products and discrepancies
          items_loaded =
            Enum.map(items, fn item ->
              {:ok, loaded} = Ash.load(item, [:product, :discrepancy, :has_discrepancy])
              loaded
            end)

          {items_with_discrepancies, items_without_discrepancies} =
            Enum.split_with(items_loaded, fn item -> item.has_discrepancy end)

          socket =
            socket
            |> assign(:location, location)
            |> assign(:reconciliation, reconciliation)
            |> assign(:items_with_discrepancies, items_with_discrepancies)
            |> assign(:items_without_discrepancies, items_without_discrepancies)
            |> assign(:page_title, "Reconciliation Details - #{location.name}")

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
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-4">
              <h1 class="text-4xl font-bold text-gray-900 dark:text-white">
                Reconciliation Details
              </h1>
              <span class={[
                "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium",
                case @reconciliation.status do
                  :completed -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                  :cancelled -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
                  :in_progress -> "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                  _ -> "bg-gray-100 text-gray-800"
                end
              ]}>
                <%= format_status(@reconciliation.status) %>
              </span>
            </div>
            <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
              <%= @location.name %> • <%= Calendar.strftime(@reconciliation.started_at, "%b %d, %Y") %>
            </p>
          </div>
          <div class="flex gap-4">
            <.link
              navigate={~p"/location/#{@location.id}/reconciliation/history"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Back to History
            </.link>
          </div>
        </div>

        <!-- Metadata Grid -->
        <div class="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-4">
          <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                Started
              </dt>
              <dd class="mt-1 text-lg font-semibold text-gray-900 dark:text-white">
                <%= Calendar.strftime(@reconciliation.started_at, "%H:%M") %>
              </dd>
            </div>
          </div>
          <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                Completed
              </dt>
              <dd class="mt-1 text-lg font-semibold text-gray-900 dark:text-white">
                <%= if @reconciliation.completed_at do %>
                  <%= Calendar.strftime(@reconciliation.completed_at, "%H:%M") %>
                <% else %>
                  -
                <% end %>
              </dd>
            </div>
          </div>
          <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                Total Items
              </dt>
              <dd class="mt-1 text-lg font-semibold text-gray-900 dark:text-white">
                <%= @reconciliation.total_items_checked %>
              </dd>
            </div>
          </div>
          <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                Discrepancies
              </dt>
              <dd class={[
                "mt-1 text-lg font-semibold",
                if(@reconciliation.total_discrepancies > 0, do: "text-red-600 dark:text-red-400", else: "text-green-600 dark:text-green-400")
              ]}>
                <%= @reconciliation.total_discrepancies %>
              </dd>
            </div>
          </div>
        </div>
      </div>

      <!-- Discrepancies Table -->
      <%= if !Enum.empty?(@items_with_discrepancies) do %>
        <div class="mb-8">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
            Discrepancies
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
                    Reason
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
                      <div class="text-sm text-gray-900 dark:text-white">
                        <%= format_adjustment_reason(item.adjustment_reason) %>
                      </div>
                      <%= if item.adjustment_notes do %>
                        <div class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                          <%= item.adjustment_notes %>
                        </div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <!-- Items Without Discrepancies (Collapsible or just listed) -->
      <%= if !Enum.empty?(@items_without_discrepancies) do %>
        <div>
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
            Items Matching System Count
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

  defp format_status(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
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
