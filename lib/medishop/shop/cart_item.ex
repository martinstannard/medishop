defmodule Medishop.Shop.CartItem do
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Shop,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "cart_items"
    repo Medishop.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:cart_id, :product_id, :quantity, :price_at_addition]
    end

    update :update do
      primary? true
      accept [:quantity]
    end

    action :add_or_update do
      argument :cart_id, :uuid, allow_nil?: false
      argument :product_id, :uuid, allow_nil?: false
      argument :quantity, :integer, allow_nil?: false
      returns :struct

      run fn input, _context ->
        cart_id = input.arguments.cart_id
        product_id = input.arguments.product_id
        quantity = input.arguments.quantity

        # Get product to capture current price
        case Medishop.Products.get_product(product_id) do
          {:ok, product} ->
            # Try to find existing cart item
            case Medishop.Shop.get_cart_item_by_cart_and_product(cart_id, product_id) do
              {:ok, cart_item} ->
                # Update existing item quantity
                Medishop.Shop.update_cart_item(cart_item, %{quantity: quantity})

              {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
                # Create new cart item
                Medishop.Shop.create_cart_item(%{
                  cart_id: cart_id,
                  product_id: product_id,
                  quantity: quantity,
                  price_at_addition: product.price
                })

              {:error, %Ash.Error.Query.NotFound{}} ->
                # Direct NotFound error
                Medishop.Shop.create_cart_item(%{
                  cart_id: cart_id,
                  product_id: product_id,
                  quantity: quantity,
                  price_at_addition: product.price
                })

              {:error, error} ->
                {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  policies do
    # Allow all actions for now (will implement proper authorization in Phase 4)
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :integer do
      allow_nil? false
      default 1
      constraints min: 1
      public? true
    end

    attribute :price_at_addition, :decimal do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :cart, Medishop.Shop.Cart do
      allow_nil? false
      public? true
    end

    belongs_to :product, Medishop.Products.Product do
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :line_total, :decimal, expr(quantity * price_at_addition)
  end

  identities do
    identity :unique_cart_item_per_product, [:cart_id, :product_id]
  end
end
