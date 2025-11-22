defmodule MedishopWeb.OrdersLive do
  use MedishopWeb, :live_view

  alias Medishop.Shop
  alias Medishop.Organizations

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"location_id" => location_id}, _session, socket) do
    user = socket.assigns.current_user

    # Verify user has access to this location
    case verify_location_access(user.id, location_id) do
      {:ok, location} ->
        # Get all orders for this location
        {:ok, orders} =
          Shop.get_orders_for_location(location_id, load: [:user, order_items: [:product]])

        # Sort orders by placed_at descending (newest first)
        orders = Enum.sort_by(orders, & &1.placed_at, {:desc, DateTime})

        socket =
          socket
          |> assign(:location, location)
          |> assign(:orders, orders)
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
          <.link
            navigate={~p"/dashboard"}
            class="btn btn-secondary"
          >
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Dashboard
          </.link>
        </div>
      </div>

      <%= if Enum.empty?(@orders) do %>
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
          <%= for order <- @orders do %>
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
                          {item.quantity}× {item.product.title}
                        </span>
                        <span class="font-medium text-gray-900 dark:text-white">
                          ${Decimal.to_string(item.line_total, :normal)}
                        </span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="flex gap-3 mt-6">
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
