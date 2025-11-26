defmodule MedishopWeb.CartLive do
  use MedishopWeb, :live_view

  alias Medishop.Organizations
  alias Medishop.Shop

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"location_id" => location_id}, _session, socket) do
    user = socket.assigns.current_user

    # Verify user has org_buyer role for this location's organization
    case verify_buyer_access(user.id, location_id) do
      {:ok, location} ->
        # Get or create cart for this location
        {:ok, cart} = Shop.get_or_create_cart_for_location(location_id)

        # Load cart with items, product details, and voucher
        {:ok, cart_with_items} =
          Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total], voucher: []])

        # Calculate totals
        {:ok, totals} = Shop.calculate_cart_totals(cart_with_items)

        socket =
          socket
          |> assign(:location, location)
          |> assign(:cart, cart_with_items)
          |> assign(:totals, totals)
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

    case Shop.get_cart_item(item_id) do
      {:ok, cart_item} ->
        case Shop.update_cart_item(cart_item, %{quantity: quantity}) do
          {:ok, updated_item} ->
            {:ok, item_with_product} =
              Shop.get_cart_item(updated_item.id, load: [:product, :line_total])

            cart = refresh_cart(socket.assigns.cart.id)
            {:ok, totals} = Shop.calculate_cart_totals(cart)

            socket =
              socket
              |> assign(:cart, cart)
              |> assign(:totals, totals)
              |> stream_insert(:cart_items, item_with_product)

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to update quantity")}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Cart item not found")}
    end
  end

  def handle_event("remove_item", %{"item_id" => item_id}, socket) do
    case Shop.get_cart_item(item_id) do
      {:ok, cart_item} ->
        case Shop.remove_cart_item(cart_item) do
          :ok ->
            cart = refresh_cart(socket.assigns.cart.id)
            {:ok, totals} = Shop.calculate_cart_totals(cart)

            socket =
              socket
              |> assign(:cart, cart)
              |> assign(:totals, totals)
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
      {:ok, cleared_cart} ->
        cart = refresh_cart(cleared_cart.id)
        {:ok, totals} = Shop.calculate_cart_totals(cart)

        socket =
          socket
          |> assign(:cart, cart)
          |> assign(:totals, totals)
          |> stream(:cart_items, [], reset: true)
          |> put_flash(:info, "Cart cleared successfully")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to clear cart")}
    end
  end

  def handle_event("apply_voucher", %{"code" => code}, socket) do
    code = String.trim(code)
    cart = socket.assigns.cart
    user = socket.assigns.current_user

    if code == "" do
       {:noreply, put_flash(socket, :error, "Please enter a voucher code")}
    else
      case Shop.validate_voucher(code, cart, user) do
        {:ok, voucher} ->
          case Shop.update_cart(cart, %{voucher_id: voucher.id}) do
            {:ok, _updated_cart} ->
              # Refresh to get recalculated totals
              cart = refresh_cart(cart.id)
              {:ok, totals} = Shop.calculate_cart_totals(cart)

              socket =
                socket
                |> assign(:cart, cart)
                |> assign(:totals, totals)
                |> put_flash(:info, "Voucher '#{voucher.code}' applied!")

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to apply voucher")}
          end

        {:error, reason} ->
          msg = case reason do
            :not_found -> "Voucher not found"
            :inactive -> "Voucher is inactive"
            :not_started -> "Voucher promotion has not started yet"
            :expired -> "Voucher has expired"
            :not_eligible_location -> "Voucher is not valid for this location"
            :min_spend_not_met -> "Minimum spend requirement not met"
            :min_quantity_not_met -> "Minimum quantity requirement not met"
            :usage_limit_reached -> "Voucher usage limit reached"
            :location_usage_limit_reached -> "Voucher usage limit reached for this location"
            _ -> "Invalid voucher: #{inspect(reason)}"
          end
          {:noreply, put_flash(socket, :error, msg)}
      end
    end
  end

  def handle_event("remove_voucher", _params, socket) do
    cart = socket.assigns.cart
    
    # Update cart with voucher_id: nil
    # We must explicitly set it to nil. Ash might need special handling if it's not a nullable attribute but it is belongs_to allow_nil? true.
    
    case Shop.update_cart(cart, %{voucher_id: nil}) do
      {:ok, _updated_cart} ->
        cart = refresh_cart(cart.id)
        {:ok, totals} = Shop.calculate_cart_totals(cart)

        socket =
          socket
          |> assign(:cart, cart)
          |> assign(:totals, totals)
          |> put_flash(:info, "Voucher removed")

        {:noreply, socket}

      {:error, _} ->
         {:noreply, put_flash(socket, :error, "Failed to remove voucher")}
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
          <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Dashboard
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
            <.icon name="hero-magnifying-glass" class="w-5 h-5" /> Browse Products
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

          <div class="flex flex-col md:flex-row items-center justify-between gap-4">
            <button
              type="button"
              class="btn btn-ghost btn-sm gap-2"
              phx-click="clear_cart"
              data-confirm="Are you sure you want to clear your cart?"
              data-testid="clear-cart-button"
            >
              <.icon name="hero-trash" class="w-4 h-4" /> Clear Cart
            </button>

            <div class="flex flex-col items-end gap-4 w-full md:w-auto">
              <div class="flex items-center gap-2 w-full justify-end">
                <%= if @cart.voucher do %>
                  <div class="badge badge-success gap-2 p-3">
                    <span class="font-bold">{@cart.voucher.code}</span> Applied
                    <button phx-click="remove_voucher" class="btn btn-xs btn-circle btn-ghost">
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                <% else %>
                  <form phx-submit="apply_voucher" class="join">
                    <input
                      type="text"
                      name="code"
                      class="input input-bordered input-sm join-item w-32"
                      placeholder="Promo Code"
                    />
                    <button type="submit" class="btn btn-neutral btn-sm join-item">Apply</button>
                  </form>
                <% end %>
              </div>
            
              <.link
                navigate={~p"/location/#{@location.id}/products"}
                class="btn btn-ghost gap-2"
              >
                <.icon name="hero-magnifying-glass" class="w-5 h-5" /> Browse Products
              </.link>

              <div class="text-right space-y-1">
                <div class="flex justify-between gap-8 text-sm text-base-content/60">
                  <span>Subtotal</span>
                  <span>${Decimal.round(@totals.subtotal, 2) |> Decimal.to_string(:normal)}</span>
                </div>
                
                <%= if Decimal.compare(@totals.discount_total, Decimal.new(0)) == :gt do %>
                   <div class="flex justify-between gap-8 text-sm text-success font-semibold">
                    <span>Discount</span>
                    <span>-${Decimal.round(@totals.discount_total, 2) |> Decimal.to_string(:normal)}</span>
                  </div>
                <% end %>
                
                <div class="flex justify-between gap-8 text-3xl font-bold text-primary pt-2 border-t">
                  <span>Total</span>
                  <span>${Decimal.round(@totals.total, 2) |> Decimal.to_string(:normal)}</span>
                </div>
              </div>

              <button
                type="button"
                class="btn btn-primary btn-lg gap-2 w-full md:w-auto"
                phx-click="place_order"
                data-testid="place-order-button"
              >
                <.icon name="hero-shopping-bag" class="w-5 h-5" /> Place Order
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp refresh_cart(cart_id) do
    {:ok, cart} = Shop.get_cart(cart_id, load: [cart_items: [:product, :line_total], voucher: []])
    cart
  end

  # Private functions

  defp verify_buyer_access(user_id, location_id) do
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
end