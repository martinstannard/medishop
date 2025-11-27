
defmodule MedishopWeb.LandingLive do
  use MedishopWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-4xl font-bold text-center mb-4">Welcome to Medishop</h1>
      <p class="text-xl text-center text-gray-700">Your trusted source for medical supplies.</p>
      <div class="mt-8 flex justify-center space-x-4">
        <a href={~p"/sign-in"} class="btn btn-primary">Sign In</a>
        <a href={~p"/register"} class="btn btn-secondary">Register</a>
      </div>
    </div>
    """
  end
end
