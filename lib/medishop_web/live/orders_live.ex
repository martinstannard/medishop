defmodule MedishopWeb.OrdersLive do
  use MedishopWeb, :live_view

  alias Medishop.Organizations
  alias Medishop.Shop

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"location_id" => location_id}, _session, socket) do
    user = socket.assigns.current_user

    # Verify user has access to this location
    case verify_location_access(user.id, location_id) do
      {:ok, location} ->
        # Get all orders for this location
        {:ok, all_orders} =
          Shop.get_orders_for_location(location_id, load: [:user, order_items: [:product]])

        # Sort orders by placed_at descending (newest first)
        all_orders = Enum.sort_by(all_orders, & &1.placed_at, {:desc, DateTime})

        socket =
          socket
          |> assign(:location, location)
          |> assign(:all_orders, all_orders)
          |> assign(:filtered_orders, all_orders)
          |> assign(:status_filter, :all)
          |> assign(:search_query, "")
          |> assign(:page_title, "Orders - #{location.name}")

        {:ok, socket}

      {:error, :unauthorized} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to view orders for this location")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}
    end
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "pending" -> :pending
        "confirmed" -> :confirmed
        "shipped" -> :shipped
        "delivered" -> :delivered
        "cancelled" -> :cancelled
        _ -> :all
      end

    socket =
      socket
      |> assign(:status_filter, status_atom)
      |> apply_filters()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> apply_filters()

    {:noreply, socket}
  end

  def handle_event("update_status", %{"order-id" => order_id, "new-status" => new_status}, socket) do
    user = socket.assigns.current_user

    # Get the order
    case Shop.get_order(order_id, load: [:user, order_items: [:product]], actor: user) do
      {:ok, order} ->
        new_status_atom = String.to_existing_atom(new_status)

        # Update the order status
        case Shop.update_order_status(order, new_status_atom, actor: user) do
          {:ok, _updated_order} ->
            # Reload all orders with updated data
            {:ok, all_orders} =
              Shop.get_orders_for_location(socket.assigns.location.id, load: [:user, order_items: [:product]], actor: user)

            all_orders = Enum.sort_by(all_orders, & &1.placed_at, {:desc, DateTime})

            flash_message = case new_status_atom do
              :confirmed -> "Order confirmed successfully"
              :shipped -> "Order marked as shipped"
              :delivered -> "Order delivered! Inventory has been updated."
              :cancelled -> "Order cancelled"
              _ -> "Order status updated"
            end

            socket =
              socket
              |> assign(:all_orders, all_orders)
              |> apply_filters()
              |> put_flash(:info, flash_message)

            {:noreply, socket}

          {:error, error} ->
            error_message = case error do
              %{errors: errors} when is_list(errors) ->
                errors
                |> Enum.map(fn e -> e.message || "Unknown error" end)
                |> Enum.join(", ")
              _ ->
                "Failed to update order status"
            end

            {:noreply, put_flash(socket, :error, error_message)}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Order not found")}
    end
  end

  defp apply_filters(socket) do
    orders = socket.assigns.all_orders
    status_filter = socket.assigns.status_filter
    search_query = String.downcase(socket.assigns.search_query)

    filtered =
      orders
      |> filter_by_status(status_filter)
      |> filter_by_search(search_query)

    assign(socket, :filtered_orders, filtered)
  end

  defp filter_by_status(orders, :all), do: orders

  defp filter_by_status(orders, status) do
    Enum.filter(orders, &(&1.status == status))
  end

  defp filter_by_search(orders, ""), do: orders

  defp filter_by_search(orders, query) do
    Enum.filter(orders, fn order ->
      String.contains?(String.downcase(order.order_number), query)
    end)
  end

  defp verify_location_access(user_id, location_id) do
    # Get user's memberships with location access
    {:ok, memberships} = Organizations.get_memberships_for_user(user_id)

    # Check if user has access to this location
    has_access? =
      Enum.any?(memberships, fn membership ->
        Enum.any?(membership.organization_location_memberships, fn loc_membership ->
          loc_membership.location_id == location_id
        end)
      end)

    if has_access? do
      case Organizations.get_location(location_id) do
        {:ok, location} -> {:ok, location}
        _ -> {:error, :not_found}
      end
    else
      {:error, :unauthorized}
    end
  end

  defp next_status_options(current_status) do
    case current_status do
      :pending -> [:confirmed, :cancelled]
      :confirmed -> [:shipped, :cancelled]
      :shipped -> [:delivered]
      _ -> []
    end
  end

  defp status_button_class(:confirmed), do: "btn-primary"
  defp status_button_class(:shipped), do: "btn-secondary"
  defp status_button_class(:delivered), do: "btn-success"
  defp status_button_class(:cancelled), do: "btn-error"
  defp status_button_class(_), do: "btn-secondary"

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-10 px-6">
      <div class="mb-10">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-5xl font-bold text-gray-900 dark:text-white">Orders</h1>
            <p class="text-gray-700 dark:text-gray-200 mt-3 text-xl">
              {@location.name}
            </p>
          </div>
          <.link navigate={~p"/dashboard"} class="btn btn-secondary">
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Dashboard
          </.link>
        </div>
      </div>
      <%!-- Filters and Search --%>
      <div class="mb-6 bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-200 dark:border-gray-600">
        <div class="flex flex-col md:flex-row gap-4">
          <%!-- Search Bar --%>
          <div class="flex-1">
            <form phx-submit="search" phx-change="search">
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Search by order number..."
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </form>
          </div>
          <%!-- Status Filter --%>
          <div class="flex gap-2 flex-wrap">
            <button
              phx-click="filter_status"
              phx-value-status="all"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :all,
                  do: "bg-blue-600 text-white dark:bg-blue-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              All
            </button>
            <button
              phx-click="filter_status"
              phx-value-status="pending"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :pending,
                  do: "bg-yellow-600 text-white dark:bg-yellow-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              Pending
            </button>
            <button
              phx-click="filter_status"
              phx-value-status="confirmed"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :confirmed,
                  do: "bg-blue-600 text-white dark:bg-blue-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              Confirmed
            </button>
            <button
              phx-click="filter_status"
              phx-value-status="shipped"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :shipped,
                  do: "bg-purple-600 text-white dark:bg-purple-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              Shipped
            </button>
            <button
              phx-click="filter_status"
              phx-value-status="delivered"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :delivered,
                  do: "bg-green-600 text-white dark:bg-green-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              Delivered
            </button>
            <button
              phx-click="filter_status"
              phx-value-status="cancelled"
              class={[
                "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                if(@status_filter == :cancelled,
                  do: "bg-red-600 text-white dark:bg-red-500",
                  else:
                    "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                )
              ]}
            >
              Cancelled
            </button>
          </div>
        </div>
      </div>

      <%= if Enum.empty?(@filtered_orders) do %>
        <div class="bg-white dark:bg-gray-800 rounded-2xl p-10 text-center border border-gray-200 dark:border-gray-600">
          <.icon
            name="hero-document-text"
            class="w-16 h-16 mx-auto text-gray-400 dark:text-gray-500 mb-4"
          />
          <p class="text-lg text-gray-700 dark:text-gray-200 mb-2">No orders yet</p>
          <p class="text-gray-600 dark:text-gray-400">
            Orders placed for this location will appear here.
          </p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for order <- @filtered_orders do %>
            <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-lg border border-gray-200 dark:border-gray-600 overflow-hidden hover:shadow-xl transition-shadow">
              <div class="p-6">
                <div class="flex items-start justify-between mb-4">
                  <div class="flex-1">
                    <div class="flex items-center gap-3 mb-2">
                      <h3 class="text-2xl font-bold text-gray-900 dark:text-white">
                        Order #{order.order_number}
                      </h3>
                      <span class={[
                        "inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold",
                        case order.status do
                          :pending ->
                            "bg-yellow-100 text-yellow-900 dark:bg-yellow-900/50 dark:text-yellow-100"

                          :confirmed ->
                            "bg-blue-100 text-blue-900 dark:bg-blue-900/50 dark:text-blue-100"

                          :shipped ->
                            "bg-purple-100 text-purple-900 dark:bg-purple-900/50 dark:text-purple-100"

                          :delivered ->
                            "bg-green-100 text-green-900 dark:bg-green-900/50 dark:text-green-100"

                          :cancelled ->
                            "bg-red-100 text-red-900 dark:bg-red-900/50 dark:text-red-100"
                        end
                      ]}>
                        {Phoenix.Naming.humanize(order.status)}
                      </span>
                    </div>
                    <p class="text-gray-600 dark:text-gray-400 text-sm">
                      Placed on {Calendar.strftime(order.placed_at, "%B %d, %Y at %I:%M %p")}
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm text-gray-600 dark:text-gray-400">Total</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                      ${Decimal.to_string(order.total, :normal)}
                    </p>
                  </div>
                </div>

                <div class="border-t border-gray-200 dark:border-gray-600 pt-4 mt-4">
                  <h4 class="font-semibold text-gray-800 dark:text-gray-200 mb-3">Items</h4>
                  <div class="space-y-2">
                    <%= for item <- order.order_items do %>
                      <div class="flex justify-between text-sm">
                        <span class="text-gray-700 dark:text-gray-300">
                          <%= if item.product do %>
                            {item.quantity}× {item.product.title}
                          <% else %>
                            {item.quantity}× {item.description}
                          <% end %>
                        </span>
                        <span class="font-medium text-gray-900 dark:text-white">
                          ${Decimal.to_string(item.line_total, :normal)}
                        </span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="flex flex-wrap gap-3 mt-6">
                  <.link
                    navigate={~p"/orders/#{order.id}/confirmation"}
                    class="btn btn-sm btn-primary"
                  >
                    <.icon name="hero-eye" class="w-4 h-4" /> View Details
                  </.link>
                  <a
                    href={~p"/orders/#{order.id}/pdf"}
                    class="btn btn-sm btn-secondary"
                    target="_blank"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Download PDF
                  </a>

                  <%!-- Status transition buttons --%>
                  <%= for next_status <- next_status_options(order.status) do %>
                    <button
                      phx-click="update_status"
                      phx-value-order-id={order.id}
                      phx-value-new-status={next_status}
                      class={["btn btn-sm", status_button_class(next_status)]}
                      data-confirm={
                        if next_status == :cancelled,
                          do: "Are you sure you want to cancel this order?",
                          else: nil
                      }
                    >
                      <%= case next_status do %>
                        <% :confirmed -> %>
                          <.icon name="hero-check-circle" class="w-4 h-4" /> Confirm Order
                        <% :shipped -> %>
                          <.icon name="hero-truck" class="w-4 h-4" /> Mark as Shipped
                        <% :delivered -> %>
                          <.icon name="hero-check-badge" class="w-4 h-4" /> Mark as Delivered
                        <% :cancelled -> %>
                          <.icon name="hero-x-circle" class="w-4 h-4" /> Cancel Order
                      <% end %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
