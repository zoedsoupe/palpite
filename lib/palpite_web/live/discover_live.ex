defmodule PalpiteWeb.DiscoverLive do
  use PalpiteWeb, :live_view

  alias Palpite.Catalog
  alias Palpite.Recommender
  alias Palpite.Taste

  @min_titles 3

  def mount(_params, _session, socket) do
    entries = Taste.list(socket.assigns.current_identity)

    socket =
      assign(socket,
        page_title: "Descobrir",
        active: :descobrir,
        entries_count: length(entries),
        genres: Catalog.genres(),
        format: nil,
        genre_ids: [],
        sheet_open: false,
        pool: [],
        idx: 0,
        state: :gate
      )

    if length(entries) < @min_titles do
      {:ok, socket}
    else
      {:ok, load_pool(socket)}
    end
  end

  def handle_event("open_sheet", _params, socket),
    do: {:noreply, assign(socket, sheet_open: true)}

  def handle_event("close_sheet", _params, socket),
    do: {:noreply, assign(socket, sheet_open: false)}

  def handle_event("set_format", %{"format" => "tudo"}, socket),
    do: {:noreply, assign(socket, format: nil)}

  def handle_event("set_format", %{"format" => format}, socket),
    do: {:noreply, assign(socket, format: String.to_existing_atom(format))}

  def handle_event("toggle_genre", %{"id" => id}, socket) do
    id = String.to_integer(id)
    ids = socket.assigns.genre_ids

    ids = if id in ids, do: List.delete(ids, id), else: [id | ids]
    {:noreply, assign(socket, genre_ids: ids)}
  end

  def handle_event("apply_filters", _params, socket) do
    {:noreply, socket |> assign(sheet_open: false) |> load_pool()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, socket |> assign(format: nil, genre_ids: [], sheet_open: false) |> load_pool()}
  end

  def handle_event("next", _params, socket) do
    {:noreply, advance(socket)}
  end

  def handle_event("like", _params, socket) do
    current = current_rec(socket.assigns)

    case current && Taste.add(socket.assigns.current_identity, current.title.tmdb_id) do
      {:ok, _} ->
        {:noreply, socket |> assign(entries_count: socket.assigns.entries_count + 1) |> advance()}

      _ ->
        {:noreply, put_flash(socket, :error, "Algo quebrou, tente de novo.")}
    end
  end

  defp load_pool(socket) do
    opts = [
      type: socket.assigns.format,
      genres: if(socket.assigns.genre_ids == [], do: nil, else: socket.assigns.genre_ids)
    ]

    {:ok, pool} = Recommender.recommend(socket.assigns.current_identity, opts)

    assign(socket, pool: pool, idx: 0, state: if(pool == [], do: :empty, else: :rec))
  end

  defp advance(socket) do
    idx = socket.assigns.idx + 1

    if idx >= length(socket.assigns.pool) do
      assign(socket, idx: idx, state: :end)
    else
      assign(socket, idx: idx, state: :rec)
    end
  end

  defp current_rec(assigns) do
    Enum.at(assigns.pool, assigns.idx)
  end

  defp provenance_sentence(provenance) do
    names =
      provenance.top_pairs
      |> Enum.take(2)
      |> Enum.map(& &1.name)

    case names do
      [] ->
        "#{provenance.total} pessoas com gosto parecido com o seu também amaram este."

      [one] ->
        "#{provenance.total} pessoas que curtiram #{one} também amaram este."

      [first, second] ->
        "#{provenance.total} pessoas que curtiram #{first} e #{second} também amaram este."
    end
  end

  def render(assigns) do
    ~H"""
    <div class="discover">
      <aside class={["discover-sidebar", @state == :gate && "is-locked"]}>
        <div class="stack">
          <.filter_groups format={@format} genre_ids={@genre_ids} genres={@genres} variant={:sidebar} />

          <div class="sidebar-note">
            <p>
              Com base em
              <strong>{@entries_count} {if @entries_count == 1, do: "título", else: "títulos"}</strong>
              da sua lista.
            </p>
          </div>
        </div>
      </aside>

      <main class="discover-main">
        <button
          :if={@state != :gate}
          type="button"
          phx-click="open_sheet"
          class="filters-trigger"
        >
          Filtros <Lucideicons.sliders_horizontal class="icon" />
        </button>

        <.gate_panel :if={@state == :gate} entries_count={@entries_count} />
        <.empty_panel :if={@state == :empty} />
        <.end_panel :if={@state == :end} />
        <.rec_card
          :if={@state == :rec}
          rec={current_rec(assigns)}
          genres={@genres}
        />
      </main>
    </div>

    <div :if={@sheet_open} class="sheet" role="dialog" aria-modal="true">
      <div class="sheet-overlay" phx-click="close_sheet"></div>
      <div class="sheet-panel">
        <div class="sheet-handle"></div>
        <.filter_groups format={@format} genre_ids={@genre_ids} genres={@genres} variant={:sheet} />
        <button type="button" phx-click="apply_filters" class="btn btn-primary btn-lg btn-block">
          Aplicar filtros
        </button>
      </div>
    </div>
    """
  end

  attr :format, :atom, required: true
  attr :genre_ids, :list, required: true
  attr :genres, :list, required: true
  attr :variant, :atom, required: true, values: [:sidebar, :sheet]

  defp filter_groups(assigns) do
    ~H"""
    <div class="filter-group">
      <div class="stack">
        <h3 class="section-label">Formato</h3>

        <div :if={@variant == :sidebar} class="format-list">
          <button
            type="button"
            phx-click="set_format"
            phx-value-format="tudo"
            class="format-option"
            aria-pressed={to_string(is_nil(@format))}
          >
            <span class="format-box"></span> Tudo
          </button>
          <button
            :for={{value, label} <- type_options()}
            type="button"
            phx-click="set_format"
            phx-value-format={value}
            class="format-option"
            aria-pressed={to_string(@format == value)}
          >
            <span class="format-box"></span> {label}
          </button>
        </div>

        <div :if={@variant == :sheet} class="sheet-format-grid">
          <button
            type="button"
            phx-click="set_format"
            phx-value-format="tudo"
            class="format-btn"
            aria-pressed={to_string(is_nil(@format))}
          >
            Tudo
          </button>
          <button
            :for={{value, label} <- type_options()}
            type="button"
            phx-click="set_format"
            phx-value-format={value}
            class="format-btn"
            aria-pressed={to_string(@format == value)}
          >
            {label}
          </button>
        </div>
      </div>

      <div class="stack">
        <h3 class="section-label">Gêneros</h3>
        <div class="chip-list">
          <button
            :for={genre <- @genres}
            type="button"
            phx-click="toggle_genre"
            phx-value-id={genre.id}
            class="chip"
            aria-pressed={to_string(genre.id in @genre_ids)}
          >
            {genre.name}
          </button>
        </div>
      </div>

      <button
        :if={@variant == :sidebar}
        type="button"
        phx-click="apply_filters"
        class="btn btn-primary btn-md btn-block"
      >
        Aplicar filtros
      </button>
    </div>
    """
  end

  attr :entries_count, :integer, required: true

  defp gate_panel(assigns) do
    ~H"""
    <div class="state-panel">
      <h2 class="state-title">
        {if @entries_count == 0, do: "Sua lista ainda está vazia.", else: "Quase lá."}
      </h2>
      <p class="state-copy">
        Não podemos dar um pitaco sem saber o que você gosta. Adicione pelo menos 3 títulos para desbloquear suas primeiras recomendações.
      </p>
      <div class="state-actions">
        <a href={~p"/meus-titulos"} class="btn btn-primary btn-lg">Montar minha lista</a>
      </div>
      <div class="state-posters" aria-hidden="true">
        <span class="slot"></span>
        <span class="slot"></span>
        <span class="slot"></span>
      </div>
    </div>
    """
  end

  defp empty_panel(assigns) do
    ~H"""
    <div class="state-panel">
      <h2 class="state-title">Não encontramos nenhum pitaco.</h2>
      <p class="state-copy">
        Pode ser que seus filtros estejam muito restritivos ou que o seu gosto seja tão único que ainda não temos pessoas com a mesma combinação na nossa base.
      </p>
      <div class="state-actions">
        <button type="button" phx-click="clear_filters" class="btn btn-primary btn-lg">
          Limpar filtros
        </button>
        <p class="state-note">
          ou <a href={~p"/meus-titulos"}>adicione mais títulos</a> para aumentar as chances
        </p>
      </div>
      <div class="state-dashes" aria-hidden="true">
        <span></span>
        <span></span>
        <span></span>
      </div>
    </div>
    """
  end

  defp end_panel(assigns) do
    ~H"""
    <div class="state-panel">
      <h2 class="state-title">Você chegou ao fim dos pitacos.</h2>
      <p class="state-copy">
        Já te mostramos todas as recomendações disponíveis baseadas na sua lista atual. O algoritmo coletivo precisa de mais referências suas para encontrar novos caminhos.
      </p>
      <div class="state-actions">
        <a href={~p"/meus-titulos"} class="btn btn-primary btn-lg">Gerenciar minha lista</a>
        <p class="state-note">Adicione pelo menos mais 2 títulos que você ama</p>
      </div>
      <div class="state-posters" aria-hidden="true">
        <span class="slot-done"><Lucideicons.check class="icon" /></span>
        <span class="slot-done"><Lucideicons.check class="icon" /></span>
        <span class="slot-done"><Lucideicons.check class="icon" /></span>
      </div>
    </div>
    """
  end

  attr :rec, :map, required: true
  attr :genres, :list, required: true

  defp rec_card(assigns) do
    ~H"""
    <div class="rec-card">
      <div class="rec-hero">
        <img
          :if={card(@rec.title.poster_path)}
          src={card(@rec.title.poster_path)}
          alt={"Pôster de #{@rec.title.name}"}
        />
        <div :if={is_nil(card(@rec.title.poster_path))} class="poster-blank"></div>
      </div>

      <div class="rec-body">
        <div class="rec-meta">
          <span :if={@rec.title.year}>{@rec.title.year}</span>
          <span :if={@rec.title.year} class="rec-meta-sep"></span>
          <span>{type_label(@rec.title.type)}</span>
        </div>

        <h2 class="rec-title">{@rec.title.name}</h2>

        <p class="rec-provenance">
          {provenance_sentence(@rec.provenance)}
        </p>

        <details class="rec-why">
          <summary>Por que este?</summary>
          <ul>
            <li :for={pair <- @rec.provenance.top_pairs}>
              {pair.count} pessoas curtiram <strong>{pair.name}</strong> junto com este título.
            </li>
          </ul>
        </details>

        <div class="rec-actions">
          <button type="button" phx-click="like" class="btn btn-primary">Gostei</button>
          <button type="button" phx-click="next" class="btn btn-outline">Não é pra mim</button>
        </div>
      </div>
    </div>
    """
  end
end
