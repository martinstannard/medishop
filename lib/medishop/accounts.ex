defmodule Medishop.Accounts do
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Accounts.Token

    resource Medishop.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :get_user_by_email, action: :get_by_email, args: [:email]
      define :register_user, action: :register, args: [:email, :password]
    end
  end
end
