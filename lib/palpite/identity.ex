defmodule Palpite.Identity do
  @moduledoc """
  Identidade anônima por token.

  `create/0` gera 32 bytes aleatórios e persiste só o sha256: dump do banco
  não vaza token nenhum. O token em base64 é mostrado uma vez só, como
  código de recuperação da lista. Sem email, sem senha, sem conta: a
  identidade é anônima e permanente.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Palpite.Repo

  @type t :: %__MODULE__{
          token_hash: binary,
          last_seen_at: DateTime.t()
        }

  schema "identities" do
    field :token_hash, :string
    field :last_seen_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = i, %{} = attrs) do
    i
    |> cast(attrs, [:token_hash, :last_seen_at])
    |> validate_required([:token_hash])
  end

  def create do
    bytes = :crypto.strong_rand_bytes(32)
    token = :crypto.hash(:sha256, bytes)
    changeset = changeset(%__MODULE__{}, %{token_hash: token})
    {Base.encode64(token), Repo.insert!(changeset)}
  end

  def fetch(hash) do
    if i = Repo.get_by(__MODULE__, token_hash: hash) do
      {:ok, i}
    else
      {:error, :not_found}
    end
  end
end
