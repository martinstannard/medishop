
defmodule MedishopWeb.LandingLiveTest do
  use MedishopWeb.ConnCase

      import Phoenix.LiveViewTest

    

      @tag :landing_page

      test "renders welcome message and sign-in/register links", %{conn: conn} do

        {:ok, _lv, html} = live(conn, ~p"/")

    

        assert html =~ "Welcome to Medishop"

        assert html =~ "Your trusted source for medical supplies."

                assert html =~ "<a href=\"/sign-in\" class=\"btn btn-primary\">Sign In</a>"

                assert html =~ "<a href=\"/register\" class=\"btn btn-secondary\">Register</a>"

      end
end
