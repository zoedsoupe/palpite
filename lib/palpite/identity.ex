defmodule Palpite.Identity do
  @moduledoc """
  Identidade anônima por token.

  `create/0` gera um código de 6 caracteres base32 e persiste só o sha256:
  dump do banco não vaza token nenhum. O código é mostrado uma vez só, como
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
    # 6 chars base32 = 30 bits. ponytail: colisão vira provável na casa dos
    # milhares de identidades (birthday paradox); se o banco crescer, subir
    # para 8+ chars ou retry em duplicata
    token = 4 |> :crypto.strong_rand_bytes() |> Base.encode32() |> binary_part(0, 6)
    hash = :crypto.hash(:sha256, token)
    changeset = changeset(%__MODULE__{}, %{token_hash: hash})
    {token, Repo.insert!(changeset)}
  end

  def fetch(token) do
    hash = token |> String.trim() |> String.upcase() |> then(&:crypto.hash(:sha256, &1))

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
