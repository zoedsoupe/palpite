defmodule Palpite.Repo.Migrations.CreateTitlesTable do
  use Ecto.Migration

  def change do
    create table(:titles) do
      add :tmdb_id, :integer
      add :type, :string
      add :name, :string
      add :year, :smallint
      add :poster_path, :string
      add :genres, {:array, :integer}
      add :like_count, :integer, default: 0
      add :dislike_count, :integer, default: 0
      add :description, :text

      timestamps()
    end

    create unique_index(:titles, [:tmdb_id])
  end
end
