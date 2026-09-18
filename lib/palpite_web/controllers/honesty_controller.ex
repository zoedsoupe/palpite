defmodule PalpiteWeb.HonestyController do
  use PalpiteWeb, :controller

  def show(conn, _params) do
    render(conn, :show, page_title: "Honestidade", active: :honestidade)
  end
end
