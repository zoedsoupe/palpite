defmodule PalpiteWeb.Plugs.Identity do
  @moduledoc """
  Toda request tem identidade: cookie assinado válido carrega a
  identidade, qualquer outro caso cria uma na hora e seta o cookie.
  O app nunca tem estado anônimo-sem-identidade: o primeiro hit já
  tem lista (vazia).

  Cookie HttpOnly, SameSite=Lax, max-age de 20 anos (identidade
  anônima pra sempre). O token bruto só existe no cookie e no banner
  de recuperação; o banco guarda só o sha256.

  O token também vai em `conn.assigns.current_identity_token`: é ele
  que a tela de "meus títulos" renderiza como código de recuperação,
  e o `live_session/1` repassa pra session dos LiveViews.
  """

  import Plug.Conn

  alias Palpite.Identity

  @cookie "palpite_identity"
  @max_age 60 * 60 * 24 * 365 * 20

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn, signed: [@cookie])

    with token when is_binary(token) <- conn.cookies[@cookie],
         {:ok, identity} <- Identity.fetch(token) do
      Identity.touch(identity)
      assign_identity(conn, identity, token)
    else
      _ -> create_and_assign(conn)
    end
  end

  @doc "Session dos LiveViews do app: só o token bruto importa."
  def live_session(conn) do
    %{"identity_token" => conn.assigns[:current_identity_token]}
  end

  @doc "Seta o cookie de identidade numa conn (usado na recuperação de lista)."
  def put_identity_cookie(conn, token) do
    put_resp_cookie(conn, @cookie, token,
      sign: true,
      http_only: true,
      same_site: "Lax",
      max_age: @max_age
    )
  end

  defp create_and_assign(conn) do
    {token, identity} = Identity.create()

    conn
    |> put_identity_cookie(token)
    |> assign_identity(identity, token)
  end

  defp assign_identity(conn, identity, token) do
    conn
    |> assign(:current_identity, identity)
    |> assign(:current_identity_token, token)
  end
end
