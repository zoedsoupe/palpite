defmodule Palpite.Taste.PairCount do
  @moduledoc """
  Matriz de co-ocorrência que o recomendador lê: "quem curtiu A também
  curtiu B". Uma linha por par não-ordenado, id menor em `title_a_id`
  (CHECK no banco). Os contadores são mantidos incrementalmente por
  `Taste`, nunca recomputados: cada mutação aplica um delta atômico em
  SQL. Par dislike/dislike não tem coluna por design.
  """

  use Ecto.Schema

  alias Palpite.Catalog.Title

  @type t :: %__MODULE__{
          title_a_id: integer,
          title_b_id: integer,
          likes: integer,
          a_like_b_dislike: integer,
          a_dislike_b_like: integer
        }

  @primary_key false
  schema "pair_counts" do
    field :likes, :integer, default: 0
    field :a_like_b_dislike, :integer, default: 0
    field :a_dislike_b_like, :integer, default: 0

    belongs_to :title_a, Title
    belongs_to :title_b, Title
  end
end
