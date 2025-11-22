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
    <div class="max-w-7xl mx-auto py-10 px-6">
        <div class="mb-10">
          <h1 class="text-5xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
          <p class="text-gray-700 dark:text-gray-200 mt-3 text-xl">
            Welcome back, <span class="font-semibold text-gray-900 dark:text-white">{@current_user.email}</span>
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
              <div class="grid gap-8 md:grid-cols-2 xl:grid-cols-3">
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
                              do: "bg-yellow-100 text-yellow-900 dark:bg-yellow-900/50 dark:text-yellow-100",
                              else: "bg-green-100 text-green-900 dark:bg-green-900/50 dark:text-green-100"
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
                          <.icon name="hero-building-office" class="w-5 h-5 text-gray-600 dark:text-gray-300" />
                          <span class="text-base font-bold text-gray-800 dark:text-gray-100">Locations</span>
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
                                    <.icon name="hero-map-pin" class="w-5 h-5 text-blue-600 dark:text-blue-300 mt-1 flex-shrink-0" />
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
                                  <div class="flex gap-2">
                                    <%= if :org_buyer in membership.org_roles and loc_membership.location.store do %>
                                      <.link
                                        navigate={~p"/location/#{loc_membership.location.id}/cart"}
                                        class="btn btn-sm btn-primary flex-shrink-0"
                                        data-testid={"cart-button-#{loc_membership.location.id}"}
                                        title="Shopping Cart"
                                      >
                                        <.icon name="hero-shopping-cart" class="w-5 h-5" />
                                      </.link>
                                    <% end %>
                                    <.link
                                      navigate={~p"/location/#{loc_membership.location.id}/orders"}
                                      class="btn btn-sm btn-secondary flex-shrink-0"
                                      data-testid={"orders-button-#{loc_membership.location.id}"}
                                      title="View Orders"
                                    >
                                      <.icon name="hero-document-text" class="w-5 h-5" />
                                    </.link>
                                  </div>
                                </div>

                                <div class="space-y-2 text-sm text-gray-700 dark:text-gray-200 mt-3">
                                  <p class="flex items-start gap-2">
                                    <.icon name="hero-home" class="w-4 h-4 mt-0.5 flex-shrink-0" />
                                    <span class="break-words">
                                      {loc_membership.location.address["street"]}, {loc_membership.location.address["city"]}, {loc_membership.location.address["state"]} {loc_membership.location.address["zip"]}
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
        </div>
    </div>
    """
  end
end
