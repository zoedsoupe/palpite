defmodule PalpiteWeb.PageController do
  use PalpiteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
