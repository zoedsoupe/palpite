defmodule Palpite.Repo.Migrations.CreateTasteEntries do
  use Ecto.Migration

  def change do
    create table(:taste_entries) do
      add :polarity, :string, null: false
      add :title_id, references(:titles), null: false
      add :identity_id, references(:identities, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:taste_entries, [:identity_id, :title_id])
  end
end
