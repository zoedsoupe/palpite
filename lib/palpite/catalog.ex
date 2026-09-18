defmodule Palpite.Catalog do
  @moduledoc """
  Contexto de catálogo: busca e normalização de títulos.

  `search/2` é o único ponto de entrada e sempre devolve `%Entry{}`:
  a LiveView nunca vê mapa cru do TMDB nem `%Title{}` de Ecto. Hits
  locais vêm primeiro porque carregam prova social; com 5 ou mais,
  a chamada ao TMDB é morta e nem sai do lugar. A fonte externa é
  injetável (default `Palpite.Catalog.Tmdb`) pra testar com stub.

  Query com menos de 2 chars retorna `{:ok, []}` sem tocar em nada.
  """

  import Ecto.Query

  alias Palpite.Catalog.Entry
  alias Palpite.Catalog.Title
  alias Palpite.Catalog.Tmdb

  alias Palpite.Repo

  @type type :: :film | :series | :cartoon | :anime
  @type query :: String.t()

  @callback search(query) :: {:ok, list(Entry.t())} | {:error, message :: atom}
  @callback details(tmdb_id :: integer) :: {:ok, Entry.t()} | {:error, message :: atom}

  @tmdb_client Application.compile_env(:palpite, :tmdb_client, Tmdb)

  @doc "Gêneros fixos do TMDB com nome pt-BR, fonte dos chips de filtro."
  @spec genres() :: [%{id: integer, name: String.t()}]
  def genres, do: Tmdb.genres() |> Enum.map(&%{id: &1["id"], name: &1["pt"]})

  def search(query, source \\ @tmdb_client)

  def search(query, _) when byte_size(query) < 2, do: {:ok, []}

  def search(query, source) do
    query = String.trim(query)
    locals = list_titles(query) |> Enum.map(&Entry.from_title/1)
    tmdb_task = Task.Supervisor.async_nolink(TMDBSupervisor, fn -> source.search(query) end)

    if Enum.count(locals) >= 5 do
      Task.shutdown(tmdb_task, :brutal_kill)
      {:ok, locals}
    else
      case Task.await(tmdb_task) do
        {:ok, remote} -> {:ok, locals ++ remote}
        {:error, _} -> {:ok, locals}
      end
    end
  end

  defp list_titles(query) do
    query = "%#{query}%"

    from(t in Title, where: like(t.name, ^query) or like(t.description, ^query))
    |> Repo.all()
  end

  @spec upsert_from_tmdb(tmdb_id :: integer, source :: module) ::
          {:ok, Title.t()} | {:error, term}
  def upsert_from_tmdb(tmdb_id, source \\ @tmdb_client) do
    with {:ok, entry} <- source.details(tmdb_id),
         {:ok, _} <-
           entry
           |> Entry.to_title()
           |> Repo.insert(on_conflict: :nothing, conflict_target: :tmdb_id) do
      {:ok, Repo.get_by!(Title, tmdb_id: tmdb_id)}
    end
  end
end
