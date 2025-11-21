defmodule Medishop.Accounts do
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Accounts.Token
    resource Medishop.Accounts.User
  end
end
