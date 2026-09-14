defmodule Palpite.Catalog.Entry do
  @moduledoc """
  Struct de borda do catálogo.

  Todo resultado de busca, local ou remoto, sai do contexto como `%Entry{}`.
  `in_catalog` marca se já existe linha local: esses hits voltam primeiro na
  busca porque carregam prova social. `from_title/1` resolve IDs de gênero
  pra nomes usando a tabela hardcoded do `Palpite.Catalog.Tmdb`; ID
  desconhecido é descartado em silêncio, nunca quebra.
  """

  alias Palpite.Catalog.Title
  alias Palpite.Catalog.Tmdb

  @type t :: %__MODULE__{
          tmdb_id: String.t(),
          type: Palpite.Catalog.type(),
          name: String.t(),
          year: integer(),
          description: String.t(),
          poster_path: String.t(),
          # frontend will consume it
          genres: list(String.t() | integer),
          in_catalog: boolean
        }

  defstruct [:tmdb_id, :type, :name, :description, :year, :poster_path, :genres, :in_catalog]

  def to_title(%__MODULE__{in_catalog: false} = e) do
    Title.changeset(%Title{}, %{
      tmdb_id: e.tmdb_id,
      type: e.type,
      name: e.name,
      year: e.year,
      poster_path: e.poster_path,
      description: e.description,
      genres: e.genres
    })
  end

  def from_title(%Title{} = t) do
    genres = Tmdb.genres()

    %__MODULE__{
      tmdb_id: t.tmdb_id,
      type: t.type,
      name: t.name,
      year: t.year,
      poster_path: t.poster_path,
      genres: Enum.flat_map(t.genres, &fetch_genre_name(&1, genres)),
      description: t.description,
      in_catalog: true
    }
  end

  defp fetch_genre_name(genre, genres) do
    if genre = Enum.find(genres, &(&1["id"] == genre)) do
      [genre["name"]]
    else
      []
    end
  end
end
