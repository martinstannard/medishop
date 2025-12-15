defmodule MedishopWeb.AuthHelpers do
  @moduledoc false
  import AshAuthentication.Plug.Helpers
  import Phoenix.ConnTest

  def log_in_user(conn, user) do
    conn
    |> init_test_session(%{})
    |> store_in_session(user)
  end
end
