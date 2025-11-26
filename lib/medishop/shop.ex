defmodule Medishop.Shop do
  @moduledoc """
  The Shop domain manages shopping carts and order processing.

  This domain handles:
  - Shopping carts (one per location)
  - Cart items with quantities and prices
  - Order creation from carts
  - Order tracking and status management
  """
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

    resource Medishop.Shop.Voucher do
      define :create_voucher, action: :create
      define :list_vouchers, action: :read
      define :get_voucher, action: :read, get_by: [:id]
      define :get_voucher_by_code, action: :by_code, args: [:code]
      define :update_voucher, action: :update
      define :destroy_voucher, action: :destroy
    end

    resource Medishop.Shop.VoucherRedemption do
      define :create_voucher_redemption, action: :create
    end
    resource Medishop.Shop.VoucherOrganization
    resource Medishop.Shop.VoucherLocation
    resource Medishop.Shop.VoucherProduct
  end

  def calculate_cart_totals(cart) do
    subtotal =
      Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
        Decimal.add(acc, Decimal.mult(Decimal.new(item.quantity), item.price_at_addition))
      end)

    if cart.voucher_id do
      case get_voucher(cart.voucher_id) do
        {:ok, voucher} ->
          discount = calculate_discount(voucher, cart)
          {:ok, %{subtotal: subtotal, discount_total: discount, total: Decimal.sub(subtotal, discount)}}
        {:error, _} ->
          {:ok, %{subtotal: subtotal, discount_total: Decimal.new("0.00"), total: subtotal}}
      end
    else
      {:ok, %{subtotal: subtotal, discount_total: Decimal.new("0.00"), total: subtotal}}
    end
  end

  require Ash.Query

  def validate_voucher(code, cart, _user) do
    case get_voucher_by_code(code, load: [:organizations, :locations]) do
      {:ok, voucher} ->
        with :ok <- check_active(voucher),
             :ok <- check_dates(voucher),
             :ok <- check_eligibility(voucher, cart),
             :ok <- check_requirements(voucher, cart),
             :ok <- check_limits(voucher, cart) do
          {:ok, voucher}
        else
          error -> error
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp check_active(voucher) do
    if voucher.active, do: :ok, else: {:error, :inactive}
  end

  defp check_dates(voucher) do
    today = Date.utc_today()

    cond do
      voucher.start_date && Date.compare(voucher.start_date, today) == :gt -> {:error, :not_started}
      voucher.end_date && Date.compare(voucher.end_date, today) == :lt -> {:error, :expired}
      true -> :ok
    end
  end

  defp check_eligibility(voucher, cart) do
    # Check Organization/Location whitelist
    # If list is empty, it means ALL are allowed.
    
    {:ok, location} = Medishop.Organizations.get_location(cart.location_id)

    loc_check =
      if Enum.empty?(voucher.locations) do
        true
      else
        Enum.any?(voucher.locations, fn l -> l.id == location.id end)
      end

    org_check =
      if Enum.empty?(voucher.organizations) do
        true
      else
        Enum.any?(voucher.organizations, fn o -> o.id == location.organization_id end)
      end

    if loc_check and org_check do
      :ok
    else
      {:error, :not_eligible_location}
    end
  end

  defp check_requirements(voucher, cart) do
    case voucher.min_purchase_type do
      :none ->
        :ok

      :amount ->
        subtotal = calculate_subtotal(cart)

        if Decimal.compare(subtotal, voucher.min_purchase_value) != :lt do
          :ok
        else
          {:error, :min_spend_not_met}
        end

      :quantity ->
        total_qty = Enum.reduce(cart.cart_items, 0, &(&1.quantity + &2))

        if total_qty >= Decimal.to_integer(voucher.min_purchase_value) do
          :ok
        else
          {:error, :min_quantity_not_met}
        end
    end
  end

  defp check_limits(voucher, cart) do
    if voucher.usage_limit_total do
      count = count_redemptions(voucher.id)

      if count >= voucher.usage_limit_total do
        {:error, :usage_limit_reached}
      else
        check_location_limit(voucher, cart)
      end
    else
      check_location_limit(voucher, cart)
    end
  end

  defp check_location_limit(voucher, cart) do
    if voucher.usage_limit_per_location do
      count = count_redemptions(voucher.id, cart.location_id)

      if count >= voucher.usage_limit_per_location do
        {:error, :location_usage_limit_reached}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp count_redemptions(voucher_id) do
    Medishop.Shop.VoucherRedemption
    |> Ash.Query.filter(voucher_id == ^voucher_id)
    |> Ash.count!()
  end

  defp count_redemptions(voucher_id, location_id) do
    Medishop.Shop.VoucherRedemption
    |> Ash.Query.filter(voucher_id == ^voucher_id and location_id == ^location_id)
    |> Ash.count!()
  end

  defp calculate_subtotal(cart) do
    Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(Decimal.new(item.quantity), item.price_at_addition))
    end)
  end

  def calculate_discount(voucher, cart) do
    subtotal =
      Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
        # Calculate line total if not present, or use item.line_total if it exists and is reliable
        # Assuming cart_items are loaded.
        # Recalculate to be safe: quantity * price_at_addition
        line_total = Decimal.mult(Decimal.new(item.quantity), item.price_at_addition)
        Decimal.add(acc, line_total)
      end)

    case voucher.discount_type do
      :percentage ->
        # discount_value is percentage (e.g., 10.0 for 10%)
        multiplier = Decimal.div(voucher.discount_value, Decimal.new(100))
        Decimal.mult(subtotal, multiplier)

      :fixed ->
        # Cap at subtotal
        if Decimal.compare(voucher.discount_value, subtotal) == :gt do
          subtotal
        else
          voucher.discount_value
        end
    end
  end
end
