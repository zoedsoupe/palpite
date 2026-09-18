defmodule PalpiteWeb.Hooks.Identity do
  @moduledoc """
  `on_mount` da live_session do app: recarrega a identidade a partir do
  token que o plug pôs na session (`identity_token`) e o mantém em
  `identity_token` pra tela renderizar o código de recuperação.

  Token sem identidade no banco (banco resetado, token forjado) manda
  de volta pra `/`: o plug recria a identidade e o cookie na próxima
  request.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias Palpite.Identity

  def on_mount(:default, _params, %{"identity_token" => token}, socket) do
    case Identity.fetch(token) do
      {:ok, identity} ->
        {:cont, assign(socket, current_identity: identity, identity_token: token)}

      {:error, :not_found} ->
        {:halt, redirect(socket, to: "/")}
    end
  end
end
