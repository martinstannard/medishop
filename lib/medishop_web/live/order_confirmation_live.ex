defmodule MedishopWeb.OrderConfirmationLive do
  use MedishopWeb, :live_view

  alias Medishop.Shop

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"order_id" => order_id}, _session, socket) do
    user = socket.assigns.current_user

    case Shop.get_order(order_id, load: [:location, order_items: :product]) do
      {:ok, order} ->
        # Verify user owns this order
        if order.user_id == user.id do
          socket =
            socket
            |> assign(:order, order)
            |> assign(:page_title, "Order Confirmation ##{order.order_number}")

          {:ok, socket}
        else
          socket =
            socket
            |> put_flash(:error, "You don't have permission to view this order")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}
        end

      {:error, _error} ->
        socket =
          socket
          |> put_flash(:error, "Order not found")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-16 h-16 bg-success/20 text-success rounded-full mb-4">
          <.icon name="hero-check-circle" class="w-10 h-10" />
        </div>
        <h1 class="text-3xl font-bold text-base-content mb-2">Order Confirmed!</h1>
        <p class="text-lg text-base-content/80">
          Thank you for your order. Your order number is
          <span class="font-bold text-primary">#{@order.order_number}</span>
        </p>
      </div>

      <div class="bg-base-100 rounded-lg shadow-lg border border-base-300 p-6 mb-6">
        <h2 class="text-xl font-bold text-base-content mb-4">Order Details</h2>

        <div class="grid md:grid-cols-2 gap-4 mb-6">
          <div>
            <div class="text-sm text-base-content/60 mb-1">Delivery Location</div>
            <div class="font-semibold text-base-content">{@order.location.name}</div>
            <div class="text-sm text-base-content/80 mt-1">
              {format_address(@order.location.address)}
            </div>
          </div>

          <div>
            <div class="text-sm text-base-content/60 mb-1">Order Status</div>
            <div class={["badge badge-lg", status_badge_class(@order.status)]}>
              {Phoenix.Naming.humanize(@order.status)}
            </div>
          </div>

          <div>
            <div class="text-sm text-base-content/60 mb-1">Order Date</div>
            <div class="font-semibold text-base-content">
              {format_datetime(@order.placed_at)}
            </div>
          </div>

          <div>
            <div class="text-sm text-base-content/60 mb-1">Order Total</div>
            <div class="text-2xl font-bold text-primary">
              ${Decimal.to_string(@order.total, :normal)}
            </div>
          </div>
        </div>

        <%= if @order.notes do %>
          <div class="mb-6">
            <div class="text-sm text-base-content/60 mb-1">Notes</div>
            <div class="text-base-content">{@order.notes}</div>
          </div>
        <% end %>

        <div class="divider">Items Ordered</div>

        <div class="overflow-x-auto">
          <table class="table" data-testid="order-items-table">
            <thead>
              <tr>
                <th>Product</th>
                <th class="text-right">Price</th>
                <th class="text-center">Quantity</th>
                <th class="text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @order.order_items} data-testid={"order-item-#{item.id}"}>
                <td>
                  <%= if item.product do %>
                    <div class="font-semibold">{item.product.title}</div>
                    <div class="text-sm opacity-60">{item.product.sku}</div>
                  <% else %>
                    <div class="font-semibold text-primary">{item.description}</div>
                  <% end %>
                </td>
                <td class="text-right">${Decimal.to_string(item.unit_price, :normal)}</td>
                <td class="text-center">{item.quantity}</td>
                <td class="text-right font-semibold">
                  ${Decimal.to_string(item.line_total, :normal)}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3" class="text-right font-bold">Subtotal:</td>
                <td class="text-right font-bold">
                  ${Decimal.to_string(@order.subtotal, :normal)}
                </td>
              </tr>
              <tr>
                <td colspan="3" class="text-right font-bold text-lg">Total:</td>
                <td class="text-right font-bold text-lg text-primary">
                  ${Decimal.to_string(@order.total, :normal)}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div class="flex items-center justify-between">
        <.link navigate={~p"/location/#{@order.location_id}/products"} class="btn btn-ghost gap-2">
          <.icon name="hero-arrow-left" class="w-5 h-5" /> Continue Shopping
        </.link>

        <.link navigate={~p"/dashboard"} class="btn btn-primary gap-2">
          <.icon name="hero-home" class="w-5 h-5" /> Back to Dashboard
        </.link>
      </div>
    </div>
    """
  end

  # Private functions

  defp format_address(address) do
    "#{address["street"]}, #{address["city"]}, #{address["state"]} #{address["zip"]}"
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp status_badge_class(status) do
    case status do
      "pending" -> "badge-warning"
      "confirmed" -> "badge-info"
      "shipped" -> "badge-primary"
      "delivered" -> "badge-success"
      "cancelled" -> "badge-error"
      _ -> "badge-ghost"
    end
  end
end
