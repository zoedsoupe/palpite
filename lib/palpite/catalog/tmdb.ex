defmodule Palpite.Catalog.Tmdb do
  require Logger

  alias Palpite.Catalog.Entry

  @behaviour Palpite.Catalog

  @genres [
    %{"id" => 12, "name" => "Adventure"},
    %{"id" => 14, "name" => "Fantasy"},
    %{"id" => 16, "name" => "Animation"},
    %{"id" => 18, "name" => "Drama"},
    %{"id" => 27, "name" => "Horror"},
    %{"id" => 28, "name" => "Action"},
    %{"id" => 35, "name" => "Comedy"},
    %{"id" => 36, "name" => "History"},
    %{"id" => 37, "name" => "Western"},
    %{"id" => 53, "name" => "Thriller"},
    %{"id" => 80, "name" => "Crime"},
    %{"id" => 99, "name" => "Documentary"},
    %{"id" => 878, "name" => "Science Fiction"},
    %{"id" => 9648, "name" => "Mystery"},
    %{"id" => 10402, "name" => "Music"},
    %{"id" => 10749, "name" => "Romance"},
    %{"id" => 10751, "name" => "Family"},
    %{"id" => 10752, "name" => "War"},
    %{"id" => 10759, "name" => "Action & Adventure"},
    %{"id" => 10762, "name" => "Kids"},
    %{"id" => 10763, "name" => "News"},
    %{"id" => 10764, "name" => "Reality"},
    %{"id" => 10765, "name" => "Sci-Fi & Fantasy"},
    %{"id" => 10766, "name" => "Soap"},
    %{"id" => 10767, "name" => "Talk"},
    %{"id" => 10768, "name" => "War & Politics"},
    %{"id" => 10770, "name" => "TV Movie"}
  ]

  def genres, do: @genres

  @animation_id Enum.find(@genres, &(&1["name"] == "Animation"))

  @base_url ~c"https://api.themoviedb.org/3"
  @token Application.compile_env!(:palpite, :tmdb_token)

  @impl true
  def search(query) when is_binary(query) do
    params = URI.encode_query(%{include_adult: true, language: "en-US", query: query})
    url = @base_url ++ ~c"/search/multi?" ++ String.to_charlist(params)

    headers = [
      {~c"authorization", ~c"Bearer #{@token}"},
      {~c"accept", ~c"application/json"}
    ]

    case :httpc.request(:get, {url, headers}, [], [{:body_format, :binary}]) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, body |> JSON.decode!() |> parse_entries()}

      {:ok, {{_, status, _}, _, body}} ->
        Logger.warning("TMDB received wrong #{status} status: #{inspect(body)}")
        {:error, :wrong_status}

      {:error, reason} ->
        Logger.error("Failed to query TMDB with: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp parse_entries(%{"results" => results}) do
    for r <- results, r["media_type"] != "person" do
      [year] = Regex.run(~r"\d{4}", r["release_date"] || "0000")

      %Entry{
        tmdb_id: r["id"],
        name: r["title"] || r["name"] || r["original_title"],
        year: year,
        description: r["overview"],
        poster_path: r["poster_path"] || r["backdrop_path"],
        genres: r["genre_ids"],
        type: parse_type(r),
        in_catalog: false
      }
    end
  end

  defp parse_type(%{"media_type" => "movie"}), do: :film

  defp parse_type(%{"media_type" => "tv", "genres" => genres} = r) do
    if animation?(genres) and japanese?(r), do: :anime, else: :cartoon
  end

  defp parse_type(%{"media_type" => "tv"}), do: :series

  defp animation?(genres), do: @animation_id in genres

  defp japanese?(%{"original_language" => lang, "original_country" => countries}),
    do: lang == "ja" or "JP" in countries
end
