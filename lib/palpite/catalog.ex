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
  @callback details(tmdb_id :: String.t()) :: {:ok, Entry.t()} | {:error, message :: atom}

  def search(query, source \\ Tmdb)

  def search(query, _) when byte_size(query) < 2, do: {:ok, []}

  def search(query, source) do
    query = String.trim(query)
    locals = list_titles(query) |> Enum.map(&Entry.from_title/1)
    tmdb_task = Task.Supervisor.async_nolink(TMDBSupervisor, fn -> source.search(query) end)

    if Enum.count(locals) >= 5 do
      Task.shutdown(tmdb_task, :brutal_kill)
      {:ok, locals}
    else
      {:ok, tmdb} = Task.await(tmdb_task)
      {:ok, locals ++ tmdb}
    end
  end

  defp list_titles(query) do
    query = "%#{query}%"

    from(t in Title, where: like(t.name, ^query) or like(t.description, ^query))
    |> Repo.all()
  end
end
