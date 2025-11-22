defmodule Medishop.Shop do
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Shop.Cart do
      define :get_or_create_cart_for_location,
        action: :get_or_create_for_location,
        args: [:location_id]

      define :clear_cart, action: :clear
    end
  end
end
