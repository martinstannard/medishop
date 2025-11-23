defmodule MedishopWeb.ProductsLive do
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
        {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

        # Load active products
        {:ok, products} = Products.list_products()
        active_products = Enum.filter(products, & &1.active)

        # Calculate cart item count
        cart_item_count = length(cart_with_items.cart_items || [])

        socket =
          socket
          |> assign(:location, location)
          |> assign(:cart, cart)
          |> assign(:cart_item_count, cart_item_count)
          |> assign(:search_query, "")
          |> assign(:products, active_products)
          |> stream(:products, active_products, dom_id: &"product-#{&1.id}")
          |> assign(:page_title, "Browse Products - #{location.name}")

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
      |> assign(:products, active_products)
      |> stream(:products, active_products, reset: true)

    {:noreply, socket}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    cart = socket.assigns.cart

    case Shop.add_or_update_cart_item(cart.id, product_id, 1) do
      {:ok, _cart_item} ->
        # Reload cart to get updated item count
        {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])
        cart_item_count = length(cart_with_items.cart_items || [])

        socket =
          socket
          |> assign(:cart_item_count, cart_item_count)
          |> put_flash(:info, "Product added to cart!")

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to add product to cart")
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-8 px-4">
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-base-content">Browse Products</h1>
          <p class="text-base-content mt-2">
            <span class="font-semibold">{@location.name}</span>
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/location/#{@location.id}/cart"}
            class="btn btn-primary gap-2 relative"
            data-testid="view-cart-button"
          >
            <.icon name="hero-shopping-cart" class="w-5 h-5" /> View Cart
            <%= if @cart_item_count > 0 do %>
              <span
                class="absolute -top-2 -right-2 badge badge-sm badge-secondary"
                data-testid="cart-count-badge"
              >
                {@cart_item_count}
              </span>
            <% end %>
          </.link>
          <.link navigate={~p"/dashboard"} class="btn btn-ghost gap-2">
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Dashboard
          </.link>
        </div>
      </div>

      <div class="mb-6">
        <form phx-change="search" phx-submit="search" class="max-w-md">
          <div class="flex gap-2">
            <input
              type="text"
              name="search[query]"
              value={@search_query}
              placeholder="Search products..."
              class="input input-bordered flex-1"
              data-testid="search-input"
            />
            <button type="submit" class="btn btn-primary gap-2">
              <.icon name="hero-magnifying-glass" class="w-5 h-5" /> Search
            </button>
          </div>
        </form>
      </div>

      <%= if Enum.empty?(@products) do %>
        <div class="bg-base-200 rounded-lg p-12 text-center">
          <.icon name="hero-archive-box-x-mark" class="w-16 h-16 mx-auto mb-4 text-base-300" />
          <h2 class="text-2xl font-bold text-base-content mb-2">No products found</h2>
          <p class="text-base-content mb-6">
            <%= if @search_query != "" do %>
              Try adjusting your search terms.
            <% else %>
              There are currently no products available.
            <% end %>
          </p>
          <%= if @search_query != "" do %>
            <button
              type="button"
              class="btn btn-primary"
              phx-click="search"
              phx-value-query=""
            >
              Clear Search
            </button>
          <% end %>
        </div>
      <% else %>
        <div
          id="products"
          phx-update="stream"
          class="grid gap-6 md:grid-cols-2 lg:grid-cols-3"
          data-testid="products-grid"
        >
          <div
            :for={{dom_id, product} <- @streams.products}
            id={dom_id}
            data-testid={"product-card-#{product.id}"}
            class="card bg-base-100 shadow-xl border border-base-300"
          >
            <figure class="px-4 pt-4">
              <%= if Enum.empty?(product.images) do %>
                <img
                  src={ProductThumbnail.generate_thumbnail(product.title, product.sku)}
                  alt={product.title}
                  class="rounded-lg w-full h-48 object-cover"
                />
              <% else %>
                <img
                  src={List.first(product.images)}
                  alt={product.title}
                  class="rounded-lg w-full h-48 object-cover"
                />
              <% end %>
            </figure>
            <div class="card-body">
              <h3 class="card-title text-base-content">{product.title}</h3>
              <p class="text-sm text-base-content/70 line-clamp-2">
                {product.description || "No description available"}
              </p>
              <div class="text-sm text-base-content/60 mt-1">
                SKU: <span class="font-mono">{product.sku}</span>
              </div>
              <div class="divider my-2"></div>
              <div class="flex items-center justify-between">
                <div class="text-2xl font-bold text-primary">
                  ${Decimal.to_string(product.price, :normal)}
                </div>
                <button
                  type="button"
                  class="btn btn-primary btn-sm gap-2"
                  phx-click="add_to_cart"
                  phx-value-product_id={product.id}
                  data-testid={"add-to-cart-#{product.id}"}
                >
                  <.icon name="hero-shopping-cart" class="w-4 h-4" /> Add to Cart
                </button>
              </div>
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
end
