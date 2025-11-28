defmodule MedishopWeb.CartLiveTest do
  use MedishopWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medishop.Generator
  import MedishopWeb.LiveViewTestHelpers

  describe "Cart Live" do
    setup do
      # Create organization and location
      org = organization() |> Ash.Generator.generate()
      location = location(organization_id: org.id) |> Ash.Generator.generate()
      
      # Create user and grant access
      user = user() |> Ash.Generator.generate()
      organization_membership(user_id: user.id, organization_id: org.id, org_roles: [:org_buyer]) |> Ash.Generator.generate()
      # Need to get the membership ID to create location membership
      {:ok, memberships} = Medishop.Organizations.get_memberships_for_user(user.id)
      membership = hd(memberships)
      
      organization_location_membership(organization_membership_id: membership.id, location_id: location.id) |> Ash.Generator.generate()

      # Create product
      product = product(%{price: Decimal.new("100.00"), active: true}) |> Ash.Generator.generate()

      # Create voucher
      voucher = voucher(%{
        name: "Test Voucher",
        code: "TEST10",
        discount_type: :percentage,
        discount_value: Decimal.new("10.00"), # 10%
        active: true,
        usage_limit_total: nil
      }) |> Ash.Generator.generate()

      # Log in user
      conn = log_in_user(build_conn(), user)

      %{conn: conn, location: location, product: product, voucher: voucher, user: user}
    end

    test "can apply voucher code", %{conn: conn, location: location, product: product, voucher: voucher} do
      # Add item to cart first
      {:ok, cart} = Medishop.Shop.get_or_create_cart_for_location(location.id)
      Medishop.Shop.add_or_update_cart_item(cart.id, product.id, 1)

      {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")

      # Assert cart has item
      # Use a looser selector if data-testid is complex or just check content
      assert has_element?(view, "div", product.title)
      
      # Submit voucher form
      view
      |> form("form[phx-submit=apply_voucher]", %{code: voucher.code})
      |> render_submit()

      # Check for success message
      assert render(view) =~ "Voucher &#39;TEST10&#39; applied!"
      
      # Check if discount is visible
      assert has_element?(view, "span", "-$10.00") # 10% of 100
    end
    
    test "shows error for invalid voucher", %{conn: conn, location: location, product: product} do
       # Add item to cart to ensure cart exists/renders fully
       {:ok, cart} = Medishop.Shop.get_or_create_cart_for_location(location.id)
       Medishop.Shop.add_or_update_cart_item(cart.id, product.id, 1)

       {:ok, view, _html} = live(conn, ~p"/location/#{location.id}/cart")
       
       view
       |> form("form[phx-submit=apply_voucher]", %{code: "INVALID"})
       |> render_submit()
       
       assert render(view) =~ "Voucher not found"
    end
  end
end