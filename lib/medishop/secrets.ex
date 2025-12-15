defmodule Medishop.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Medishop.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:medishop, :token_signing_secret)
  end
end
