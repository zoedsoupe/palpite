defmodule Palpite.Catalog.Tmdb do
  @moduledoc """
  Cliente TMDB via `:httpc`, implementação default do behaviour `Catalog`.

  Gêneros ficam hardcoded em `@genres`: o mapeamento ID->nome do TMDB é
  minúsculo e estável, então sem tabela no banco nem fetch em runtime
  (`mix fetch_tmdb_genres` regenera a lista se um dia precisar).

  O TMDB só conhece movie/tv, então o tipo é derivado: `movie` vira `:film`
  (filme de anime é `:film`), `tv` com gênero Animation e origem japonesa
  vira `:anime`, Animation sem JP vira `:cartoon`, o resto é `:series`.
  No `search/multi` é best-effort porque nem sempre vem país de origem.

  Não existe endpoint de details "multi": `details/1` dispara `/tv/:id` e
  `/movie/:id` em paralelo - um sempre 404, o outro traz o payload completo
  (sempre com `origin_country`), e a classificação autoritativa acontece
  nesse vencedor. Se os dois falham, sobe o erro mais informativo.

  Status inesperado ou falha de rede vira `{:error, _}` com log: quem chama
  degrada pros resultados locais e a UI nem fica sabendo que o TMDB caiu.
  """

  require Logger

  alias Palpite.Catalog.Entry

  @behaviour Palpite.Catalog

  @genres [
    %{"id" => 12, "name" => "Adventure", "pt" => "Aventura"},
    %{"id" => 14, "name" => "Fantasy", "pt" => "Fantasia"},
    %{"id" => 16, "name" => "Animation", "pt" => "Animação"},
    %{"id" => 18, "name" => "Drama", "pt" => "Drama"},
    %{"id" => 27, "name" => "Horror", "pt" => "Terror"},
    %{"id" => 28, "name" => "Action", "pt" => "Ação"},
    %{"id" => 35, "name" => "Comedy", "pt" => "Comédia"},
    %{"id" => 36, "name" => "History", "pt" => "História"},
    %{"id" => 37, "name" => "Western", "pt" => "Faroeste"},
    %{"id" => 53, "name" => "Thriller", "pt" => "Suspense"},
    %{"id" => 80, "name" => "Crime", "pt" => "Crime"},
    %{"id" => 99, "name" => "Documentary", "pt" => "Documentário"},
    %{"id" => 878, "name" => "Science Fiction", "pt" => "Ficção científica"},
    %{"id" => 9648, "name" => "Mystery", "pt" => "Mistério"},
    %{"id" => 10402, "name" => "Music", "pt" => "Música"},
    %{"id" => 10749, "name" => "Romance", "pt" => "Romance"},
    %{"id" => 10751, "name" => "Family", "pt" => "Família"},
    %{"id" => 10752, "name" => "War", "pt" => "Guerra"},
    %{"id" => 10759, "name" => "Action & Adventure", "pt" => "Ação e aventura"},
    %{"id" => 10762, "name" => "Kids", "pt" => "Infantil"},
    %{"id" => 10763, "name" => "News", "pt" => "Notícias"},
    %{"id" => 10764, "name" => "Reality", "pt" => "Reality"},
    %{"id" => 10765, "name" => "Sci-Fi & Fantasy", "pt" => "Sci-fi e fantasia"},
    %{"id" => 10766, "name" => "Soap", "pt" => "Novela"},
    %{"id" => 10767, "name" => "Talk", "pt" => "Talk show"},
    %{"id" => 10768, "name" => "War & Politics", "pt" => "Guerra e política"},
    %{"id" => 10770, "name" => "TV Movie", "pt" => "Filme de TV"}
  ]

  def genres, do: @genres

  @animation_id @genres |> Enum.find(&(&1["name"] == "Animation")) |> Map.fetch!("id")

  @base_url ~c"https://api.themoviedb.org/3"

  defp token do
    Application.fetch_env!(:palpite, :tmdb_token)
  end

  @impl true
  def search(query) when is_binary(query) do
    params = %{include_adult: true, language: "en-US", query: query}

    with {:ok, body} <- get(~c"/search/multi", params) do
      {:ok, parse_entries(body)}
    end
  end

  defp get(path, params) do
    query = URI.encode_query(params)
    url = @base_url ++ path ++ ~c"?" ++ String.to_charlist(query)

    headers = [
      {~c"authorization", ~c"Bearer #{token()}"},
      {~c"accept", ~c"application/json"}
    ]

    case :httpc.request(:get, {url, headers}, [], [{:body_format, :binary}]) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, JSON.decode!(body)}

      {:ok, {{_, 404, _}, _, _}} ->
        {:error, :not_found}

      {:ok, {{_, status, _}, _, body}} ->
        Logger.warning("TMDB received wrong #{status} status: #{inspect(body)}")
        {:error, :wrong_status}

      {:error, reason} ->
        Logger.error("Failed to query TMDB with: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp parse_entries(%{"results" => results}) do
    for r <- results, r["media_type"] != "person", do: parse_entry(r)
  end

  defp parse_entry(r) do
    %Entry{
      tmdb_id: r["id"],
      name: r["title"] || r["name"] || r["original_title"],
      year: year_from(r["release_date"] || r["first_air_date"]),
      description: r["overview"],
      poster_path: r["poster_path"] || r["backdrop_path"],
      genres: r["genre_ids"],
      type: parse_type(r),
      in_catalog: false
    }
  end

  # search/multi nem sempre traz país de origem: classificação best-effort,
  # a autoritativa acontece em parse_details/2
  defp parse_type(%{"media_type" => "movie"}), do: :film
  defp parse_type(%{"media_type" => "tv", "genre_ids" => ids} = r), do: classify(:tv, ids, r)
  defp parse_type(%{"media_type" => "tv"}), do: :series

  defp japanese?(%{"original_language" => "ja"}), do: true
  defp japanese?(%{"origin_country" => countries}), do: "JP" in countries
  defp japanese?(_), do: false

  defp year_from(date) when is_binary(date) do
    case Regex.run(~r"\d{4}", date) do
      [year] -> String.to_integer(year)
      _ -> nil
    end
  end

  defp year_from(_), do: nil

  @impl true
  def details(tmdb_id) do
    results =
      TMDBSupervisor
      |> Task.Supervisor.async_stream_nolink(
        [:tv, :movie],
        &details_req(tmdb_id, &1),
        ordered: false,
        on_timeout: :kill_task
      )
      |> Enum.flat_map(fn
        {:ok, res} -> [res]
        _ -> []
      end)

    Enum.find(results, &match?({:ok, _}, &1)) ||
      Enum.find(results, {:error, :not_found}, &(&1 != {:error, :not_found}))
  end

  defp details_req(tmdb_id, media) do
    with {:ok, body} <- get(~c"/#{media}/#{tmdb_id}", %{language: "en-US"}) do
      {:ok, parse_details(body, media)}
    end
  end

  defp parse_details(r, media) do
    genre_ids = Enum.map(r["genres"] || [], & &1["id"])

    %Entry{
      tmdb_id: r["id"],
      name: r["title"] || r["name"],
      year: year_from(r["release_date"] || r["first_air_date"]),
      description: r["overview"],
      poster_path: r["poster_path"],
      genres: genre_ids,
      type: classify(media, genre_ids, r),
      in_catalog: false
    }
  end

  # autoritativa: payloads de details sempre trazem origin_country
  defp classify(:movie, _ids, _r), do: :film

  defp classify(:tv, ids, r) do
    cond do
      @animation_id in ids and japanese?(r) -> :anime
      @animation_id in ids -> :cartoon
      true -> :series
    end
  end
end
