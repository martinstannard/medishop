defmodule MedishopWeb.PaymentMethodsLive do
  use MedishopWeb, :live_view

  alias Medishop.Organizations
  alias Medishop.StripeService
  require Logger

  def mount(_params, _session, socket) do
    {:ok, assign(socket, organization: nil, show_modal: false, client_secret: nil, payment_methods: [])}
  end

  def handle_params(_params, _uri, socket) do
    organization =
      case socket.assigns.current_user do
        nil -> nil
        user -> Organizations.get_organization_by_user_id(user.id)
      end

    payment_methods =
      case organization do
        nil -> []
        org ->
          case StripeService.list_payment_methods(org.stripe_customer_id) do
            {:ok, %{"data" => methods}} -> methods
            _ -> []
          end
      end

    {:noreply, assign(socket, organization: organization, payment_methods: payment_methods)}
  end

  def handle_event("show_modal", _, socket) do
    case StripeService.create_setup_intent(socket.assigns.organization.stripe_customer_id) do
      {:ok, %{"client_secret" => client_secret}} ->
        {:noreply, assign(socket, show_modal: true, client_secret: client_secret)}

      {:error, error} ->
        Logger.error("Could not create setup intent: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Could not add payment method.")}
    end
  end

  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, client_secret: nil)}
  end

  def handle_event("stripe-success", %{"setup_intent" => setup_intent}, socket) do
    Logger.info("Stripe success: #{inspect(setup_intent)}")
    {:noreply, put_flash(socket, :info, "Payment method saved!") |> assign(show_modal: false, client_secret: nil)}
  end

  def handle_event("stripe-error", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, error)}
  end

  def handle_event("delete_payment_method", %{"id" => pm_id}, socket) do
    case StripeService.detach_payment_method(pm_id) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Payment method deleted!")}

      {:error, error} ->
        Logger.error("Could not delete payment method: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Could not delete payment method.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold">Manage Payment Methods</h1>

      <%= if @organization do %>
        <div class="mt-4">
          <.button phx-click="show_modal">Add Payment Method</.button>
        </div>

        <div class="mt-8">
          <h2 class="text-xl font-bold">Saved Payment Methods</h2>
          <ul class="mt-4">
            <%= for pm <- @payment_methods do %>
              <li class="flex items-center justify-between py-2 border-b">
                <div>
                  <span><%= pm["card"]["brand"] %> ****<%= pm["card"]["last4"] %></span>
                  <span class="ml-4 text-gray-500">Expires <%= pm["card"]["exp_month"] %>/<%= pm["card"]["exp_year"] %></span>
                </div>
                <.button phx-click="delete_payment_method" phx-value-id={pm["id"]} class="text-red-500">
                  Delete
                </.button>
              </li>
            <% end %>
          </ul>
        </div>
      <% else %>
        <p>You are not a member of any organization.</p>
      <% end %>

      <%= if @show_modal do %>
        <.modal id="payment-method-modal" title="Add Payment Method" on_cancel={JS.push("hide_modal")}>
          <.form
            for={:payment_method}
            phx-submit="save_payment_method"
            phx-hook="StripeHook"
            data-publishable-key={Application.get_env(:medishop, :stripe)[:publishable_key]}
            data-client-secret={@client_secret}
          >
            <div id="card-element" class="my-4"></div>
            <.button type="submit">Save</.button>
          </.form>
        </.modal>
      <% end %>
    </div>
    """
  end
end
