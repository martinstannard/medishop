defmodule MedishopWeb.ShopLive do
  use MedishopWeb, :live_view

  alias Medishop.Organizations
  alias Medishop.Products
  alias Medishop.Shop
  alias MedishopWeb.Helpers.ProductThumbnail

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(%{"location_id" => location_id}, _session, socket) do
    user = socket.assigns.current_user

    # Verify user has org_buyer role for this location's organization
    case verify_buyer_access(user.id, location_id) do
      {:ok, location} ->
        # Get or create cart for this location
        {:ok, cart} = Shop.get_or_create_cart_for_location(location_id)

        # Load cart with items, product details, and line_total calculation
        {:ok, cart_with_items} =
          Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total]])

        # Sort cart items by inserted_at to maintain consistent order
        sorted_cart_items = sort_cart_items(cart_with_items.cart_items || [])

        # Load active products
        {:ok, products} = Products.list_products()
        active_products = Enum.filter(products, & &1.active)

        socket =
          socket
          |> assign(:location, location)
          |> assign(:cart, cart_with_items)
          |> assign(:search_query, "")
          |> stream(:cart_items, sorted_cart_items, dom_id: &"cart-item-#{&1.id}")
          |> stream(:products, active_products, dom_id: &"product-#{&1.id}")
          |> assign(:page_title, "Shop - #{location.name}")

        {:ok, socket}

      {:error, :unauthorized} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to access this location")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}
    end
  end

  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    # Search products by title
    {:ok, products} =
      if query == "" do
        Products.list_products()
      else
        Products.search_products(%{title: query, active: true})
      end

    # Filter for active products only
    active_products = Enum.filter(products, & &1.active)

    socket =
      socket
      |> assign(:search_query, query)
      |> stream(:products, active_products, reset: true)

    {:noreply, socket}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    cart = socket.assigns.cart

    case Shop.add_or_update_cart_item(cart.id, product_id, 1) do
      {:ok, _cart_item} ->
        # Reload cart to get updated items
        {:ok, cart_with_items} =
          Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total]])

        sorted_cart_items = sort_cart_items(cart_with_items.cart_items || [])

        socket =
          socket
          |> assign(:cart, cart_with_items)
          |> stream(:cart_items, sorted_cart_items, reset: true)
          |> put_flash(:info, "Product added to cart!")

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to add product to cart")
        {:noreply, socket}
    end
  end

  def handle_event("update_quantity", %{"item_id" => item_id, "quantity" => quantity_str}, socket) do
    quantity = String.to_integer(quantity_str)

    case Shop.get_cart_item(item_id) do
      {:ok, cart_item} ->
        case Shop.update_cart_item(cart_item, %{quantity: quantity}) do
          {:ok, _updated_item} ->
            # Reload cart to get updated items and totals
            cart = socket.assigns.cart

            {:ok, cart_with_items} =
              Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total]])

            sorted_cart_items = sort_cart_items(cart_with_items.cart_items || [])

            socket =
              socket
              |> assign(:cart, cart_with_items)
              |> stream(:cart_items, sorted_cart_items, reset: true)

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
            # Reload cart to get updated items and totals
            cart = socket.assigns.cart

            {:ok, cart_with_items} =
              Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total]])

            sorted_cart_items = sort_cart_items(cart_with_items.cart_items || [])

            socket =
              socket
              |> assign(:cart, cart_with_items)
              |> stream(:cart_items, sorted_cart_items, reset: true)
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
        # Reload cart to get empty items list
        {:ok, cart_with_items} =
          Shop.get_cart(cart.id, load: [cart_items: [:product, :line_total]])

        socket =
          socket
          |> assign(:cart, cart_with_items)
          |> stream(:cart_items, [], reset: true)
          |> put_flash(:info, "Cart cleared successfully")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to clear cart")}
    end
  end

  def handle_event("place_order", _params, socket) do
    cart = socket.assigns.cart
    user = socket.assigns.current_user

    case Shop.create_order_from_cart(cart.id, user.id) do
      {:ok, order} ->
        socket =
          socket
          |> put_flash(:info, "Order placed successfully!")
          |> push_navigate(to: ~p"/orders/#{order.id}/confirmation")

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to place order")
        {:noreply, socket}
    end
  end

  defp verify_buyer_access(user_id, location_id) do
    # Get user's memberships with location access
    {:ok, memberships} = Organizations.get_memberships_for_user(user_id)

    # Find organization membership with location access and org_buyer role
    membership_with_access =
      Enum.find(memberships, fn membership ->
        has_buyer_role = :org_buyer in membership.org_roles

        has_location_access =
          Enum.any?(membership.organization_location_memberships, fn loc_membership ->
            loc_membership.location_id == location_id
          end)

        has_buyer_role and has_location_access
      end)

    if membership_with_access do
      case Organizations.get_location(location_id) do
        {:ok, location} -> {:ok, location}
        _ -> {:error, :not_found}
      end
    else
      {:error, :unauthorized}
    end
  end

  defp sort_cart_items(cart_items) do
    Enum.sort_by(cart_items, & &1.created_at, {:asc, DateTime})
  end

  defp calculate_total(cart_items) do
    Enum.reduce(cart_items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.line_total)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-gray-50 dark:bg-slate-900">
      <%!-- Main Content Area (Products) --%>
      <div class="flex-1 overflow-y-auto">
        <div class="max-w-7xl mx-auto py-8 px-6">
          <%!-- Header --%>
          <div class="mb-8">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h1 class="text-4xl font-bold text-gray-900 dark:text-white">Shop</h1>
                <p class="text-gray-600 dark:text-gray-400 mt-2">
                  {@location.name}
                </p>
              </div>
              <.link navigate={~p"/dashboard"} class="btn btn-secondary">
                <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Dashboard
              </.link>
            </div>

            <%!-- Search Bar --%>
            <form phx-submit="search" phx-change="search" class="mt-6">
              <input
                type="text"
                name="search[query]"
                value={@search_query}
                placeholder="Search products..."
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </form>
          </div>

          <%!-- Products Grid --%>
          <div
            id="products"
            phx-update="stream"
            class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            <div
              :for={{dom_id, product} <- @streams.products}
              id={dom_id}
              class="bg-white dark:bg-gray-800 rounded-xl shadow-md border border-gray-200 dark:border-gray-600 overflow-hidden hover:shadow-lg transition-shadow"
            >
              <%!-- Product Image or Gradient --%>
              <div class="aspect-w-16 aspect-h-9 bg-gray-100 dark:bg-gray-700">
                <%= if product.images != nil and length(product.images) > 0 do %>
                  <img
                    src={hd(product.images)}
                    alt={product.title}
                    class="w-full h-48 object-cover"
                  />
                <% else %>
                  <div class="w-full h-48 flex items-center justify-center">
                    <img
                      src={ProductThumbnail.generate_thumbnail(product.title, product.sku)}
                      alt={product.title}
                      class="w-full h-full object-cover"
                    />
                  </div>
                <% end %>
              </div>

              <%!-- Product Details --%>
              <div class="p-4">
                <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-1">
                  {product.title}
                </h3>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">
                  SKU: {product.sku}
                </p>

                <%= if product.description do %>
                  <p class="text-sm text-gray-600 dark:text-gray-300 mb-3 line-clamp-2">
                    {product.description}
                  </p>
                <% end %>

                <div class="flex items-center justify-between mt-4">
                  <span class="text-2xl font-bold text-gray-900 dark:text-white">
                    ${Decimal.to_string(product.price, :normal)}
                  </span>
                  <button
                    phx-click="add_to_cart"
                    phx-value-product_id={product.id}
                    class="btn btn-primary btn-sm"
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> Add to Cart
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%!-- Right Sidebar (Cart) --%>
      <div class="w-96 bg-white dark:bg-gray-800 border-l border-gray-200 dark:border-gray-700 overflow-y-auto flex flex-col">
        <div class="p-6 border-b border-gray-200 dark:border-gray-700">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Your Cart</h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
            {length(@cart.cart_items || [])} {if length(@cart.cart_items || []) == 1,
              do: "item",
              else: "items"}
          </p>
        </div>

        <%!-- Cart Items --%>
        <%= if Enum.empty?(@cart.cart_items || []) do %>
          <div class="flex-1 flex items-center justify-center p-6">
            <div class="text-center">
              <.icon name="hero-shopping-cart" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
              <p class="text-gray-600 dark:text-gray-400">Your cart is empty</p>
              <p class="text-sm text-gray-500 dark:text-gray-500 mt-2">
                Add products to get started
              </p>
            </div>
          </div>
        <% else %>
          <div class="flex-1 overflow-y-auto p-6 space-y-4">
            <div
              :for={{dom_id, item} <- @streams.cart_items}
              id={dom_id}
              class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4"
            >
              <div class="flex items-start justify-between mb-2">
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 dark:text-white">
                    {item.product.title}
                  </h4>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    SKU: {item.product.sku}
                  </p>
                  <p class="text-sm text-gray-600 dark:text-gray-300 mt-1">
                    ${Decimal.to_string(item.price_at_addition, :normal)} each
                  </p>
                </div>
                <button
                  phx-click="remove_item"
                  phx-value-item_id={item.id}
                  class="text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-300"
                  title="Remove item"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>

              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <button
                    phx-click="update_quantity"
                    phx-value-item_id={item.id}
                    phx-value-quantity={item.quantity - 1}
                    disabled={item.quantity <= 1}
                    class="w-8 h-8 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-600 text-gray-900 dark:text-white disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-500"
                  >
                    <.icon name="hero-minus" class="w-4 h-4 mx-auto" />
                  </button>
                  <span class="w-12 text-center font-semibold text-gray-900 dark:text-white">
                    {item.quantity}
                  </span>
                  <button
                    phx-click="update_quantity"
                    phx-value-item_id={item.id}
                    phx-value-quantity={item.quantity + 1}
                    class="w-8 h-8 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-600 text-gray-900 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-500"
                  >
                    <.icon name="hero-plus" class="w-4 h-4 mx-auto" />
                  </button>
                </div>
                <span class="font-bold text-gray-900 dark:text-white">
                  ${Decimal.to_string(item.line_total, :normal)}
                </span>
              </div>
            </div>
          </div>

          <%!-- Cart Footer --%>
          <div class="border-t border-gray-200 dark:border-gray-700 p-6 space-y-4">
            <%!-- Total --%>
            <div class="flex items-center justify-between text-lg font-bold">
              <span class="text-gray-900 dark:text-white">Total</span>
              <span class="text-gray-900 dark:text-white">
                ${Decimal.to_string(calculate_total(@cart.cart_items || []), :normal)}
              </span>
            </div>

            <%!-- Actions --%>
            <div class="space-y-2">
              <button phx-click="place_order" class="btn btn-primary w-full">
                <.icon name="hero-shopping-bag" class="w-5 h-5" /> Place Order
              </button>
              <button phx-click="clear_cart" class="btn btn-secondary w-full">
                <.icon name="hero-trash" class="w-5 h-5" /> Clear Cart
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
