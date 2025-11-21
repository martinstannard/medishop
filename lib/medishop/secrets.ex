defmodule Medishop.Secrets do
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
