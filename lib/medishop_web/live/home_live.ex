defmodule MedishopWeb.HomeLive do
  use MedishopWeb, :live_view

  alias AshPhoenix.Form
  alias Medishop.Accounts.User

  on_mount {MedishopWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      form = Form.for_action(User, :sign_in_with_password, as: "user", api: Medishop.Accounts)

      {:ok, assign(socket, form: to_form(form), trigger_action: false, error: nil)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = Form.validate(socket.assigns.form.source, user_params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    form = socket.assigns.form.source

    form
    |> Form.validate(user_params)
    |> Form.submit()
    |> case do
      {:ok, _user} ->
        {:noreply, assign(socket, trigger_action: true, form: to_form(form))}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form), trigger_action: false)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4 py-12">
      <div class="max-w-md w-full">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-primary mb-2">MediShop</h1>
          <p class="text-base-content/70">Welcome back! Please login to your account.</p>
        </div>

        <.card>
          <.card_content class="p-8">
            <.form
              for={@form}
              phx-change="validate"
              phx-submit="submit"
              action={~p"/auth/user/password/sign_in"}
              method="post"
            >
              <div class="space-y-6">
                <div>
                  <.input
                    field={@form[:email]}
                    type="email"
                    label="Email"
                    placeholder="Enter your email"
                    required
                  />
                </div>

                <div>
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    placeholder="Enter your password"
                    required
                  />
                </div>

                <div class="flex items-center justify-between">
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" class="checkbox checkbox-sm" name="remember_me" />
                    <span class="text-sm">Remember me</span>
                  </label>

                  <.link navigate={~p"/reset"} class="text-sm text-primary hover:underline">
                    Forgot password?
                  </.link>
                </div>

                <.button type="submit" class="w-full">
                  Sign In
                </.button>
              </div>
            </.form>
          </.card_content>

          <.card_footer class="bg-base-300 p-4 text-center">
            <p class="text-sm text-base-content/70">
              Don't have an account?
              <.link navigate={~p"/register"} class="text-primary hover:underline font-semibold">
                Sign up
              </.link>
            </p>
          </.card_footer>
        </.card>
      </div>
    </div>
    """
  end
end
