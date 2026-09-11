defmodule Palpite.Catalog do
  @moduledoc """

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
