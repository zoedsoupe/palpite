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
    token = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
    hash = :crypto.hash(:sha256, token)
    changeset = changeset(%__MODULE__{}, %{token_hash: hash})
    {token, Repo.insert!(changeset)}
  end

  def fetch(token) do
    hash = :crypto.hash(:sha256, token)

    if i = Repo.get_by(__MODULE__, token_hash: hash) do
      {:ok, i}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Marca a identidade como vista agora, no máximo uma escrita por hora:
  toda request autenticada chama, e escrita por request botaria o banco
  no hot path à toa (a coluna só alimenta introspecção de atividade).
  """
  @spec touch(t) :: :ok
  def touch(%__MODULE__{last_seen_at: last_seen} = i) do
    now = DateTime.utc_now(:second)

    if is_nil(last_seen) or DateTime.diff(now, last_seen, :second) >= 3600 do
      i
      |> changeset(%{last_seen_at: now})
      |> Repo.update()
    end

    :ok
  end
end
