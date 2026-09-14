defmodule Palpite.Catalog.Title do
  @moduledoc """
  Schema de título persistido no catálogo local.

  Guarda `poster_path` cru: a URL completa é montada na camada de view
  (`https://image.tmdb.org/t/p/w342`), hotlink direto do TMDB, nunca proxy.
  `genres` fica como lista de IDs do TMDB; a tradução pra nome acontece na
  borda, em `Palpite.Catalog.Entry.from_title/1`, sem tabela de gêneros
  no banco. `like_count` e `dislike_count` são contadores desnormalizados
  que o contexto `Taste` alimenta.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer,
          tmdb_id: String.t(),
          type: Palpite.Catalog.type(),
          name: String.t(),
          year: integer,
          poster_path: String.t() | nil,
          genres: list(integer),
          like_count: integer,
          dislike_count: integer,
          description: String.t()
        }

  @fields ~w(tmdb_id type name year poster_path genres like_count dislike_count description)a

  schema "titles" do
    field :tmdb_id, :string
    field :type, :string
    field :name, :string
    field :year, :integer
    field :poster_path, :string
    field :genres, {:array, :string}
    field :like_count, :integer, default: 0
    field :dislike_count, :integer, default: 0
    field :description, :string
  end

  @doc false
  def changeset(%__MODULE__{} = title, attrs \\ %{}) do
    title
    |> cast(attrs, @fields)
  end
end
