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
    <div class="max-w-4xl mx-auto py-8 px-4">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-base-content">Dashboard</h1>
        <p class="text-base-content mt-2">
          Welcome back, <span class="font-semibold">{@current_user.email}</span>
        </p>
      </div>

      <div class="space-y-8">
        <section>
          <h2 class="text-2xl font-semibold mb-4 text-primary">My Organizations</h2>
          
          <%= if Enum.empty?(@memberships) do %>
            <div class="bg-base-200 rounded-lg p-6 text-center">
              <p class="text-base-content">You are not a member of any organizations yet.</p>
            </div>
          <% else %>
            <div class="grid gap-6 md:grid-cols-2">
              <%= for membership <- @memberships do %>
                <.card class="bg-base-100 shadow-xl border border-base-300">
                  <.card_content class="p-6">
                    <div class="flex justify-between items-start mb-6">
                      <div>
                        <h3 class="text-2xl font-extrabold text-base-content tracking-tight">
                          {membership.organization.name}
                        </h3>
                        <div class="flex items-center gap-2 mt-1">
                           <span class={["badge badge-md", if(membership.organization.is_test_organization, do: "badge-warning", else: "badge-success")]}>
                             {if membership.organization.is_test_organization, do: "Test Org", else: "Active"}
                           </span>
                           <%= for role <- membership.org_roles do %>
                              <span class="badge badge-md badge-outline">
                                {Phoenix.Naming.humanize(role)}
                              </span>
                           <% end %>
                        </div>
                      </div>
                    </div>

                    <div class="space-y-4">
                      <h4 class="font-bold text-base uppercase tracking-wider text-primary border-b border-base-200 pb-2">
                        Locations & Access
                      </h4>
                      
                      <%= if Enum.empty?(membership.organization_location_memberships) do %>
                        <p class="text-base text-base-content italic">No specific location access assigned.</p>
                      <% else %>
                        <div class="grid gap-4">
                          <%= for loc_membership <- membership.organization_location_memberships do %>
                            <div class="bg-base-200/50 rounded-lg p-3">
                              <div class="flex items-center justify-between mb-2">
                                <span class="font-bold text-base-content flex items-center gap-2">
                                  <.icon name="hero-map-pin" class="w-5 h-5 text-primary" />
                                  {loc_membership.location.name}
                                </span>
                                <%= if loc_membership.location.store do %>
                                  <span class="badge badge-sm badge-info">Store</span>
                                <% end %>
                              </div>
                              
                              <div class="pl-7 space-y-1 text-base-content">
                                <p class="flex items-start gap-1">
                                  <.icon name="hero-home" class="w-4 h-4 mt-0.5 opacity-80" />
                                  <span>
                                    {loc_membership.location.address["street"]}, 
                                    {loc_membership.location.address["city"]}, {loc_membership.location.address["state"]} {loc_membership.location.address["zip"]}
                                  </span>
                                </p>
                                <p class="flex items-center gap-1">
                                  <.icon name="hero-phone" class="w-4 h-4 opacity-80" />
                                  <span>{loc_membership.location.contact_number}</span>
                                </p>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </.card_content>
                </.card>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end
end
