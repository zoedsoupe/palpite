defmodule PalpiteWeb.MyTitlesLive do
  use PalpiteWeb, :live_view

  alias Palpite.Catalog
  alias Palpite.Taste

  @min_titles 3

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Meus títulos",
       active: :meus_titulos,
       entries: Taste.list(socket.assigns.current_identity),
       query: "",
       results: [],
       pending_tmdb: nil,
       show_recovery: false,
       show_banner: false
     )}
  end

  def handle_event("search", %{"q" => query}, socket) do
    query = String.trim(query)

    if byte_size(query) < 2 do
      {:noreply, assign(socket, query: query, results: [])}
    else
      {:ok, results} = Catalog.search(query)
      {:noreply, assign(socket, query: query, results: results)}
    end
  end

  def handle_event("toggle", %{"tmdb-id" => tmdb_id}, socket) do
    tmdb_id = String.to_integer(tmdb_id)
    identity = socket.assigns.current_identity

    case Enum.find(socket.assigns.entries, &(&1.title.tmdb_id == tmdb_id)) do
      nil -> add_title(socket, identity, tmdb_id)
      entry -> remove_title(socket, identity, entry)
    end
  end

  def handle_event("toggle_recovery", _params, socket) do
    {:noreply, assign(socket, show_recovery: not socket.assigns.show_recovery)}
  end

  def handle_event("dismiss_banner", _params, socket) do
    {:noreply, assign(socket, show_banner: false)}
  end

  defp add_title(socket, identity, tmdb_id) do
    entry = Enum.find(socket.assigns.results, &(&1.tmdb_id == tmdb_id))

    socket = assign(socket, pending_tmdb: tmdb_id)
    result = entry && Taste.add(identity, entry)

    case result do
      {:ok, _} ->
        {:noreply, refresh(socket, added: true)}

      _ ->
        {:noreply,
         socket
         |> assign(pending_tmdb: nil)
         |> put_flash(:error, "Algo quebrou, tente de novo.")}
    end
  end

  defp remove_title(socket, identity, entry) do
    :ok = Taste.remove(identity, entry.title_id)
    {:noreply, refresh(socket)}
  end

  defp refresh(socket, opts \\ []) do
    entries = Taste.list(socket.assigns.current_identity)

    show_banner =
      socket.assigns.show_banner or
        (Keyword.get(opts, :added, false) and length(entries) == @min_titles)

    assign(socket, entries: entries, pending_tmdb: nil, show_banner: show_banner)
  end

  defp liked?(entries, tmdb_id), do: Enum.any?(entries, &(&1.title.tmdb_id == tmdb_id))

  defp unlocked?(entries), do: length(entries) >= @min_titles

  def render(assigns) do
    ~H"""
    <div class="my-titles">
      <section class="my-titles-main">
        <div class="stack" style="--stack-space: var(--space-2)">
          <h1>O que você mais gosta?</h1>
          <p class="page-sub">
            Pesquise e selecione os títulos que você ama. É com eles que cruzamos seu gosto com o de outras pessoas.
          </p>
        </div>

        <div :if={@show_banner} class="banner">
          <p class="banner-title">Guarde seu código de recuperação</p>
          <p class="status-copy">
            Ele é a única forma de recuperar sua lista em outro navegador ou aparelho.
          </p>
          <div class="recovery-box">
            <span class="recovery-token">{@identity_token}</span>
          </div>
          <button type="button" phx-click="dismiss_banner" class="btn btn-outline btn-md">
            Já guardei
          </button>
        </div>

        <form phx-change="search" phx-submit="search" class="search" role="search">
          <Lucideicons.search class="icon" />
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="Buscar filmes ou séries..."
            class="search-input"
            phx-debounce="300"
            autocomplete="off"
          />
        </form>

        <div :if={@query != ""} class="result-list">
          <h2 class="section-label">Resultados da busca</h2>
          <.result_row
            :for={result <- @results}
            result={result}
            liked={liked?(@entries, result.tmdb_id)}
            pending={@pending_tmdb == result.tmdb_id}
          />
          <div :if={@results == []} class="empty-state">
            <p>Nada por aqui. Confere a grafia?</p>
          </div>
        </div>

        <div :if={@query == "" and @entries != []} class="result-list">
          <h2 class="section-label">Seus títulos selecionados</h2>
          <.entry_row :for={entry <- @entries} entry={entry} />
        </div>

        <div :if={@query == "" and @entries == []} class="empty-state">
          <div class="empty-circle">
            <Lucideicons.plus class="icon" />
          </div>
          <p>Sua lista está vazia</p>
          <p>Pesquise acima para adicionar seu primeiro título fundamental.</p>
        </div>
      </section>

      <aside class="my-titles-aside">
        <.status_card :if={not unlocked?(@entries)} entries={@entries} />

        <a :if={unlocked?(@entries)} href={~p"/descobrir"} class="cta-card">
          <div>
            <p class="cta-card-title">Pitacos liberados</p>
            <p class="cta-card-sub">Sua lista tem o mínimo necessário.</p>
          </div>
          <Lucideicons.arrow_right class="icon" />
        </a>

        <div class="stack">
          <button type="button" phx-click="toggle_recovery" class="recovery-toggle">
            <Lucideicons.key class="icon" />
            {if @show_recovery,
              do: "Ocultar código de recuperação",
              else: "Exibir código de recuperação"}
          </button>

          <div :if={@show_recovery} class="stack" style="--stack-space: var(--space-3)">
            <div class="recovery-box">
              <span class="recovery-token">{@identity_token}</span>
            </div>
            <p class="recovery-hint">
              Guarde este código. Sem ele, você perde sua lista se limpar os dados do navegador.
            </p>
          </div>
        </div>
      </aside>
    </div>

    <div :if={unlocked?(@entries)} class="mobile-cta">
      <a href={~p"/descobrir"} class="btn btn-primary btn-lg btn-block">Ver meus pitacos</a>
    </div>
    """
  end

  attr :result, Palpite.Catalog.Entry, required: true
  attr :liked, :boolean, required: true
  attr :pending, :boolean, required: true

  defp result_row(assigns) do
    ~H"""
    <div class="result-row">
      <div class="row-info">
        <img
          :if={thumb(@result.poster_path)}
          class="row-thumb"
          src={thumb(@result.poster_path)}
          alt={"Pôster de #{@result.name}"}
          loading="lazy"
        />
        <div>
          <h3 class="row-name">{@result.name}</h3>
          <p class="row-meta">
            {[@result.year, type_label(@result.type)] |> Enum.reject(&is_nil/1) |> Enum.join(" • ")}
          </p>
        </div>
      </div>
      <button
        type="button"
        phx-click="toggle"
        phx-value-tmdb-id={@result.tmdb_id}
        class="btn-pill"
        aria-pressed={to_string(@liked)}
        disabled={@pending}
      >
        <span :if={@pending} class="spinner"></span>
        <Lucideicons.check :if={@liked and not @pending} class="icon" />
        {if @liked, do: "curtido", else: "eu gosto disso"}
      </button>
    </div>
    """
  end

  attr :entry, Palpite.Taste.TasteEntry, required: true

  defp entry_row(assigns) do
    ~H"""
    <div class="result-row">
      <div class="row-info">
        <img
          :if={thumb(@entry.title.poster_path)}
          class="row-thumb"
          src={thumb(@entry.title.poster_path)}
          alt={"Pôster de #{@entry.title.name}"}
          loading="lazy"
        />
        <div>
          <h3 class="row-name">{@entry.title.name}</h3>
          <p class="row-meta">
            {[@entry.title.year, type_label(@entry.title.type)]
            |> Enum.reject(&is_nil/1)
            |> Enum.join(" • ")}
          </p>
        </div>
      </div>
      <button
        type="button"
        phx-click="toggle"
        phx-value-tmdb-id={@entry.title.tmdb_id}
        class="btn-pill"
        aria-pressed="true"
      >
        <Lucideicons.check class="icon" /> curtido
      </button>
    </div>
    """
  end

  attr :entries, :list, required: true

  defp status_card(assigns) do
    count = length(assigns.entries)
    missing = @min_titles - count

    assigns =
      assign(assigns,
        count: count,
        missing: missing,
        preview: Enum.take(assigns.entries, 4)
      )

    ~H"""
    <div class="status-card stack">
      <div class="stack" style="--stack-space: var(--space-2)">
        <h2 class="status-title">
          {@count} {if @count == 1, do: "título", else: "títulos"}. Falta {if @missing == 1,
            do: "1",
            else: @missing} para desbloquear.
        </h2>
        <p class="status-copy">
          Precisamos de pelo menos 3 títulos salvos para calcular combinações estatísticas sem distorções.
        </p>
      </div>

      <div :if={@preview != []} class="stack" style="--stack-space: var(--space-3)">
        <h3 class="section-label">Sua lista atual</h3>
        <div class="mini-grid">
          <div :for={entry <- @preview} class="mini-poster">
            <img
              :if={card(entry.title.poster_path)}
              src={card(entry.title.poster_path)}
              alt={"Pôster de #{entry.title.name}"}
              loading="lazy"
            />
            <div :if={is_nil(card(entry.title.poster_path))} class="poster-blank"></div>
            <p>{entry.title.name}</p>
          </div>
          <div class="mini-add">
            <Lucideicons.plus class="icon" />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
