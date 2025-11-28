defmodule MedishopWeb.PageControllerTest do
  use MedishopWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to Medishop"
  end
end
