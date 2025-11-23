defmodule MedishopWeb.DashboardLive do
  use MedishopWeb, :live_view

  alias Medishop.{Organizations, Inventory}

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok, memberships} = Organizations.get_memberships_for_user(user.id)

    # Get low stock items across all user's locations
    low_stock_items = get_low_stock_items(memberships)

    {:ok,
     assign(socket,
       memberships: memberships,
       low_stock_items: low_stock_items,
       page_title: "Dashboard"
     )}
  end

  # Get low stock items (quantity < 10) across all user's locations
  defp get_low_stock_items(memberships) do
    memberships
    |> Enum.flat_map(fn membership ->
      membership.organization_location_memberships
      |> Enum.flat_map(fn loc_membership ->
        location_id = loc_membership.location.id

        case Inventory.get_inventory_by_location(%{location_id: location_id}) do
          {:ok, inventory_items} ->
            inventory_items
            |> Enum.map(fn item ->
              {:ok, item_with_data} = Ash.load(item, [:current_quantity, :product, :location])
              item_with_data
            end)
            |> Enum.filter(fn item -> item.current_quantity < 10 end)

          _ ->
            []
        end
      end)
    end)
    |> Enum.sort_by(fn item -> item.current_quantity end, :asc)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-10 px-6">
      <div class="mb-10">
        <h1 class="text-5xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
        <p class="text-gray-700 dark:text-gray-200 mt-3 text-xl">
          Welcome back,
          <span class="font-semibold text-gray-900 dark:text-white">{@current_user.email}</span>
        </p>
      </div>

      <div class="space-y-8">
        <section>
          <h2 class="text-3xl font-bold mb-8 text-gray-900 dark:text-white">My Organizations</h2>

          <%= if Enum.empty?(@memberships) do %>
            <div class="bg-white dark:bg-gray-800 rounded-2xl p-10 text-center border border-gray-200 dark:border-gray-600">
              <p class="text-lg text-gray-700 dark:text-gray-200">
                You are not a member of any organizations yet.
              </p>
            </div>
          <% else %>
            <div class="grid gap-8 md:grid-cols-1 lg:grid-cols-2">
              <%= for membership <- @memberships do %>
                <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-600 overflow-hidden hover:shadow-2xl transition-shadow">
                  <div class="p-8">
                    <div class="mb-6">
                      <h3 class="text-2xl font-bold text-gray-900 dark:text-white mb-3">
                        {membership.organization.name}
                      </h3>
                      <div class="flex flex-wrap items-center gap-2.5">
                        <span class={[
                          "inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold",
                          if(membership.organization.is_test_organization,
                            do:
                              "bg-yellow-100 text-yellow-900 dark:bg-yellow-900/50 dark:text-yellow-100",
                            else:
                              "bg-green-100 text-green-900 dark:bg-green-900/50 dark:text-green-100"
                          )
                        ]}>
                          {if membership.organization.is_test_organization, do: "Test", else: "Active"}
                        </span>
                        <%= for role <- membership.org_roles do %>
                          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-blue-100 text-blue-900 dark:bg-blue-900/50 dark:text-blue-100">
                            {Phoenix.Naming.humanize(role)}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div class="space-y-4">
                      <div class="flex items-center gap-3 pb-3 border-b-2 border-gray-200 dark:border-gray-600">
                        <.icon
                          name="hero-building-office"
                          class="w-5 h-5 text-gray-600 dark:text-gray-300"
                        />
                        <span class="text-base font-bold text-gray-800 dark:text-gray-100">
                          Locations
                        </span>
                      </div>

                      <%= if Enum.empty?(membership.organization_location_memberships) do %>
                        <p class="text-base text-gray-600 dark:text-gray-300 italic">
                          No location access
                        </p>
                      <% else %>
                        <div class="space-y-4">
                          <%= for loc_membership <- membership.organization_location_memberships do %>
                            <div class="bg-gray-50 dark:bg-gray-700 rounded-xl p-4 border border-gray-200 dark:border-gray-600">
                              <div class="flex items-start justify-between gap-3 mb-3">
                                <div class="flex items-start gap-3 min-w-0 flex-1">
                                  <.icon
                                    name="hero-map-pin"
                                    class="w-5 h-5 text-blue-600 dark:text-blue-300 mt-1 flex-shrink-0"
                                  />
                                  <div class="min-w-0 flex-1">
                                    <p class="font-bold text-gray-900 dark:text-white text-base mb-2">
                                      {loc_membership.location.name}
                                    </p>
                                    <%= if loc_membership.location.store do %>
                                      <span class="inline-flex items-center px-3 py-1 rounded-md text-sm font-semibold bg-purple-100 text-purple-900 dark:bg-purple-900/50 dark:text-purple-100">
                                        Store
                                      </span>
                                    <% end %>
                                  </div>
                                </div>
                                <div class="flex flex-wrap gap-2">
                                  <%= if :org_buyer in membership.org_roles and loc_membership.location.store do %>
                                    <.link
                                      navigate={~p"/location/#{loc_membership.location.id}/shop"}
                                      class="btn btn-sm btn-primary flex-shrink-0"
                                      data-testid={"shop-button-#{loc_membership.location.id}"}
                                      title="Shop"
                                    >
                                      <.icon name="hero-shopping-cart" class="w-5 h-5" /> Shop
                                    </.link>
                                  <% end %>
                                  <.link
                                    navigate={~p"/location/#{loc_membership.location.id}/orders"}
                                    class="btn btn-sm btn-secondary flex-shrink-0"
                                    data-testid={"orders-button-#{loc_membership.location.id}"}
                                    title="View Orders"
                                  >
                                    <.icon name="hero-document-text" class="w-5 h-5" /> Orders
                                  </.link>
                                  <.link
                                    navigate={~p"/location/#{loc_membership.location.id}/inventory"}
                                    class="btn btn-sm btn-secondary flex-shrink-0"
                                    data-testid={"inventory-button-#{loc_membership.location.id}"}
                                    title="View Inventory"
                                  >
                                    <.icon name="hero-cube" class="w-5 h-5" /> Inventory
                                  </.link>
                                </div>
                              </div>

                              <div class="space-y-2 text-sm text-gray-700 dark:text-gray-200 mt-3">
                                <p class="flex items-start gap-2">
                                  <.icon name="hero-home" class="w-4 h-4 mt-0.5 flex-shrink-0" />
                                  <span class="break-words">
                                    {loc_membership.location.address["street"]}, {loc_membership.location.address[
                                      "city"
                                    ]}, {loc_membership.location.address["state"]} {loc_membership.location.address[
                                      "zip"
                                    ]}
                                  </span>
                                </p>
                                <p class="flex items-center gap-2">
                                  <.icon name="hero-phone" class="w-4 h-4 flex-shrink-0" />
                                  <span>{loc_membership.location.contact_number}</span>
                                </p>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>

        <%!-- Low Stock Alerts Section --%>
        <%= if not Enum.empty?(@low_stock_items) do %>
          <section id="low-stock-alerts">
            <div class="mb-6 flex items-center justify-between">
              <h2 class="text-3xl font-bold text-gray-900 dark:text-white">
                Low Stock Alerts
              </h2>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-100">
                {length(@low_stock_items)} {if length(@low_stock_items) == 1, do: "Item", else: "Items"}
              </span>
            </div>

            <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl border border-yellow-200 dark:border-yellow-600 overflow-hidden">
              <div class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for item <- @low_stock_items do %>
                  <div
                    class="p-6 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                    id={"low-stock-item-#{item.id}"}
                  >
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="flex items-center gap-4">
                          <div>
                            <h3 class="text-lg font-bold text-gray-900 dark:text-white">
                              {item.product.title}
                            </h3>
                            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                              SKU: {item.product.sku} • {item.location.name}
                            </p>
                          </div>
                          <span class={[
                            "inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold",
                            if(item.current_quantity == 0,
                              do: "bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300",
                              else: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300"
                            )
                          ]}>
                            {item.current_quantity} {if item.current_quantity == 1, do: "unit", else: "units"}
                          </span>
                        </div>
                      </div>
                      <div>
                        <.link
                          navigate={~p"/location/#{item.location_id}/inventory/#{item.product_id}"}
                          class="inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-blue-600 dark:bg-blue-500 rounded-lg hover:bg-blue-700 dark:hover:bg-blue-600 transition-colors"
                        >
                          View Details →
                        </.link>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>
        <% end %>
        <%!-- End Low Stock Alerts Section --%>
      </div>
    </div>
    """
  end
end
