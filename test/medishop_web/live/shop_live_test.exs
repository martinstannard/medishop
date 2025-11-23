defmodule MedishopWeb.ShopLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  alias Medishop.Shop

  describe "ShopLive - cart item ordering" do
    setup %{conn: conn} do
      user = user() |> Ash.Generator.generate()
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()

      # Create membership with org_buyer role and make location a store
      membership = organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create products
      product1 = product(title: "Aspirin", sku: "ASP-100", price: Decimal.new("10.00")) |> Ash.Generator.generate()
      product2 = product(title: "Ibuprofen", sku: "IBU-200", price: Decimal.new("15.50")) |> Ash.Generator.generate()
      product3 = product(title: "Acetaminophen", sku: "ACE-300", price: Decimal.new("12.00")) |> Ash.Generator.generate()

      # Log in the user
      conn = log_in_user(conn, user)

      %{
        conn: conn,
        user: user,
        org: org,
        location: location,
        product1: product1,
        product2: product2,
        product3: product3
      }
    end

    # Helper to extract cart item IDs in order from rendered HTML
    defp extract_cart_item_order(html) do
      # Match all cart-item-{id} divs in order
      Regex.scan(~r/id="cart-item-([0-9a-f-]+)"/, html)
      |> Enum.map(fn [_, id] -> id end)
    end

    # Helper to get product IDs from cart items in order
    defp get_product_ids_from_cart_items(item_ids) do
      Enum.map(item_ids, fn item_id ->
        {:ok, item} = Shop.get_cart_item(item_id)
        item.product_id
      end)
    end

    test "maintains cart item order when updating quantities", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      # Add products to cart with manually set created_at timestamps
      # Use generator for cart
      cart = cart(location_id: location.id) |> Ash.Generator.generate()

      base_time = DateTime.utc_now()

      {:ok, item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 1)
      # Manually set created_at for first item
      Ash.Changeset.for_update(item1, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -2, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 1)
      # Manually set created_at for second item
      Ash.Changeset.for_update(item2, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -1, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item3} = Shop.add_or_update_cart_item(cart.id, product3.id, 1)
      # Manually set created_at for third item (most recent)
      Ash.Changeset.for_update(item3, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, base_time)
      |> Ash.update!(authorize?: false)

      # Mount the ShopLive page
      {:ok, view, html} = live(conn, ~p"/location/#{location.id}/shop")

      # Verify initial order
      initial_order = extract_cart_item_order(html)
      assert length(initial_order) == 3
      assert initial_order == [item1.id, item2.id, item3.id]

      # Update quantity of the second item using the + button (increment)
      # The increment button has phx-value-quantity set to item.quantity + 1
      view
      |> element(
        "#cart-item-#{item2.id} button[phx-click='update_quantity'][phx-value-quantity='2']"
      )
      |> render_click()

      # Verify order is maintained after quantity update
      html = render(view)
      order_after_update = extract_cart_item_order(html)
      assert order_after_update == [item1.id, item2.id, item3.id]

      # Update quantity of the first item (from 1 to 2)
      view
      |> element(
        "#cart-item-#{item1.id} button[phx-click='update_quantity'][phx-value-quantity='2']"
      )
      |> render_click()

      # Verify order is still maintained
      html = render(view)
      order_after_second_update = extract_cart_item_order(html)
      assert order_after_second_update == [item1.id, item2.id, item3.id]

      # Update quantity of the last item (from 1 to 2)
      view
      |> element(
        "#cart-item-#{item3.id} button[phx-click='update_quantity'][phx-value-quantity='2']"
      )
      |> render_click()

      # Verify order is still maintained
      html = render(view)
      final_order = extract_cart_item_order(html)
      assert final_order == [item1.id, item2.id, item3.id]
    end

    test "maintains cart item order when adding new products", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      # Add first two products to cart with manually set created_at timestamps
      cart = cart(location_id: location.id) |> Ash.Generator.generate()

      base_time = DateTime.utc_now()

      {:ok, item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 1)

      Ash.Changeset.for_update(item1, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -1, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 1)

      Ash.Changeset.for_update(item2, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, base_time)
      |> Ash.update!(authorize?: false)

      # Mount the ShopLive page
      {:ok, view, html} = live(conn, ~p"/location/#{location.id}/shop")

      # Verify initial order
      initial_order = extract_cart_item_order(html)
      assert length(initial_order) == 2
      assert initial_order == [item1.id, item2.id]

      # Add third product via the UI (will get current timestamp, making it newest)
      view
      |> element("button[phx-click='add_to_cart'][phx-value-product_id='#{product3.id}']")
      |> render_click()

      # Verify new product appears at the end
      html = render(view)
      order_after_add = extract_cart_item_order(html)
      assert length(order_after_add) == 3

      # Get the new item3 ID
      product_ids = get_product_ids_from_cart_items(order_after_add)
      assert product_ids == [product1.id, product2.id, product3.id]

      # Update quantity of first item to ensure order is still maintained (from 1 to 2)
      view
      |> element(
        "#cart-item-#{item1.id} button[phx-click='update_quantity'][phx-value-quantity='2']"
      )
      |> render_click()

      # Verify first item is still first
      html = render(view)
      final_order = extract_cart_item_order(html)
      final_product_ids = get_product_ids_from_cart_items(final_order)
      assert final_product_ids == [product1.id, product2.id, product3.id]
    end

    test "cart items are sorted by created_at timestamp", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      # Add products to cart with manually set created_at timestamps
      cart = cart(location_id: location.id) |> Ash.Generator.generate()

      base_time = DateTime.utc_now()

      {:ok, item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 1)

      Ash.Changeset.for_update(item1, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -2, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 1)

      Ash.Changeset.for_update(item2, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -1, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item3} = Shop.add_or_update_cart_item(cart.id, product3.id, 1)

      Ash.Changeset.for_update(item3, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, base_time)
      |> Ash.update!(authorize?: false)

      # Mount the ShopLive page
      {:ok, _view, _html} = live(conn, ~p"/location/#{location.id}/shop")

      # Get cart items from the database to verify they have the created_at field
      {:ok, cart_with_items} = Shop.get_cart(cart.id, load: [:cart_items])

      # Verify all cart items have created_at timestamps
      for item <- cart_with_items.cart_items do
        assert item.created_at != nil, "Cart item #{item.id} missing created_at timestamp"
      end

      # Sort items by created_at
      sorted_items =
        Enum.sort_by(cart_with_items.cart_items, & &1.created_at, {:asc, DateTime})

      # Verify items are in chronological order
      assert Enum.at(sorted_items, 0).product_id == product1.id
      assert Enum.at(sorted_items, 1).product_id == product2.id
      assert Enum.at(sorted_items, 2).product_id == product3.id
    end

    test "removing and re-adding a product places it at the end", %{
      conn: conn,
      location: location,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      # Add products to cart with manually set created_at timestamps
      cart = cart(location_id: location.id) |> Ash.Generator.generate()

      base_time = DateTime.utc_now()

      {:ok, item1} = Shop.add_or_update_cart_item(cart.id, product1.id, 1)

      Ash.Changeset.for_update(item1, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -2, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item2} = Shop.add_or_update_cart_item(cart.id, product2.id, 1)

      Ash.Changeset.for_update(item2, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, DateTime.add(base_time, -1, :second))
      |> Ash.update!(authorize?: false)

      {:ok, item3} = Shop.add_or_update_cart_item(cart.id, product3.id, 1)

      Ash.Changeset.for_update(item3, :update, %{})
      |> Ash.Changeset.force_change_attribute(:created_at, base_time)
      |> Ash.update!(authorize?: false)

      # Mount the ShopLive page
      {:ok, view, html} = live(conn, ~p"/location/#{location.id}/shop")

      # Verify initial order
      initial_order = extract_cart_item_order(html)
      assert initial_order == [item1.id, item2.id, item3.id]

      # Remove the second product
      view
      |> element("button[phx-click='remove_item'][phx-value-item_id='#{item2.id}']")
      |> render_click()

      # Verify order is now (product1, product3)
      html = render(view)
      order_after_remove = extract_cart_item_order(html)
      assert length(order_after_remove) == 2
      product_ids_after_remove = get_product_ids_from_cart_items(order_after_remove)
      assert product_ids_after_remove == [product1.id, product3.id]

      # Re-add product2 via the UI (will get current timestamp, placing it at the end)
      view
      |> element("button[phx-click='add_to_cart'][phx-value-product_id='#{product2.id}']")
      |> render_click()

      # Verify product2 is now at the end (product1, product3, product2)
      html = render(view)
      final_order = extract_cart_item_order(html)
      assert length(final_order) == 3
      final_product_ids = get_product_ids_from_cart_items(final_order)
      assert final_product_ids == [product1.id, product3.id, product2.id]
    end
  end
end