defmodule MedishopWeb.CartLive do
  use MedishopWeb, :live_view

  alias Medishop.Shop
  alias Medishop.Organizations

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"location_id" => location_id}, _session, socket) do
    user = socket.assigns.current_user

    # Verify user has org_buyer role for this location's organization
    case verify_buyer_access(user.id, location_id) do
      {:ok, location} ->
        # Get or create cart for this location
        {:ok, cart} = Shop.get_or_create_cart_for_location(location_id)

        # Load cart with items and product details preloaded
        {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [cart_items: :product])

        socket =
          socket
          |> assign(:location, location)
          |> assign(:cart, cart_with_items)
          |> stream(:cart_items, cart_with_items.cart_items || [], dom_id: &"cart-item-#{&1.id}")
          |> assign(:page_title, "Shopping Cart - #{location.name}")

        {:ok, socket}

      {:error, :unauthorized} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to access this cart")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}
    end
  end

  def handle_event("update_quantity", %{"item_id" => item_id, "quantity" => quantity_str}, socket) do
    quantity = String.to_integer(quantity_str)

    # First fetch the cart item, then update it
    case Shop.get_cart_item(item_id) do
      {:ok, cart_item} ->
        case Shop.update_cart_item(cart_item, %{quantity: quantity}) do
          {:ok, updated_item} ->
            # Reload with product relationship
            {:ok, item_with_product} = Shop.get_cart_item(updated_item.id, load: [:product])
            {:noreply, stream_insert(socket, :cart_items, item_with_product)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to update quantity")}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Cart item not found")}
    end
  end

  def handle_event("remove_item", %{"item_id" => item_id}, socket) do
    # First fetch the cart item to get the struct
    case Shop.get_cart_item(item_id) do
      {:ok, cart_item} ->
        case Shop.remove_cart_item(cart_item) do
          :ok ->
            socket =
              socket
              |> stream_delete(:cart_items, cart_item)
              |> put_flash(:info, "Item removed from cart")

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to remove item")}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Cart item not found")}
    end
  end

  def handle_event("clear_cart", _params, socket) do
    cart = socket.assigns.cart

    case Shop.clear_cart(cart) do
      {:ok, _cleared_cart} ->
        socket =
          socket
          |> stream(:cart_items, [], reset: true)
          |> put_flash(:info, "Cart cleared successfully")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to clear cart")}
    end
  end

  def handle_event("place_order", _params, socket) do
    user = socket.assigns.current_user
    cart = socket.assigns.cart

    case Shop.create_order_from_cart(cart.id, user.id) do
      {:ok, order} ->
        socket =
          socket
          |> put_flash(:info, "Order placed successfully! Order ##{order.order_number}")
          |> redirect(to: ~p"/orders/#{order.id}/confirmation")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to place order")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-base-content">Shopping Cart</h1>
          <p class="text-base-content mt-2">
            <span class="font-semibold">{@location.name}</span>
          </p>
        </div>
        <.link navigate={~p"/dashboard"} class="btn btn-ghost gap-2">
          <.icon name="hero-arrow-left" class="w-5 h-5" />
          Back to Dashboard
        </.link>
      </div>

      <%= if Enum.empty?(@cart.cart_items || []) do %>
        <div class="bg-base-200 rounded-lg p-12 text-center">
          <.icon name="hero-shopping-cart" class="w-16 h-16 mx-auto mb-4 text-base-300" />
          <h2 class="text-2xl font-bold text-base-content mb-2">Your cart is empty</h2>
          <p class="text-base-content mb-6">Add some products to get started!</p>
          <.link
            navigate={~p"/location/#{@location.id}/products"}
            class="btn btn-primary gap-2"
          >
            <.icon name="hero-magnifying-glass" class="w-5 h-5" />
            Browse Products
          </.link>
        </div>
      <% else %>
        <div class="grid gap-6">
          <div class="bg-base-100 rounded-lg shadow-lg border border-base-300">
            <div class="overflow-x-auto">
              <table class="table" data-testid="cart-items-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th class="text-right">Price</th>
                    <th class="text-center">Quantity</th>
                    <th class="text-right">Total</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody id="cart-items" phx-update="stream">
                  <tr
                    :for={{dom_id, cart_item} <- @streams.cart_items}
                    id={dom_id}
                    data-testid={"cart-item-#{cart_item.id}"}
                  >
                    <td>
                      <div class="font-semibold">{cart_item.product.title}</div>
                      <div class="text-sm opacity-60">{cart_item.product.sku}</div>
                    </td>
                    <td class="text-right">${cart_item.price_at_addition}</td>
                    <td>
                      <div class="flex items-center justify-center gap-2">
                        <button
                          type="button"
                          class="btn btn-xs btn-circle"
                          phx-click="update_quantity"
                          phx-value-item_id={cart_item.id}
                          phx-value-quantity={cart_item.quantity - 1}
                          disabled={cart_item.quantity <= 1}
                        >
                          -
                        </button>
                        <span class="font-semibold w-8 text-center">{cart_item.quantity}</span>
                        <button
                          type="button"
                          class="btn btn-xs btn-circle"
                          phx-click="update_quantity"
                          phx-value-item_id={cart_item.id}
                          phx-value-quantity={cart_item.quantity + 1}
                        >
                          +
                        </button>
                      </div>
                    </td>
                    <td class="text-right font-semibold">${cart_item.line_total}</td>
                    <td>
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm text-error"
                        phx-click="remove_item"
                        phx-value-item_id={cart_item.id}
                        data-testid={"remove-item-#{cart_item.id}"}
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <button
              type="button"
              class="btn btn-ghost btn-sm gap-2"
              phx-click="clear_cart"
              data-confirm="Are you sure you want to clear your cart?"
              data-testid="clear-cart-button"
            >
              <.icon name="hero-trash" class="w-4 h-4" />
              Clear Cart
            </button>

            <div class="flex items-center gap-4">
              <.link
                navigate={~p"/location/#{@location.id}/products"}
                class="btn btn-ghost gap-2"
              >
                <.icon name="hero-magnifying-glass" class="w-5 h-5" />
                Browse Products
              </.link>

              <div class="text-right">
                <div class="text-sm text-base-content/60">Total</div>
                <div class="text-3xl font-bold text-primary">
                  ${calculate_total(@cart.cart_items || [])}
                </div>
              </div>

              <button
                type="button"
                class="btn btn-primary btn-lg gap-2"
                phx-click="place_order"
                data-testid="place-order-button"
              >
                <.icon name="hero-shopping-bag" class="w-5 h-5" />
                Place Order
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private functions

  defp verify_buyer_access(user_id, location_id) do
    # Get location with organization preloaded
    with {:ok, location} <- Organizations.get_location(location_id),
         {:ok, memberships} <- Organizations.get_memberships_for_user(user_id),
         true <- has_buyer_access?(memberships, location.organization_id) do
      {:ok, location}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp has_buyer_access?(memberships, organization_id) do
    Enum.any?(memberships, fn membership ->
      membership.organization_id == organization_id and :org_buyer in membership.org_roles
    end)
  end

  defp calculate_total(cart_items) do
    cart_items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.line_total)
    end)
    |> Decimal.to_string(:normal)
  end
end
