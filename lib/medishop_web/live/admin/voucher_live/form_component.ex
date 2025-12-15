defmodule MedishopWeb.Admin.VoucherLive.FormComponent do
  use MedishopWeb, :live_component

  alias Medishop.Shop
  alias Medishop.Organizations
  alias Medishop.Products

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="px-6 py-4 border-b border-base-200">
        <h2 class="text-xl font-bold">{@title}</h2>
      </div>

      <div class="p-6 h-[80vh] overflow-y-auto">
        <.form
          for={@form}
          id="voucher-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6 pb-12"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input field={@form[:name]} type="text" label="Name" />
            <.input field={@form[:code]} type="text" label="Code" />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="label">Discount Type</label>
              <div class="flex items-center gap-4">
                <label class="cursor-pointer label gap-2">
                  <input
                    type="radio"
                    name={@form[:discount_type].name}
                    value="percentage"
                    checked={to_string(@form[:discount_type].value) == "percentage"}
                    class="radio"
                    phx-change="validate"
                  />
                  <span class="label-text">Percentage</span>
                </label>
                <label class="cursor-pointer label gap-2">
                  <input
                    type="radio"
                    name={@form[:discount_type].name}
                    value="fixed"
                    checked={to_string(@form[:discount_type].value) == "fixed"}
                    class="radio"
                    phx-change="validate"
                  />
                  <span class="label-text">Fixed Amount</span>
                </label>
              </div>
            </div>
            <.input field={@form[:discount_value]} type="number" label="Discount Value" step="0.01" />
          </div>

          <div class="divider">Requirements</div>

          <div>
            <label class="label">Minimum Purchase Requirement</label>
            <div class="flex items-center gap-4 mb-4">
              <label class="cursor-pointer label gap-2">
                <input
                  type="radio"
                  name={@form[:min_purchase_type].name}
                  value="none"
                  checked={to_string(@form[:min_purchase_type].value) == "none" || is_nil(@form[:min_purchase_type].value)}
                  class="radio"
                  phx-change="validate"
                />
                <span class="label-text">None</span>
              </label>
              <label class="cursor-pointer label gap-2">
                <input
                  type="radio"
                  name={@form[:min_purchase_type].name}
                  value="amount"
                  checked={to_string(@form[:min_purchase_type].value) == "amount"}
                  class="radio"
                  phx-change="validate"
                />
                <span class="label-text">Min Amount ($)</span>
              </label>
              <label class="cursor-pointer label gap-2">
                <input
                  type="radio"
                  name={@form[:min_purchase_type].name}
                  value="quantity"
                  checked={to_string(@form[:min_purchase_type].value) == "quantity"}
                  class="radio"
                  phx-change="validate"
                />
                <span class="label-text">Min Quantity</span>
              </label>
            </div>
            
            <%= if to_string(@form[:min_purchase_type].value) in ["amount", "quantity"] do %>
              <.input field={@form[:min_purchase_value]} type="number" label="Minimum Value" step="0.01" />
            <% end %>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input field={@form[:start_date]} type="date" label="Start Date" />
            <.input field={@form[:end_date]} type="date" label="End Date" />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input field={@form[:usage_limit_total]} type="number" label="Total Usage Limit" />
            <.input field={@form[:usage_limit_per_location]} type="number" label="Usage Limit Per Location" />
          </div>

          <div class="divider">Eligibility</div>

          <div>
             <label class="label">Organizations (Leave empty for all)</label>
             <div class="h-48 overflow-y-auto border rounded p-2 bg-base-100">
               <%= for org <- @organizations do %>
                 <label class="cursor-pointer label justify-start gap-2">
                   <input
                     type="checkbox"
                     name={@form[:organization_ids].name <> "[]"}
                     value={org.id}
                     checked={selected?(org.id, @form[:organization_ids].value, @voucher.organizations)}
                     class="checkbox checkbox-sm"
                   />
                   <span class="label-text">{org.name}</span>
                 </label>
               <% end %>
             </div>
          </div>

          <div>
             <label class="label">Locations (Leave empty for all)</label>
             <div class="h-48 overflow-y-auto border rounded p-2 bg-base-100">
               <%= for loc <- @locations do %>
                 <label class="cursor-pointer label justify-start gap-2">
                   <input
                     type="checkbox"
                     name={@form[:location_ids].name <> "[]"}
                     value={loc.id}
                     checked={selected?(loc.id, @form[:location_ids].value, @voucher.locations)}
                     class="checkbox checkbox-sm"
                   />
                   <span class="label-text">{loc.name}</span>
                 </label>
               <% end %>
             </div>
          </div>

          <div>
             <label class="label">Products (Leave empty for all)</label>
             <div class="h-48 overflow-y-auto border rounded p-2 bg-base-100">
               <%= for prod <- @products do %>
                 <label class="cursor-pointer label justify-start gap-2">
                   <input
                     type="checkbox"
                     name={@form[:product_ids].name <> "[]"}
                     value={prod.id}
                     checked={selected?(prod.id, @form[:product_ids].value, @voucher.products)}
                     class="checkbox checkbox-sm"
                   />
                   <span class="label-text">{prod.title} ({prod.sku})</span>
                 </label>
               <% end %>
             </div>
          </div>
          
          <div class="divider">Settings</div>

          <div class="flex flex-col gap-2">
            <label class="cursor-pointer label justify-start gap-4">
              <.input field={@form[:active]} type="checkbox" label="" />
              <span class="label-text font-semibold">Active</span>
            </label>
             <label class="cursor-pointer label justify-start gap-4">
              <.input field={@form[:apply_to_shipping]} type="checkbox" label="" />
              <span class="label-text">Apply to Shipping</span>
            </label>
             <label class="cursor-pointer label justify-start gap-4">
              <.input field={@form[:combinable]} type="checkbox" label="" />
              <span class="label-text">Combinable with other discounts</span>
            </label>
          </div>

          <div class="modal-action">
            <.button class="btn btn-primary" phx-disable-with="Saving...">Save Voucher</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{voucher: voucher} = assigns, socket) do
    {:ok, organizations} = Organizations.list_organizations()
    {:ok, locations} = Organizations.list_locations()
    {:ok, products} = Products.list_products()

    # Preload relationships if existing voucher and not already loaded
    voucher = 
      if voucher.id && !Ash.Resource.loaded?(voucher, :organizations) do
        {:ok, v} = Shop.get_voucher(voucher.id, load: [:organizations, :locations, :products])
        v
      else
        voucher
      end

    form = 
      if voucher.id do
         AshPhoenix.Form.for_update(voucher, :update,
          api: Shop,
          as: "voucher",
          forms: [auto?: true]
        )
      else
        AshPhoenix.Form.for_create(Medishop.Shop.Voucher, :create,
          api: Shop,
          as: "voucher",
          forms: [auto?: true]
        )
      end
      |> to_form()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:voucher, voucher)
     |> assign(:organizations, organizations)
     |> assign(:locations, locations)
     |> assign(:products, products)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"voucher" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"voucher" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, voucher} ->
        notify_parent({:saved, voucher})

        {:noreply,
         socket
         |> put_flash(:info, "Voucher saved successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp selected?(id, form_value, resource_list) do
    id_str = to_string(id)
    
    # Check form value first (strings from params)
    if form_value do
      Enum.any?(form_value, fn val -> to_string(val) == id_str end)
    else
      # Fallback to resource relationship (structs)
      if is_list(resource_list) do
        Enum.any?(resource_list, fn item -> to_string(item.id) == id_str end)
      else
        false
      end
    end
  end
end
