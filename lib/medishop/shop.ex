defmodule Medishop.Shop do
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Shop.Cart do
      # Create actions
      define :create_cart, action: :create

      # Read actions
      define :list_carts, action: :read
      define :get_cart, action: :read, get_by: [:id]
      define :get_cart_by_location, action: :read, get_by: [:location_id]

      # Update actions
      define :update_cart, action: :update
      define :clear_cart, action: :clear

      # Destroy actions
      define :destroy_cart, action: :destroy

      # Custom actions
      define :get_or_create_cart_for_location,
        action: :get_or_create_for_location,
        args: [:location_id]
    end

    resource Medishop.Shop.CartItem do
      # Create actions
      define :create_cart_item, action: :create

      # Read actions
      define :list_cart_items, action: :read
      define :get_cart_item, action: :read, get_by: [:id]
      define :get_cart_item_by_cart_and_product, action: :read, get_by: [:cart_id, :product_id]

      # Update actions
      define :update_cart_item, action: :update

      # Destroy actions
      define :remove_cart_item, action: :destroy

      # Custom actions
      define :add_or_update_cart_item,
        action: :add_or_update,
        args: [:cart_id, :product_id, :quantity]
    end

    resource Medishop.Shop.Order do
      # Create actions
      define :create_order, action: :create

      # Read actions
      define :list_orders, action: :read
      define :get_order, action: :read, get_by: [:id]
      define :get_order_by_number, action: :read, get_by: [:order_number]
      define :get_orders_for_location, action: :get_by_location, args: [:location_id]
      define :get_orders_for_user, action: :get_by_user, args: [:user_id]

      # Update actions
      define :update_order, action: :update
      define :update_order_status, action: :update_status, args: [:status]

      # Destroy actions
      define :destroy_order, action: :destroy

      # Custom actions
      define :create_order_from_cart,
        action: :create_from_cart,
        args: [:cart_id, :user_id, {:optional, :notes}]
    end

    resource Medishop.Shop.OrderItem do
      # Create actions
      define :create_order_item, action: :create

      # Read actions (order items are immutable, no update/destroy)
      define :list_order_items, action: :read
      define :get_order_item, action: :read, get_by: [:id]
    end
  end
end
