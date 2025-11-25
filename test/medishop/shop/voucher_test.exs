defmodule Medishop.Shop.VoucherTest do
  use Medishop.DataCase

  alias Medishop.Shop
  import Medishop.Generator

  describe "create_voucher/1" do
    test "creates a voucher with valid attributes" do
      assert {:ok, voucher} =
               Shop.create_voucher(%{
                 name: "Summer Sale",
                 code: "SUMMER25",
                 discount_type: :percentage,
                 discount_value: Decimal.new("25.0")
               })

      assert voucher.name == "Summer Sale"
      assert to_string(voucher.code) == "SUMMER25"
      assert voucher.discount_type == :percentage
      assert Decimal.eq?(voucher.discount_value, Decimal.new("25.0"))
    end

    test "enforces unique code" do
      {:ok, _} = Shop.create_voucher(%{
        name: "First",
        code: "UNIQUE",
        discount_type: :fixed,
        discount_value: Decimal.new("10")
      })

      assert {:error, %Ash.Error.Invalid{}} =
               Shop.create_voucher(%{
                 name: "Second",
                 code: "UNIQUE",
                 discount_type: :fixed,
                 discount_value: Decimal.new("5")
               })
    end

    test "code is case insensitive" do
      {:ok, _} = Shop.create_voucher(%{
        name: "First",
        code: "CASE",
        discount_type: :fixed,
        discount_value: Decimal.new("10")
      })

      assert {:error, %Ash.Error.Invalid{}} =
               Shop.create_voucher(%{
                 name: "Second",
                 code: "case",
                 discount_type: :fixed,
                 discount_value: Decimal.new("5")
               })
    end
  end

  describe "get_voucher_by_code/1" do
    test "retrieves voucher by code" do
      voucher = voucher(code: "FINDME") |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:ok, found} = Shop.get_voucher_by_code("FINDME")
      assert found.id == voucher.id
    end

    test "retrieves voucher by code case insensitively" do
      voucher = voucher(code: "MixedCase") |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:ok, found} = Shop.get_voucher_by_code("mixedcase")
      assert found.id == voucher.id
    end
  end

  describe "relationships" do
    test "can manage organization eligibility" do
      org = organization() |> Ash.Generator.generate() |> List.wrap() |> hd()
      voucher = voucher() |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:ok, updated} = Shop.update_voucher(voucher, %{
        organization_ids: [org.id]
      })

      assert {:ok, loaded} = Shop.get_voucher(updated.id, load: [:organizations])
      assert length(loaded.organizations) == 1
      assert hd(loaded.organizations).id == org.id
    end

    test "can manage location eligibility" do
      loc = location() |> Ash.Generator.generate() |> List.wrap() |> hd()
      voucher = voucher() |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:ok, updated} = Shop.update_voucher(voucher, %{
        location_ids: [loc.id]
      })

      assert {:ok, loaded} = Shop.get_voucher(updated.id, load: [:locations])
      assert length(loaded.locations) == 1
      assert hd(loaded.locations).id == loc.id
    end

    test "can manage product eligibility" do
      prod = product() |> Ash.Generator.generate() |> List.wrap() |> hd()
      voucher = voucher() |> Ash.Generator.generate() |> List.wrap() |> hd()

      assert {:ok, updated} = Shop.update_voucher(voucher, %{
        product_ids: [prod.id]
      })

      assert {:ok, loaded} = Shop.get_voucher(updated.id, load: [:products])
      assert length(loaded.products) == 1
      assert hd(loaded.products).id == prod.id
    end
  end
end
