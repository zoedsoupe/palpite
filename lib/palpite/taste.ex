defmodule Palpite.Taste do
  @moduledoc """
  Contexto de gosto: o que cada identidade curte/não curte e os
  agregados que o recomendador lê (`pair_counts` e os contadores
  desnormalizados de `titles`).

  Modelo de mutação: delta, nunca recomputação. Toda operação abre uma
  transação, faz a mudança na linha de `taste_entries`, relê a lista da
  identidade e deixa o `Stats` (puro) derivar o delta `{added, removed}`;
  a camada SQL aplica esse delta em `pair_counts` e `titles` com
  incrementos atômicos (`ON CONFLICT DO UPDATE`, sem read-modify-write
  em Elixir). Add, remove e flip de polaridade caem no mesmo caminho.

  Concorrência: `mode: :immediate` faz o SQLite segurar o lock de
  escrita desde o BEGIN, serializando mutações - duas escritas
  concorrentes da mesma identidade não intercalam deltas nem derivam
  contadores.
  """

  import Ecto.Query

  alias Palpite.Catalog
  alias Palpite.Catalog.Entry
  alias Palpite.Catalog.Title
  alias Palpite.Identity
  alias Palpite.Repo
  alias Palpite.Taste.PairCount
  alias Palpite.Taste.Stats
  alias Palpite.Taste.TasteEntry

  @doc """
  Adiciona um título à lista da identidade com polaridade `:like`.

  Aceita `%Entry{}` de busca ou um `tmdb_id` cru; garante a linha local
  via `Catalog.upsert_from_tmdb/2` quando preciso. Idempotente pela
  unique `(identity_id, title_id)`: readicionar devolve a entrada
  existente sem mexer em contador.
  """
  @spec add(Identity.t(), Entry.t() | integer) :: {:ok, TasteEntry.t()} | {:error, term}
  def add(%Identity{} = identity, %Entry{} = entry) do
    with {:ok, title} <- ensure_title(entry) do
      insert_like(identity, title)
    end
  end

  def add(%Identity{} = identity, tmdb_id) when is_integer(tmdb_id) do
    case Repo.get_by(Title, tmdb_id: tmdb_id) do
      nil -> add(identity, %Entry{tmdb_id: tmdb_id, in_catalog: false})
      title -> insert_like(identity, title)
    end
  end

  defp insert_like(%Identity{} = identity, %Title{} = title) do
    Repo.transaction(
      fn ->
        old = entries_for(identity.id)

        %TasteEntry{}
        |> TasteEntry.changeset(%{
          identity_id: identity.id,
          title_id: title.id,
          polarity: "like"
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:identity_id, :title_id])

        apply_deltas(identity.id, old)
        Repo.get_by!(TasteEntry, identity_id: identity.id, title_id: title.id)
      end,
      mode: :immediate
    )
  end

  @doc """
  Remove um título da lista, aplicando o delta negativo. Remover algo
  que nunca foi adicionado é no-op, não erro (a UI alterna às cegas).
  """
  @spec remove(Identity.t(), title_id :: integer) :: :ok
  def remove(%Identity{} = identity, title_id) do
    Repo.transaction(
      fn ->
        old = entries_for(identity.id)

        Repo.delete_all(
          from(e in TasteEntry,
            where: e.identity_id == ^identity.id and e.title_id == ^title_id
          )
        )

        apply_deltas(identity.id, old)
        :ok
      end,
      mode: :immediate
    )
  end

  @doc """
  Inverte a polaridade de uma entrada existente. Estritamente
  remove-delta + add-delta por dentro. A UI v0 não chama; existe pro
  storage da UI de dislikes já nascer pronto.
  """
  @spec set_polarity(Identity.t(), title_id :: integer, Stats.polarity()) ::
          {:ok, TasteEntry.t()} | {:error, :not_found}
  def set_polarity(%Identity{} = identity, title_id, polarity)
      when polarity in [:like, :dislike] do
    Repo.transaction(
      fn ->
        old = entries_for(identity.id)

        {updated, _} =
          Repo.update_all(
            from(e in TasteEntry,
              where: e.identity_id == ^identity.id and e.title_id == ^title_id
            ),
            set: [polarity: to_string(polarity)]
          )

        if updated == 0 do
          Repo.rollback(:not_found)
        else
          apply_deltas(identity.id, old)
          Repo.get_by!(TasteEntry, identity_id: identity.id, title_id: title_id)
        end
      end,
      mode: :immediate
    )
  end

  @doc "A lista da identidade com títulos preloaded, mais recente primeiro."
  @spec list(Identity.t()) :: [TasteEntry.t()]
  def list(%Identity{} = identity) do
    Repo.all(
      from(e in TasteEntry,
        where: e.identity_id == ^identity.id,
        order_by: [desc: e.inserted_at],
        preload: :title
      )
    )
  end

  @doc """
  Importa uma lista de `%Entry{}` em lote (~1000 linhas por statement),
  com uma única aplicação de delta pro batch inteiro. Reservado pra
  versões futuras (import CSV/Letterboxd); sem UI no v0.
  """
  @spec import_many(Identity.t(), [Entry.t()]) :: {:ok, count :: integer} | {:error, term}
  def import_many(%Identity{} = identity, entries) when is_list(entries) do
    with {:ok, titles} <- ensure_titles(entries) do
      Repo.transaction(
        fn ->
          old = entries_for(identity.id)
          now = DateTime.utc_now(:second)

          rows =
            Enum.map(titles, fn title ->
              %{
                identity_id: identity.id,
                title_id: title.id,
                polarity: "like",
                inserted_at: now,
                updated_at: now
              }
            end)

          for chunk <- Enum.chunk_every(rows, 1000) do
            Repo.insert_all(TasteEntry, chunk,
              on_conflict: :nothing,
              conflict_target: [:identity_id, :title_id]
            )
          end

          apply_deltas(identity.id, old)
          length(entries_for(identity.id)) - length(old)
        end,
        mode: :immediate
      )
    end
  end

  defp ensure_titles(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case ensure_title(entry) do
        {:ok, title} -> {:cont, {:ok, [title | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp ensure_title(%Entry{in_catalog: true, tmdb_id: tmdb_id}),
    do: {:ok, Repo.get_by!(Title, tmdb_id: tmdb_id)}

  defp ensure_title(%Entry{tmdb_id: tmdb_id}) do
    with {:ok, _} <- Catalog.upsert_from_tmdb(tmdb_id),
         do: {:ok, Repo.get_by!(Title, tmdb_id: tmdb_id)}
  end

  defp entries_for(identity_id) do
    Repo.all(
      from(e in TasteEntry,
        where: e.identity_id == ^identity_id,
        select: {e.title_id, e.polarity}
      )
    )
    |> Enum.map(fn {tid, pol} -> {tid, String.to_existing_atom(pol)} end)
  end

  # delta do before/after da lista aplicado em pair_counts e titles,
  # sempre dentro da transação da mutação chamadora
  defp apply_deltas(identity_id, old) do
    new = entries_for(identity_id)
    diff = Stats.diff(old, new)

    apply_pair_deltas(Stats.pair_deltas(diff, old, new))
    apply_title_deltas(Stats.title_deltas(diff))
  end

  defp apply_pair_deltas(deltas) when map_size(deltas) == 0, do: :ok

  defp apply_pair_deltas(deltas) do
    rows =
      Enum.map(deltas, fn {{a, b}, counters} ->
        %{
          title_a_id: a,
          title_b_id: b,
          likes: Map.get(counters, :likes, 0),
          a_like_b_dislike: Map.get(counters, :a_like_b_dislike, 0),
          a_dislike_b_like: Map.get(counters, :a_dislike_b_like, 0)
        }
      end)

    on_conflict =
      from(p in PairCount,
        update: [
          set: [
            likes: fragment("pair_counts.likes + EXCLUDED.likes"),
            a_like_b_dislike:
              fragment("pair_counts.a_like_b_dislike + EXCLUDED.a_like_b_dislike"),
            a_dislike_b_like: fragment("pair_counts.a_dislike_b_like + EXCLUDED.a_dislike_b_like")
          ]
        ]
      )

    Repo.insert_all(PairCount, rows,
      on_conflict: on_conflict,
      conflict_target: [:title_a_id, :title_b_id]
    )

    :ok
  end

  defp apply_title_deltas(deltas) do
    deltas
    |> Enum.group_by(fn {_id, counters} ->
      {Map.get(counters, :like_count, 0), Map.get(counters, :dislike_count, 0)}
    end)
    |> Enum.each(fn
      {{0, 0}, _} ->
        :ok

      {{like_inc, dislike_inc}, group} ->
        ids = Enum.map(group, &elem(&1, 0))

        Repo.update_all(
          from(t in Title,
            where: t.id in ^ids,
            update: [inc: [like_count: ^like_inc, dislike_count: ^dislike_inc]]
          ),
          []
        )
    end)
  end
end
