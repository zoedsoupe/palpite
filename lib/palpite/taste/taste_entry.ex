defmodule Palpite.Taste.TasteEntry do
  @moduledoc """
  Linha de gosto de uma identidade: um título, uma polaridade.

  `polarity` é string no banco ("like" | "dislike"); a coluna existe
  desde o dia um mesmo que a UI v0 só curta. A unique `(identity_id,
  title_id)` torna `Taste.add/2` idempotente.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Palpite.Catalog.Title
  alias Palpite.Identity

  @type t :: %__MODULE__{
          id: integer,
          polarity: String.t(),
          title_id: integer,
          identity_id: integer
        }

  schema "taste_entries" do
    field :polarity, :string

    belongs_to :title, Title
    belongs_to :identity, Identity

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = e, %{} = attrs) do
    e
    |> cast(attrs, ~w(identity_id title_id polarity)a)
    |> validate_required(~w(identity_id title_id polarity)a)
  end
end
