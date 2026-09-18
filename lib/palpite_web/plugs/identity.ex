defmodule PalpiteWeb.Plugs.Identity do
  @moduledoc """
  Toda request tem identidade: cookie assinado válido carrega a
  identidade, qualquer outro caso cria uma na hora e seta o cookie.
  O app nunca tem estado anônimo-sem-identidade — o primeiro hit já
  tem lista (vazia).

  Cookie HttpOnly, SameSite=Lax, max-age de 20 anos (identidade
  anônima pra sempre). O token bruto só existe no cookie e no banner
  de recuperação; o banco guarda só o sha256.
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
      assign(conn, :current_identity, identity)
    else
      _ -> create_and_assign(conn)
    end
  end

  defp create_and_assign(conn) do
    {token, identity} = Identity.create()

    conn
    |> put_resp_cookie(@cookie, token,
      sign: true,
      http_only: true,
      same_site: "Lax",
      max_age: @max_age
    )
    |> assign(:current_identity, identity)
  end
end
