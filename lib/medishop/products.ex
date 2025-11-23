defmodule Medishop.Products do
  @moduledoc """
  The Products domain manages the product catalog.

  This domain handles:
  - Product definitions (medications, medical supplies)
  - Product attributes (SKU, title, description, pricing)
  - Product search and filtering
  """
  use Ash.Domain, otp_app: :medishop, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Medishop.Products.Product do
      define :create_product, action: :create
      define :list_products, action: :read
      define :get_product, action: :read, get_by: [:id]
      define :get_product_by_sku, action: :read, get_by: [:sku]
      define :search_products, action: :search
      define :update_product, action: :update
      define :destroy_product, action: :destroy
    end
  end
end
