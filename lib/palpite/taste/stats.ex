defmodule Palpite.Taste.Stats do
  @moduledoc """
  Núcleo puro dos contadores de gosto. Sem Ecto, sem banco: entram listas
  de `{title_id, polarity}`, saem incrementos/decrementos de contadores.

  Toda mutação é um delta de conjunto: `diff/2` compara a lista antes e
  depois e devolve `{added, removed}`. `pair_deltas/4` mapeia esse delta
  pros contadores de `pair_counts` (par guardado uma vez, id menor em
  `title_a_id`, por isso a ordem decide qual coluna de dislike recebe o
  incremento) e `title_deltas/1` pros `like_count`/`dislike_count` de
  `titles`. Flip like->dislike cai no mesmo caminho: remove-delta +
  add-delta, sem caso especial. Par dislike/dislike não tem coluna e é
  ignorado.
  """

  @type polarity :: :like | :dislike
  @type entry :: {title_id :: integer, polarity}
  @type pair_counters :: %{
          optional(:likes | :a_like_b_dislike | :a_dislike_b_like) => integer
        }

  @doc """
  Compara a lista antes e depois da mutação.

  Devolve `{added, removed}`: entradas que só existem na nova lista e
  entradas que só existiam na antiga, respectivamente.
  """
  @spec diff([entry], [entry]) :: {added :: [entry], removed :: [entry]}
  def diff(old_entries, new_entries) do
    old = MapSet.new(old_entries)
    new = MapSet.new(new_entries)

    {MapSet.to_list(MapSet.difference(new, old)), MapSet.to_list(MapSet.difference(old, new))}
  end

  @doc """
  Mapeia um diff pros incrementos de `pair_counts`.

  Entradas removidas pareiam com a lista antiga (sinal -1), adicionadas
  com a nova (sinal +1). Pares entre entradas intocadas cancelam e nem
  aparecem. Devolve `%{{a_id, b_id} => %{counter => delta}}`.
  """
  @spec pair_deltas({[entry], [entry]}, [entry], [entry]) :: %{
          {integer, integer} => pair_counters
        }
  def pair_deltas({added, removed}, old_entries, new_entries) do
    %{}
    |> apply_entries(removed, old_entries, -1)
    |> apply_entries(added, new_entries, 1)
  end

  @doc """
  Mapeia um diff pros incrementos de `titles.like_count`/`dislike_count`.

  Devolve `%{title_id => %{like_count: delta, dislike_count: delta}}`
  (só as chaves tocadas).
  """
  @spec title_deltas({[entry], [entry]}) :: %{integer => map}
  def title_deltas({added, removed}) do
    %{}
    |> bump(added, 1)
    |> bump(removed, -1)
  end

  defp apply_entries(deltas, entries, list, sign) do
    Enum.reduce(entries, deltas, fn {tid, pol}, acc ->
      Enum.reduce(list, acc, fn
        {^tid, _}, acc ->
          acc

        {other_tid, other_pol}, acc ->
          case pair_counter(tid, pol, other_tid, other_pol) do
            nil -> acc
            {pair, counter} -> update_delta(acc, pair, counter, sign)
          end
      end)
    end)
  end

  defp pair_counter(t1, p1, t2, p2) do
    {{a_id, a_pol}, {b_id, b_pol}} =
      if t1 < t2, do: {{t1, p1}, {t2, p2}}, else: {{t2, p2}, {t1, p1}}

    case {a_pol, b_pol} do
      {:like, :like} -> {{a_id, b_id}, :likes}
      {:like, :dislike} -> {{a_id, b_id}, :a_like_b_dislike}
      {:dislike, :like} -> {{a_id, b_id}, :a_dislike_b_like}
      {:dislike, :dislike} -> nil
    end
  end

  defp update_delta(deltas, pair, counter, sign) do
    counters = deltas |> Map.get(pair, %{}) |> Map.update(counter, sign, &(&1 + sign))
    Map.put(deltas, pair, counters)
  end

  defp bump(acc, entries, sign) do
    Enum.reduce(entries, acc, fn {tid, pol}, acc ->
      field = if pol == :like, do: :like_count, else: :dislike_count
      counters = acc |> Map.get(tid, %{}) |> Map.update(field, sign, &(&1 + sign))
      Map.put(acc, tid, counters)
    end)
  end
end
