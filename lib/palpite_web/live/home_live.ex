defmodule PalpiteWeb.HomeLive do
  use PalpiteWeb, :live_view

  alias Palpite.Taste

  def mount(_params, _session, socket) do
    count = length(Taste.list(socket.assigns.current_identity))

    {:ok, assign(socket, page_title: "Início", active: :home, titles_count: count)}
  end

  def render(assigns) do
    ~H"""
    <div class="home-hero">
      <h1 class="home-title">Indicações de filmes e séries baseadas em gosto real.</h1>

      <p class="home-sub">
        Esqueça os algoritmos de retenção. O Pitaco conecta o que você ama ao que pessoas com o mesmo gosto também amaram.
      </p>

      <div class="home-ctas">
        <a href={~p"/descobrir"} class="btn btn-primary btn-lg">Quero um pitaco</a>
        <a href={~p"/meus-titulos"} class="btn btn-outline btn-lg">Dar meus pitacos</a>
      </div>

      <p class="home-count">
        Você tem
        <strong>{@titles_count} {if @titles_count == 1, do: "título", else: "títulos"}</strong>
        salvos no navegador.
      </p>

      <p class="home-count">
        Trocou de aparelho? <a href={~p"/recuperar"}>Recupere sua lista de pitacos</a>.
      </p>

      <div class="home-posters" aria-hidden="true">
        <span></span>
        <span></span>
        <span></span>
      </div>
    </div>
    """
  end
end
