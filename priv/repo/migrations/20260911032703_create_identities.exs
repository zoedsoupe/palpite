defmodule Palpite.Repo.Migrations.CreateIdentities do
  use Ecto.Migration

  def change do
    create table(:identities) do
      add :token_hash, :binary, size: 32
      add :last_seen_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:identities, [:token_hash])
  end
end
