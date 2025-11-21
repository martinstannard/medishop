defmodule MedishopWeb.PageController do
  use MedishopWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
