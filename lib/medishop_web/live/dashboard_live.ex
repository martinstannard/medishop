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
    <div class="max-w-6xl mx-auto py-8 px-4">
      <div class="mb-8">
        <h1 class="text-4xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
        <p class="text-gray-600 dark:text-gray-300 mt-2 text-lg">
          Welcome back, <span class="font-semibold text-gray-900 dark:text-white">{@current_user.email}</span>
        </p>
      </div>

      <div class="space-y-6">
        <section>
          <h2 class="text-2xl font-bold mb-6 text-gray-900 dark:text-white">My Organizations</h2>

          <%= if Enum.empty?(@memberships) do %>
            <div class="bg-white dark:bg-gray-800 rounded-xl p-8 text-center border border-gray-200 dark:border-gray-700">
              <p class="text-gray-600 dark:text-gray-300">You are not a member of any organizations yet.</p>
            </div>
          <% else %>
            <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              <%= for membership <- @memberships do %>
                <div class="bg-white dark:bg-gray-800 rounded-xl shadow-lg border border-gray-200 dark:border-gray-700 overflow-hidden hover:shadow-xl transition-shadow">
                  <div class="p-6">
                    <div class="mb-4">
                      <h3 class="text-xl font-bold text-gray-900 dark:text-white mb-2">
                        {membership.organization.name}
                      </h3>
                      <div class="flex flex-wrap items-center gap-2">
                        <span class={[
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          if(membership.organization.is_test_organization,
                            do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200",
                            else: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                          )
                        ]}>
                          {if membership.organization.is_test_organization, do: "Test", else: "Active"}
                        </span>
                        <%= for role <- membership.org_roles do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                            {Phoenix.Naming.humanize(role)}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div class="space-y-3">
                      <div class="flex items-center gap-2 pb-2 border-b border-gray-200 dark:border-gray-700">
                        <.icon name="hero-building-office" class="w-4 h-4 text-gray-500 dark:text-gray-400" />
                        <span class="text-sm font-semibold text-gray-700 dark:text-gray-300">Locations</span>
                      </div>

                      <%= if Enum.empty?(membership.organization_location_memberships) do %>
                        <p class="text-sm text-gray-500 dark:text-gray-400 italic">
                          No location access
                        </p>
                      <% else %>
                        <div class="space-y-3">
                          <%= for loc_membership <- membership.organization_location_memberships do %>
                            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3 border border-gray-200 dark:border-gray-700">
                              <div class="flex items-start justify-between gap-2 mb-2">
                                <div class="flex items-start gap-2 min-w-0 flex-1">
                                  <.icon name="hero-map-pin" class="w-4 h-4 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
                                  <div class="min-w-0 flex-1">
                                    <p class="font-semibold text-gray-900 dark:text-white text-sm">
                                      {loc_membership.location.name}
                                    </p>
                                    <%= if loc_membership.location.store do %>
                                      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200 mt-1">
                                        Store
                                      </span>
                                    <% end %>
                                  </div>
                                </div>
                                <%= if :org_buyer in membership.org_roles and loc_membership.location.store do %>
                                  <.link
                                    navigate={~p"/location/#{loc_membership.location.id}/cart"}
                                    class="btn btn-sm btn-primary flex-shrink-0"
                                    data-testid={"cart-button-#{loc_membership.location.id}"}
                                  >
                                    <.icon name="hero-shopping-cart" class="w-4 h-4" />
                                  </.link>
                                <% end %>
                              </div>

                              <div class="space-y-1 text-xs text-gray-600 dark:text-gray-400 mt-2">
                                <p class="flex items-start gap-1.5">
                                  <.icon name="hero-home" class="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                                  <span class="break-words">
                                    {loc_membership.location.address["street"]}, {loc_membership.location.address["city"]}, {loc_membership.location.address["state"]} {loc_membership.location.address["zip"]}
                                  </span>
                                </p>
                                <p class="flex items-center gap-1.5">
                                  <.icon name="hero-phone" class="w-3.5 h-3.5 flex-shrink-0" />
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
      </div>
    </div>
    """
  end
end
