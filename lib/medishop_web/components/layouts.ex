defmodule MedishopWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MedishopWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <div class="flex items-center gap-8">
            <a href="/" class="flex items-center gap-2.5 group">
              <div class="flex items-center justify-center w-10 h-10 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg shadow-md group-hover:shadow-lg transition-shadow">
                <.icon name="hero-shopping-bag" class="size-6 text-white" />
              </div>
              <div class="flex flex-col">
                <span class="text-xl font-bold text-gray-900 dark:text-white tracking-tight">
                  Medishop
                </span>
                <span class="text-xs text-gray-500 dark:text-gray-400 -mt-1">
                  Healthcare Supply Platform
                </span>
              </div>
            </a>
          </div>

          <div class="flex items-center gap-4">
            <.theme_toggle />

            <%= if assigns[:current_user] do %>
              <div class="dropdown dropdown-end">
                <div
                  tabindex="0"
                  role="button"
                  class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors cursor-pointer"
                >
                  <div class="flex items-center justify-center w-8 h-8 bg-blue-600 text-white rounded-full text-sm font-semibold">
                    {to_string(@current_user.email) |> String.slice(0, 2) |> String.upcase()}
                  </div>
                  <.icon name="hero-chevron-down" class="size-4 text-gray-600 dark:text-gray-400" />
                </div>
                <ul
                  tabindex="0"
                  class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow-lg bg-white dark:bg-gray-800 rounded-xl w-56 border border-gray-200 dark:border-gray-700"
                >
                  <li class="px-4 py-2 text-xs text-gray-500 dark:text-gray-400 border-b border-gray-200 dark:border-gray-700">
                    <%= if String.length(to_string(@current_user.email)) > 30 do %>
                      {String.slice(to_string(@current_user.email), 0, 30)}...
                    <% else %>
                      {to_string(@current_user.email)}
                    <% end %>
                  </li>
                  <li>
                    <.link
                      navigate="/dashboard"
                      class="text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
                    >
                      <.icon name="hero-squares-2x2" class="size-4" /> Dashboard
                    </.link>
                  </li>
                  <li>
                    <a
                      href={~p"/sign-out"}
                      class="text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign Out
                    </a>
                  </li>
                </ul>
              </div>
            <% else %>
              <a href="/" class="btn btn-primary">
                Sign In
              </a>
            <% end %>
          </div>
        </div>
      </div>
    </header>

    <main class="min-h-screen bg-gray-50 dark:bg-slate-900">
      <div class="mx-auto space-y-4">
        <%= if assigns[:inner_block] do %>
          {render_slot(@inner_block)}
        <% else %>
          {@inner_content}
        <% end %>
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center border-2 border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-800 rounded-full p-0.5">
      <div class="absolute w-1/3 h-[calc(100%-4px)] rounded-full bg-white dark:bg-gray-700 shadow-md left-0.5 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-all duration-200" />

      <button
        class="relative flex items-center justify-center p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 text-gray-600 dark:text-gray-300 opacity-75 hover:opacity-100 transition-opacity" />
      </button>

      <button
        class="relative flex items-center justify-center p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 text-gray-600 dark:text-gray-300 opacity-75 hover:opacity-100 transition-opacity" />
      </button>

      <button
        class="relative flex items-center justify-center p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 text-gray-600 dark:text-gray-300 opacity-75 hover:opacity-100 transition-opacity" />
      </button>
    </div>
    """
  end
end
