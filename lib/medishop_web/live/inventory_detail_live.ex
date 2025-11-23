defmodule MedishopWeb.InventoryDetailLive do
  @moduledoc """
  LiveView for displaying detailed inventory information for a specific product at a location.
  Shows the event log and provides actions for recording new inventory events.
  """

  use MedishopWeb, :live_view

  alias Medishop.{Inventory, Organizations, Products}

  @impl true
  def mount(%{"location_id" => location_id, "product_id" => product_id}, _session, socket) do
    # Check if user is authenticated
    if socket.assigns[:current_user] do
      # Verify location exists and user has access
      case Organizations.get_location(location_id) do
        {:ok, location} ->
          # Get product
          case Products.get_product(product_id) do
            {:ok, product} ->
              # Get or create location inventory
              {:ok, inventory} =
                case Inventory.get_inventory_by_location(%{location_id: location.id}) do
                  {:ok, inventories} ->
                    case Enum.find(inventories, fn inv -> inv.product_id == product.id end) do
                      nil ->
                        # Create if doesn't exist
                        Inventory.create_location_inventory(%{
                          location_id: location.id,
                          product_id: product.id
                        })

                      inventory ->
                        {:ok, inventory}
                    end

                  {:error, _} ->
                    # Create if doesn't exist
                    Inventory.create_location_inventory(%{
                      location_id: location.id,
                      product_id: product.id
                    })
                end

              # Load current quantity
              {:ok, inventory} = Ash.load(inventory, :current_quantity)

              # Get all events for this product at this location
              {:ok, events} =
                Inventory.get_events_by_location_and_product(%{
                  location_id: location.id,
                  product_id: product.id
                })

              socket =
                socket
                |> assign(:location, location)
                |> assign(:product, product)
                |> assign(:inventory, inventory)
                |> assign(:all_events, events)
                |> assign(:event_type_filter, :all)
                |> assign(:sort_by, :occurred_at)
                |> assign(:sort_order, :desc)
                |> assign(:page_title, "#{product.title} - Inventory")

              {:ok, socket}

            {:error, _} ->
              socket =
                socket
                |> put_flash(:error, "Product not found")
                |> redirect(to: ~p"/location/#{location_id}/inventory")

              {:ok, socket}
          end

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
  def handle_event("filter_event_type", %{"event_type" => event_type}, socket) do
    event_type_atom =
      case event_type do
        "all" -> :all
        "purchase_received" -> :purchase_received
        "administered" -> :administered
        "expired" -> :expired
        "disposed" -> :disposed
        "adjustment" -> :adjustment
        _ -> :all
      end

    {:noreply, assign(socket, :event_type_filter, event_type_atom)}
  end

  def handle_event("sort", %{"by" => sort_by_string}, socket) do
    sort_by = String.to_existing_atom(sort_by_string)
    current_sort_by = socket.assigns.sort_by

    # Toggle sort order if clicking the same column
    sort_order =
      if current_sort_by == sort_by do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        :desc
      end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :filtered_events, filter_and_sort_events(assigns))

    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <%!-- Header --%>
      <div id="inventory-detail-header" class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 id="product-title" class="text-4xl font-bold text-gray-900 dark:text-white">
              {@product.title}
            </h1>
            <p class="mt-2 text-lg text-gray-600 dark:text-gray-300">
              SKU: <span id="product-sku">{@product.sku}</span> • <span id="location-name">{@location.name}</span>
            </p>
          </div>
          <div class="flex gap-4">
            <.link
              navigate={~p"/location/#{@location.id}/inventory"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white dark:bg-gray-800 dark:text-gray-200 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              ← Back to Inventory
            </.link>
          </div>
        </div>
      </div>
      <%!-- Current Quantity Card --%>
      <div class="mb-6 bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 border border-gray-200 dark:border-gray-700">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Current Quantity</p>
            <p id="current-quantity" class="mt-2 text-5xl font-bold text-gray-900 dark:text-white">
              {@inventory.current_quantity}
            </p>
          </div>
          <div>
            <%= stock_status_badge(@inventory.current_quantity) %>
          </div>
        </div>
      </div>
      <%!-- Event Type Filter --%>
      <div class="mb-6">
        <div class="flex gap-2 flex-wrap">
          <button
            id="filter-all"
            phx-click="filter_event_type"
            phx-value-event_type="all"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :all,
                do: "bg-blue-600 text-white dark:bg-blue-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            All Events
          </button>
          <button
            id="filter-purchase_received"
            phx-click="filter_event_type"
            phx-value-event_type="purchase_received"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :purchase_received,
                do: "bg-green-600 text-white dark:bg-green-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            Purchases
          </button>
          <button
            id="filter-administered"
            phx-click="filter_event_type"
            phx-value-event_type="administered"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :administered,
                do: "bg-blue-600 text-white dark:bg-blue-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            Administered
          </button>
          <button
            id="filter-expired"
            phx-click="filter_event_type"
            phx-value-event_type="expired"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :expired,
                do: "bg-yellow-600 text-white dark:bg-yellow-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            Expired
          </button>
          <button
            id="filter-disposed"
            phx-click="filter_event_type"
            phx-value-event_type="disposed"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :disposed,
                do: "bg-red-600 text-white dark:bg-red-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            Disposed
          </button>
          <button
            id="filter-adjustment"
            phx-click="filter_event_type"
            phx-value-event_type="adjustment"
            class={[
              "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
              if(@event_type_filter == :adjustment,
                do: "bg-purple-600 text-white dark:bg-purple-500",
                else:
                  "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
              )
            ]}
          >
            Adjustments
          </button>
        </div>
      </div>
      <%!-- Event Log Table --%>
      <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg overflow-hidden">
        <table id="event-log-table" class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead class="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th
                id="sort-occurred_at"
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
                phx-click="sort"
                phx-value-by="occurred_at"
              >
                <div class="flex items-center gap-2">
                  Date/Time
                  <%= if @sort_by == :occurred_at do %>
                    <span class="text-blue-600"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                  <% end %>
                </div>
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Type
              </th>
              <th
                id="sort-quantity_change"
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
                phx-click="sort"
                phx-value-by="quantity_change"
              >
                <div class="flex items-center gap-2">
                  Quantity
                  <%= if @sort_by == :quantity_change do %>
                    <span class="text-blue-600"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                  <% end %>
                </div>
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Reference
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Reason
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
            <%= if Enum.empty?(@filtered_events) do %>
              <tr>
                <td colspan="5" class="px-6 py-12 text-center">
                  <div class="text-gray-500 dark:text-gray-400">
                    <%= if @event_type_filter != :all do %>
                      <p id="no-filtered-events-message" class="text-lg font-medium">No <%= String.replace("#{@event_type_filter}", "_", " ") %> events found</p>
                      <p class="mt-1 text-sm">Try selecting a different filter</p>
                    <% else %>
                      <p id="no-events-message" class="text-lg font-medium">No inventory events found</p>
                      <p class="mt-1 text-sm">
                        Events will appear here when inventory is received or used
                      </p>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% else %>
              <%= for event <- @filtered_events do %>
                <tr id={"event-#{event.id}"} data-quantity-change={event.quantity_change} class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm text-gray-900 dark:text-white">
                      {Calendar.strftime(event.occurred_at, "%b %d, %Y")}
                    </div>
                    <div class="text-xs text-gray-500 dark:text-gray-400">
                      {Calendar.strftime(event.occurred_at, "%I:%M %p")}
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= event_type_badge(event.event_type) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class={[
                      "text-sm font-semibold",
                      if(event.quantity_change > 0,
                        do: "text-green-600 dark:text-green-400",
                        else: "text-red-600 dark:text-red-400"
                      )
                    ]}>
                      <%= if event.quantity_change > 0, do: "+", else: "" %>{event.quantity_change}
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if event.reference_type do %>
                      <div class="text-sm text-gray-900 dark:text-white">
                        {event.reference_type}
                      </div>
                    <% else %>
                      <span class="text-sm text-gray-400 dark:text-gray-500">—</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4">
                    <%= if event.reason do %>
                      <div class="event-reason text-sm text-gray-600 dark:text-gray-300 max-w-xs truncate">
                        {event.reason}
                      </div>
                    <% else %>
                      <span class="text-sm text-gray-400 dark:text-gray-500">—</span>
                    <% end %>
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

  defp filter_and_sort_events(assigns) do
    events = assigns.all_events
    event_type_filter = assigns.event_type_filter

    # Filter by event type
    events =
      if event_type_filter != :all do
        Enum.filter(events, &(&1.event_type == event_type_filter))
      else
        events
      end

    # Sort events
    events =
      case assigns.sort_by do
        :occurred_at ->
          Enum.sort_by(events, & &1.occurred_at, assigns.sort_order)

        :quantity_change ->
          Enum.sort_by(events, & &1.quantity_change, assigns.sort_order)
      end

    events
  end

  defp stock_status_badge(quantity) when quantity == 0 do
    assigns = %{}

    ~H"""
    <span id="stock-status" class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300">
      Out of Stock
    </span>
    """
  end

  defp stock_status_badge(quantity) when quantity > 0 and quantity < 10 do
    assigns = %{}

    ~H"""
    <span id="stock-status" class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300">
      Low Stock
    </span>
    """
  end

  defp stock_status_badge(_quantity) do
    assigns = %{}

    ~H"""
    <span id="stock-status" class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300">
      In Stock
    </span>
    """
  end

  defp event_type_badge(:purchase_received) do
    assigns = %{}

    ~H"""
    <span class="event-type-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300">
      Purchase Received
    </span>
    """
  end

  defp event_type_badge(:administered) do
    assigns = %{}

    ~H"""
    <span class="event-type-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300">
      Administered
    </span>
    """
  end

  defp event_type_badge(:expired) do
    assigns = %{}

    ~H"""
    <span class="event-type-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300">
      Expired
    </span>
    """
  end

  defp event_type_badge(:disposed) do
    assigns = %{}

    ~H"""
    <span class="event-type-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300">
      Disposed
    </span>
    """
  end

  defp event_type_badge(:adjustment) do
    assigns = %{}

    ~H"""
    <span class="event-type-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300">
      Adjustment
    </span>
    """
  end
end
