defmodule MedishopWeb.DashboardLive do
  use MedishopWeb, :live_view

  alias Medishop.Organizations

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok, memberships} = Organizations.get_memberships_for_user(user.id)

    {:ok, assign(socket, memberships: memberships, page_title: "Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-10 px-6">
      <div class="space-y-10">
        <section>
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-2xl font-bold text-gray-900 dark:text-white">My Organizations</h2>
          </div>

          <%= if Enum.empty?(@memberships) do %>
            <div class="bg-white dark:bg-gray-800 rounded-xl p-12 text-center border border-dashed border-gray-300 dark:border-gray-600">
              <.icon name="hero-building-office-2" class="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <h3 class="text-lg font-medium text-gray-900 dark:text-white">No Organizations</h3>
              <p class="text-gray-500 dark:text-gray-400 mt-1">
                You are not a member of any organizations yet.
              </p>
            </div>
          <% else %>
            <div class="space-y-8">
              <%= for membership <- @memberships do %>
                <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
                  <!-- Organization Header -->
                  <div class="px-6 py-5 border-b border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-800/50 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                    <div class="flex items-center gap-4">
                      <div class="w-12 h-12 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm">
                        <span class="text-white font-bold text-xl">
                          {String.at(membership.organization.name, 0)}
                        </span>
                      </div>
                      <div>
                        <h3 class="text-xl font-bold text-gray-900 dark:text-white leading-tight">
                          {membership.organization.name}
                        </h3>
                        <div class="flex flex-wrap items-center gap-2 mt-1.5">
                          <%= if membership.organization.is_test_organization do %>
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
                              Test Org
                            </span>
                          <% else %>
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300">
                              Active
                            </span>
                          <% end %>
                          <span class="text-gray-300 dark:text-gray-600">|</span>
                          <%= for role <- membership.org_roles do %>
                            <span class="text-sm text-gray-600 dark:text-gray-400">
                              {Phoenix.Naming.humanize(role)}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Locations List -->
                  <div class="bg-white dark:bg-gray-800">
                    <%= if Enum.empty?(membership.organization_location_memberships) do %>
                      <div class="px-6 py-12 text-center">
                        <p class="text-gray-500 dark:text-gray-400 italic">
                          No location access assigned.
                        </p>
                      </div>
                    <% else %>
                      <div class="divide-y divide-gray-100 dark:divide-gray-700">
                        <%= for loc_membership <- membership.organization_location_memberships do %>
                          <div class="group px-6 py-5 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors">
                            <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
                              <!-- Location Info -->
                              <div class="flex items-start gap-4 min-w-0 flex-1">
                                <div class="mt-1">
                                  <.icon
                                    name="hero-map-pin"
                                    class="w-5 h-5 text-gray-400 dark:text-gray-500 group-hover:text-blue-500 transition-colors"
                                  />
                                </div>
                                <div>
                                  <div class="flex items-center gap-2.5 mb-1">
                                    <h4 class="text-lg font-semibold text-gray-900 dark:text-white">
                                      {loc_membership.location.name}
                                    </h4>
                                    <%= if loc_membership.location.store do %>
                                      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300">
                                        Store
                                      </span>
                                    <% end %>
                                  </div>
                                  <div class="text-sm text-gray-500 dark:text-gray-400 space-y-0.5">
                                    <p>
                                      {loc_membership.location.address["street"]}, {loc_membership.location.address[
                                        "city"
                                      ]}, {loc_membership.location.address["state"]} {loc_membership.location.address[
                                        "zip"
                                      ]}
                                    </p>
                                    <p class="text-gray-400 dark:text-gray-500 text-xs mt-1">
                                      {loc_membership.location.contact_number}
                                    </p>
                                  </div>
                                </div>
                              </div>

                              <!-- Actions -->
                              <div class="flex flex-wrap items-center gap-3 pt-2 lg:pt-0">
                                <%= if :org_buyer in membership.org_roles and loc_membership.location.store do %>
                                  <.link
                                    navigate={~p"/location/#{loc_membership.location.id}/shop"}
                                    class="inline-flex items-center gap-2 rounded-md bg-blue-600 px-3 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 dark:bg-blue-500 dark:hover:bg-blue-400 transition-colors"
                                    data-testid={"shop-button-#{loc_membership.location.id}"}
                                  >
                                    <.icon name="hero-shopping-bag" class="w-4 h-4" /> Shop
                                  </.link>
                                <% end %>
                                <.link
                                  navigate={~p"/location/#{loc_membership.location.id}/orders"}
                                  class="inline-flex items-center gap-2 rounded-md bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-200 dark:ring-gray-600 dark:hover:bg-gray-700 transition-colors"
                                  data-testid={"orders-button-#{loc_membership.location.id}"}
                                >
                                  <.icon name="hero-document-text" class="w-4 h-4 text-gray-400 dark:text-gray-400" /> Orders
                                </.link>
                                <.link
                                  navigate={~p"/location/#{loc_membership.location.id}/inventory"}
                                  class="inline-flex items-center gap-2 rounded-md bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-200 dark:ring-gray-600 dark:hover:bg-gray-700 transition-colors"
                                  data-testid={"inventory-button-#{loc_membership.location.id}"}
                                >
                                  <.icon name="hero-cube" class="w-4 h-4 text-gray-400 dark:text-gray-400" /> Inventory
                                </.link>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end
end
