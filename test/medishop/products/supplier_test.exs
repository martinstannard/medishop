defmodule Medishop.Products.SupplierTest do
  use Medishop.DataCase

  alias Medishop.Products
  import Medishop.Generator

  describe "create_supplier/1" do
    test "creates a supplier with valid attributes" do
      assert {:ok, supplier} =
               Products.create_supplier(%{
                 name: "Acme Medical",
                 address: "123 Main St",
                 sage_id: "SAGE-123",
                 contact_email: "contact@acme.com",
                 contact_number: "555-1234"
               })

      assert supplier.name == "Acme Medical"
      assert supplier.sage_id == "SAGE-123"
      assert supplier.contact_email == "contact@acme.com"
    end
  end

  describe "update_supplier/2" do
    test "updates supplier attributes" do
      supplier = supplier() |> Ash.Generator.generate()

      assert {:ok, updated} =
               Products.update_supplier(supplier, %{
                 name: "New Name",
                 sage_id: "NEW-ID"
               })

      assert updated.name == "New Name"
      assert updated.sage_id == "NEW-ID"
    end
  end

  describe "destroy_supplier/1" do
    test "destroys a supplier" do
      supplier = supplier() |> Ash.Generator.generate()
      assert :ok = Products.destroy_supplier(supplier)
      assert {:error, _} = Products.get_supplier(supplier.id)
    end
  end

  describe "product relationship" do
    test "can link supplier to product via update_product" do
      supplier = supplier() |> Ash.Generator.generate()
      product = product() |> Ash.Generator.generate()

      assert {:ok, _updated_product} =
               Products.update_product(product, %{
                 supplier_ids: [supplier.id]
               })
      
      assert {:ok, product_with_suppliers} = Products.get_product(product.id, load: [:suppliers])
      assert length(product_with_suppliers.suppliers) == 1
      assert hd(product_with_suppliers.suppliers).id == supplier.id
    end

    test "can link supplier to product via create_product" do
      supplier = supplier() |> Ash.Generator.generate()
      
      assert {:ok, product} =
               Products.create_product(%{
                 sku: "SUP-PROD-001",
                 title: "Supplier Product",
                 price: Decimal.new("10.00"),
                 supplier_ids: [supplier.id]
               })

      assert {:ok, product_with_suppliers} = Products.get_product(product.id, load: [:suppliers])
      assert length(product_with_suppliers.suppliers) == 1
      assert hd(product_with_suppliers.suppliers).id == supplier.id
    end
  end
end
