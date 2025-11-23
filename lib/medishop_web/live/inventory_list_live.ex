defmodule MedishopWeb.InventoryListLive do
  @moduledoc """
  LiveView for displaying inventory levels at a specific location.
  Shows all products with their current quantities and provides filtering/sorting capabilities.
  """

  use MedishopWeb, :live_view

  alias Medishop.{Inventory, Organizations}

  @impl true
  def mount(%{"location_id" => location_id}, _session, socket) do
    # Check if user is authenticated
    if socket.assigns[:current_user] do
      # Verify location exists and user has access
      case Organizations.get_location(location_id) do
        {:ok, location} ->
          # Load inventory for this location
          {:ok, inventory_items} =
            Inventory.get_inventory_by_location(%{location_id: location.id})

          # Load current quantities and products for each inventory item
          inventory_items =
            Enum.map(inventory_items, fn item ->
              {:ok, item_with_quantity} = Ash.load(item, [:current_quantity, :product])
              item_with_quantity
            end)

          socket =
            socket
            |> assign(:location, location)
            |> assign(:inventory_items, inventory_items)
            |> assign(:search_query, "")
            |> assign(:sort_by, :product_title)
            |> assign(:sort_order, :asc)
            |> assign(:page_title, "Inventory - #{location.name}")

          {:ok, socket}

        {:error, _} ->
          socket =
            socket
            |> put_flash(:error, "Location not found")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}
      end
    else
      # Redirect unauthenticated users to sign-in
      {:ok, socket |> redirect(to: ~p"/sign-in")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("sort", %{"by" => sort_by_string}, socket) do
    sort_by = String.to_existing_atom(sort_by_string)
    current_sort_by = socket.assigns.sort_by

    # Toggle sort order if clicking the same column
    sort_order =
      if current_sort_by == sort_by do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :filtered_items, filter_and_sort_items(assigns))

    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-4xl font-bold text-gray-900 dark:text-white">
                Inventory
              </h1>
              <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
                <%= @location.name %>
              </p>
            </div>
            <div class="flex gap-4">
              <.link
                navigate={~p"/dashboard"}
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                ← Back to Dashboard
              </.link>
            </div>
          </div>
        </div>

        <!-- Search Bar -->
        <div class="mb-6">
          <form phx-change="search" class="max-w-xl">
            <label for="search" class="sr-only">Search products</label>
            <input
              type="text"
              name="search"
              id="search"
              value={@search_query}
              placeholder="Search by product name or SKU..."
              class="block w-full rounded-lg border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:border-blue-500 focus:ring-blue-500"
            />
          </form>
        </div>

        <!-- Inventory Table -->
        <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
                  phx-click="sort"
                  phx-value-by="product_title"
                >
                  <div class="flex items-center gap-2">
                    Product
                    <%= if @sort_by == :product_title do %>
                      <span class="text-blue-600"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                    <% end %>
                  </div>
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
                >
                  SKU
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
                  phx-click="sort"
                  phx-value-by="quantity"
                >
                  <div class="flex items-center gap-2">
                    Current Quantity
                    <%= if @sort_by == :quantity do %>
                      <span class="text-blue-600"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                    <% end %>
                  </div>
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
                >
                  Status
                </th>
                <th scope="col" class="relative px-6 py-3">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <%= if Enum.empty?(@filtered_items) do %>
                <tr>
                  <td colspan="5" class="px-6 py-12 text-center">
                    <div class="text-gray-500 dark:text-gray-400">
                      <%= if @search_query != "" do %>
                        <p class="text-lg font-medium">No products found</p>
                        <p class="mt-1 text-sm">Try adjusting your search query</p>
                      <% else %>
                        <p class="text-lg font-medium">No inventory items</p>
                        <p class="mt-1 text-sm">Products will appear here once they have been added to inventory</p>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for item <- @filtered_items do %>
                  <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900 dark:text-white">
                        <%= item.product.title %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        <%= item.product.sku %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-semibold text-gray-900 dark:text-white">
                        <%= item.current_quantity %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= stock_status_badge(item.current_quantity) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <.link
                        navigate={~p"/location/#{@location.id}/inventory/#{item.product.id}"}
                        class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300"
                      >
                        View Details →
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

  # Private helpers

  defp filter_and_sort_items(assigns) do
    items = assigns.inventory_items
    query = String.downcase(assigns.search_query)

    # Filter by search query
    items =
      if query != "" do
        Enum.filter(items, fn item ->
          title_match = String.contains?(String.downcase(item.product.title), query)
          sku_match = String.contains?(String.downcase(item.product.sku), query)
          title_match or sku_match
        end)
      else
        items
      end

    # Sort items
    items =
      case assigns.sort_by do
        :product_title ->
          Enum.sort_by(items, fn item -> item.product.title end, assigns.sort_order)

        :quantity ->
          Enum.sort_by(items, fn item -> item.current_quantity end, assigns.sort_order)
      end

    items
  end

  defp stock_status_badge(quantity) when quantity == 0 do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300">
      Out of Stock
    </span>
    """
  end

  defp stock_status_badge(quantity) when quantity > 0 and quantity < 10 do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300">
      Low Stock
    </span>
    """
  end

  defp stock_status_badge(_quantity) do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300">
      In Stock
    </span>
    """
  end
end
