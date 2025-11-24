defmodule MedishopWeb.ReconciliationHistoryLive do
  @moduledoc """
  LiveView for viewing the history of stock reconciliations for a location.
  """

  use MedishopWeb, :live_view

  alias Medishop.{Inventory, Organizations}

  @impl true
  def mount(%{"location_id" => location_id}, _session, socket) do
    if socket.assigns[:current_user] do
      case Organizations.get_location(location_id) do
        {:ok, location} ->
          {:ok, reconciliations} =
            Inventory.get_reconciliations_by_location(%{location_id: location.id})

          # Sort by started_at descending
          reconciliations =
            Enum.sort_by(reconciliations, & &1.started_at, {:desc, DateTime})

          socket =
            socket
            |> assign(:location, location)
            |> assign(:reconciliations, reconciliations)
            |> assign(:page_title, "Reconciliation History - #{location.name}")

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
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <!-- Header -->
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-4xl font-bold text-gray-900 dark:text-white">
            Reconciliation History
          </h1>
          <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
            <%= @location.name %>
          </p>
        </div>
        <div class="flex gap-4">
          <.link
            navigate={~p"/location/#{@location.id}/inventory"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
          >
            Back to Inventory
          </.link>
          <.link
            navigate={~p"/location/#{@location.id}/stock-take"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600"
          >
            Start New Stock Take
          </.link>
        </div>
      </div>

      <!-- Reconciliations List -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead class="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Date
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Items Checked
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Discrepancies
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
            <%= if Enum.empty?(@reconciliations) do %>
              <tr>
                <td colspan="5" class="px-6 py-12 text-center text-gray-500 dark:text-gray-400">
                  No reconciliations found
                </td>
              </tr>
            <% else %>
              <%= for reconciliation <- @reconciliations do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    <%= Calendar.strftime(reconciliation.started_at, "%b %d, %Y %H:%M") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                      case reconciliation.status do
                        :completed -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                        :cancelled -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
                        :in_progress -> "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= format_status(reconciliation.status) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    <%= reconciliation.total_items_checked %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    <%= if reconciliation.status == :completed do %>
                       <span class={if reconciliation.total_discrepancies > 0, do: "text-red-600 dark:text-red-400 font-medium", else: "text-gray-500"}>
                        <%= reconciliation.total_discrepancies %>
                      </span>
                    <% else %>
                      -
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link
                      navigate={~p"/location/#{@location.id}/reconciliation/#{reconciliation.id}"}
                      class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300"
                    >
                      View Details
                    </.link>
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

  defp format_status(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
