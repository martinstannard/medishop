defmodule MedishopWeb.Admin.VoucherLive.Index do
  use MedishopWeb, :live_view

  alias Medishop.Shop
  alias Medishop.Shop.Voucher

  on_mount {MedishopWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # In a real app, verify admin permissions here
      # For now, we assume authenticated user is enough or add a check
      :ok
    end

    {:ok,
     socket
     |> assign(:page_title, "Vouchers")
     |> stream(:vouchers, list_vouchers())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Voucher")
    |> assign(:voucher, Shop.get_voucher!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Voucher")
    |> assign(:voucher, %Voucher{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Vouchers")
    |> assign(:voucher, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    voucher = Shop.get_voucher!(id)
    {:ok, _} = Shop.destroy_voucher(voucher)

    {:noreply, stream_delete(socket, :vouchers, voucher)}
  end

  defp list_vouchers do
    {:ok, vouchers} = Shop.list_vouchers()
    vouchers
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-7xl mx-auto">
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-3xl font-bold text-base-content">Vouchers</h1>
          <p class="mt-2 text-base-content/60">Manage promotional codes and discounts</p>
        </div>
        <.link patch={~p"/admin/vouchers/new"} class="btn btn-primary gap-2">
          <.icon name="hero-plus" class="w-5 h-5" /> New Voucher
        </.link>
      </div>

      <div class="bg-base-100 rounded-lg shadow-lg border border-base-300 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Code / Name</th>
                <th>Discount</th>
                <th>Validity</th>
                <th>Status</th>
                <th>Usage</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody id="vouchers" phx-update="stream">
              <tr :for={{dom_id, voucher} <- @streams.vouchers} id={dom_id}>
                <td>
                  <div class="font-bold">{voucher.code}</div>
                  <div class="text-sm opacity-60">{voucher.name}</div>
                </td>
                <td>
                  <div class="badge badge-neutral">
                    <%= if voucher.discount_type == :percentage do %>
                      {Decimal.to_string(voucher.discount_value)}%
                    <% else %>
                      ${Decimal.to_string(voucher.discount_value)}
                    <% end %>
                  </div>
                  <%= if voucher.min_purchase_type != :none do %>
                    <div class="text-xs mt-1 opacity-60">
                      Min: {voucher.min_purchase_type} {Decimal.to_string(voucher.min_purchase_value)}
                    </div>
                  <% end %>
                </td>
                <td>
                  <div class="text-sm">
                    <%= if voucher.start_date do %>
                      <div>From: {voucher.start_date}</div>
                    <% end %>
                    <%= if voucher.end_date do %>
                      <div>To: {voucher.end_date}</div>
                    <% end %>
                    <%= if is_nil(voucher.start_date) and is_nil(voucher.end_date) do %>
                      <span class="italic text-base-content/40">Always valid</span>
                    <% end %>
                  </div>
                </td>
                <td>
                  <%= if voucher.active do %>
                    <div class="badge badge-success gap-1">
                      Active
                    </div>
                  <% else %>
                    <div class="badge badge-ghost gap-1">
                      Inactive
                    </div>
                  <% end %>
                </td>
                <td>
                  <div class="text-sm">
                    <%= if voucher.usage_limit_total do %>
                      Limit: {voucher.usage_limit_total}
                    <% else %>
                      Unlimited
                    <% end %>
                  </div>
                </td>
                <td class="text-right">
                  <div class="join">
                    <.link
                      patch={~p"/admin/vouchers/#{voucher}/edit"}
                      class="btn btn-sm btn-ghost join-item"
                    >
                      Edit
                    </.link>
                    <button
                      class="btn btn-sm btn-ghost text-error join-item"
                      phx-click="delete"
                      phx-value-id={voucher.id}
                      data-confirm="Are you sure you want to delete this voucher?"
                    >
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="voucher-modal"
      show
      on_cancel={JS.patch(~p"/admin/vouchers")}
    >
      <.live_component
        module={MedishopWeb.Admin.VoucherLive.FormComponent}
        id={@voucher.id || :new}
        title={@page_title}
        action={@live_action}
        voucher={@voucher}
        patch={~p"/admin/vouchers"}
      />
    </.modal>
    """
  end
end
