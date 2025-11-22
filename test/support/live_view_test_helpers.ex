defmodule MedishopWeb.LiveViewTestHelpers do
  @moduledoc """
  Helpers for testing LiveViews with authentication.
  """

  @doc """
  Logs in a user for LiveView tests by storing them in the session.

  This helper uses AshAuthentication.Plug.Helpers.store_in_session/2
  which is the correct way to authenticate users in tests.
  """
  def log_in_user(conn, user) do
    # Generate JWT token for the user
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    user = Ash.Resource.put_metadata(user, :token, token)

    # Store user in session using AshAuthentication helpers
    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
