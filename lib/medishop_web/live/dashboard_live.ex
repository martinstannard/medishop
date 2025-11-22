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
        <p class="text-base-content/70 mt-2">
          Welcome back, <span class="font-semibold">{@current_user.email}</span>
        </p>
      </div>

      <div class="space-y-8">
        <section>
          <h2 class="text-2xl font-semibold mb-4 text-primary">My Organizations</h2>
          
          <%= if Enum.empty?(@memberships) do %>
            <div class="bg-base-200 rounded-lg p-6 text-center">
              <p class="text-base-content/70">You are not a member of any organizations yet.</p>
            </div>
          <% else %>
            <div class="grid gap-6 md:grid-cols-2">
              <%= for membership <- @memberships do %>
                <.card class="bg-base-100 shadow-lg">
                  <.card_content class="p-6">
                    <div class="flex justify-between items-start mb-4">
                      <div>
                        <h3 class="text-xl font-bold text-base-content">
                          {membership.organization.name}
                        </h3>
                        <p class="text-sm text-base-content/60">
                          {if membership.organization.is_test_organization, do: "Test Organization", else: "Active Organization"}
                        </p>
                      </div>
                      <div class="flex gap-2">
                        <%= for role <- membership.org_roles do %>
                          <span class="badge badge-primary badge-outline text-xs">
                            {Phoenix.Naming.humanize(role)}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div class="divider my-2"></div>

                    <div>
                      <h4 class="font-semibold text-sm uppercase tracking-wider text-base-content/50 mb-3">
                        Authorized Locations
                      </h4>
                      
                      <%= if Enum.empty?(membership.organization_location_memberships) do %>
                        <p class="text-sm text-base-content/60 italic">No specific location access assigned.</p>
                      <% else %>
                        <ul class="space-y-2">
                          <%= for loc_membership <- membership.organization_location_memberships do %>
                            <li class="flex items-center gap-2 text-sm">
                              <.icon name="hero-map-pin" class="w-4 h-4 text-secondary" />
                              <span>{loc_membership.location.name}</span>
                              <%= if loc_membership.location.store do %>
                                <span class="badge badge-sm badge-ghost">Store</span>
                              <% end %>
                            </li>
                          <% end %>
                        </ul>
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
