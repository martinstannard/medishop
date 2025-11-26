defmodule Medishop.Shop.VoucherLogicTest do
  use Medishop.DataCase

  alias Medishop.Shop
  import Medishop.Generator

  describe "validate_voucher/3" do
    setup do
      location = location() |> Ash.Generator.generate()
      cart = cart(location_id: location.id) |> Ash.Generator.generate()
      %{cart: cart}
    end

    test "returns error if voucher not found", %{cart: cart} do
      assert {:error, :not_found} = Shop.validate_voucher("INVALID", cart, nil)
    end

    test "returns error if voucher expired", %{cart: cart} do
      _voucher = voucher(
        code: "EXPIRED",
        start_date: ~D[2020-01-01],
        end_date: ~D[2020-01-31]
      ) |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:error, :expired} = Shop.validate_voucher("EXPIRED", cart, nil)
    end

    test "returns error if voucher not active", %{cart: cart} do
      _voucher = voucher(
        code: "INACTIVE",
        active: false
      ) |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:error, :inactive} = Shop.validate_voucher("INACTIVE", cart, nil)
    end

    test "returns voucher if valid", %{cart: cart} do
      voucher = voucher(code: "VALID") |> Ash.Generator.generate() |> List.wrap() |> hd()
      # We need to preload associations for full validation, but for basic check it returns voucher
      # The function signature will likely need context (cart, user)
      assert {:ok, v} = Shop.validate_voucher("VALID", cart, nil)
      assert v.id == voucher.id
    end
  end

  describe "calculate_discount/2" do
    test "calculates percentage discount" do
      voucher = voucher(
        discount_type: :percentage,
        discount_value: Decimal.new("10.0")
      ) |> Ash.Generator.generate() |> List.wrap() |> hd()

      cart = cart() |> Ash.Generator.generate() |> List.wrap() |> hd()
      # Add items worth 100.00
      _item = cart_item(
        cart_id: cart.id, 
        price_at_addition: Decimal.new("100.00"), 
        quantity: 1
      ) |> Ash.Generator.generate()

      # Reload cart with items
      {:ok, cart} = Shop.get_cart(cart.id, load: [:cart_items])

      discount = Shop.calculate_discount(voucher, cart)
      assert Decimal.eq?(discount, Decimal.new("10.00"))
    end

    test "calculates fixed discount" do
      voucher = voucher(
        discount_type: :fixed,
        discount_value: Decimal.new("15.00")
      ) |> Ash.Generator.generate() |> List.wrap() |> hd()

      cart = cart() |> Ash.Generator.generate() |> List.wrap() |> hd()
      _item = cart_item(
        cart_id: cart.id, 
        price_at_addition: Decimal.new("100.00"), 
        quantity: 1
      ) |> Ash.Generator.generate()

      {:ok, cart} = Shop.get_cart(cart.id, load: [:cart_items])

      discount = Shop.calculate_discount(voucher, cart)
      assert Decimal.eq?(discount, Decimal.new("15.00"))
    end

    test "caps fixed discount at subtotal" do
      voucher = voucher(
        discount_type: :fixed,
        discount_value: Decimal.new("50.00")
      ) |> Ash.Generator.generate() |> List.wrap() |> hd()

      cart = cart() |> Ash.Generator.generate() |> List.wrap() |> hd()
      _item = cart_item(
        cart_id: cart.id, 
        price_at_addition: Decimal.new("20.00"), 
        quantity: 1
      ) |> Ash.Generator.generate()

      {:ok, cart} = Shop.get_cart(cart.id, load: [:cart_items])

      discount = Shop.calculate_discount(voucher, cart)
      assert Decimal.eq?(discount, Decimal.new("20.00"))
    end
  end
end
