defmodule MedishopWeb.InventoryDetailLive do
  @moduledoc """
  LiveView for displaying detailed inventory information for a specific product at a location.
  Shows the event log and provides actions for recording new inventory events.
  """

  use MedishopWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <h1 class="text-4xl font-bold">Inventory Detail</h1>
      <p class="mt-4 text-gray-600">Coming soon...</p>
    </div>
    """
  end
end
