defmodule Palpite.Repo.Migrations.CreatePairCounts do
  use Ecto.Migration

  # SQLite nao suporta ALTER TABLE ADD CONSTRAINT: tabela criada em SQL cru
  # com o CHECK (title_a_id < title_b_id) inline
  def change do
    execute """
            CREATE TABLE pair_counts (
              title_a_id INTEGER NOT NULL REFERENCES titles(id) ON DELETE CASCADE,
              title_b_id INTEGER NOT NULL REFERENCES titles(id) ON DELETE CASCADE,
              likes INTEGER NOT NULL DEFAULT 0,
              a_like_b_dislike INTEGER NOT NULL DEFAULT 0,
              a_dislike_b_like INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (title_a_id, title_b_id),
              CONSTRAINT ordered_pair CHECK (title_a_id < title_b_id)
            )
            """,
            "DROP TABLE pair_counts"

    create index(:pair_counts, [:title_b_id])
  end
end
