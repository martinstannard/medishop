defmodule Medishop.ProductsFixtures do
  @moduledoc """
  This module defines test fixtures for the Products domain.
  """

  alias Medishop.Products

  @doc """
  Generate a unique SKU.
  """
  def unique_sku, do: "SKU-#{System.unique_integer([:positive])}"

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    sku = Map.get(attrs, :sku, unique_sku())
    title = Map.get(attrs, :title, "Test Product #{System.unique_integer([:positive])}")
    price = Map.get(attrs, :price, Decimal.new("10.00"))

    {:ok, product} =
      Products.create_product(
        Map.merge(
          %{
            sku: sku,
            title: title,
            price: price
          },
          attrs
        )
      )

    product
  end
end
