defmodule PalpiteWeb.RecoveryController do
  use PalpiteWeb, :controller

  alias Palpite.Identity
  alias PalpiteWeb.Plugs.Identity, as: IdentityPlug

  def new(conn, _params) do
    render(conn, :new, page_title: "Recuperar minha lista", active: :recuperar)
  end

  def create(conn, %{"code" => code}) do
    code = String.trim(code)

    case Identity.fetch(code) do
      {:ok, _identity} ->
        conn
        |> IdentityPlug.put_identity_cookie(code)
        |> put_flash(:info, "Lista recuperada. Boas vindas de volta.")
        |> redirect(to: ~p"/meus-titulos")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Código não encontrado. Confere e tenta de novo.")
        |> redirect(to: ~p"/recuperar")
    end
  end
end
