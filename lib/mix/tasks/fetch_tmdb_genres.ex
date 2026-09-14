defmodule Mix.Tasks.FetchTmdbGenres do
  @moduledoc """
  Busca as listas de gêneros de movie e tv no TMDB, deduplica por id,
  ordena e imprime.

  Serve pra regenerar a tabela hardcoded de gêneros do
  `Palpite.Catalog.Tmdb` quando o TMDB mudar a lista (raro). Não roda
  em runtime, é task de manutenção.
  """

  require Logger

  @sources ~w(movie tv)
  @endpoints for s <- @sources, do: "https://api.themoviedb.org/3/genre/#{s}/list"

  def run(_) do
    {:ok, pid} = Task.Supervisor.start_link()
    token = Application.fetch_env!(:palpite, :tmdb_token)

    pid
    |> Task.Supervisor.async_stream_nolink(@endpoints, &fetch_genres(&1, token),
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, v} -> v end)
    |> List.flatten()
    |> Enum.uniq_by(fn %{"id" => id} -> id end)
    |> Enum.sort_by(& &1["id"])
    |> IO.inspect()
  end

  defp fetch_genres(url, token) do
    url = String.to_charlist(url)

    headers = [
      {~c"authorization", ~c"Bearer #{token}"},
      {~c"accept", ~c"application/json"}
    ]

    case :httpc.request(:get, {url, headers}, [], [{:body_format, :binary}]) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body |> JSON.decode!() |> parse_genres()

      {:ok, {{_, status, _}, _headers, body}} ->
        Logger.warning("Failed with #{status} and #{inspect(body)}")
        exit("tmdb returned status #{status}")

      {:error, reason} ->
        exit("Failed with: #{inspect(reason)}")
    end
  end

  defp parse_genres(%{"genres" => genres}), do: genres
  defp parse_genres(_), do: raise("invalid body")
end
