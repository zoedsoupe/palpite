defmodule Palpite.Recommender.Core do
  @moduledoc """
  Núcleo puro de recomendação: entram dados, sai lista ranqueada.

  A matemática, por candidato T:

    * `raw(T) = Σ likes(T,t) − λ·Σ likes(T,d)` - soma os co-likes com
      cada título `t` que a pessoa curtiu e subtrai λ vezes os co-likes
      com os que ela não curtiu. Algo popular entre quem compartilha
      seus dislikes empurra pra baixo, não só deixa de empurrar pra cima.
    * `score = raw / (pop^α + β)` - divide pela raiz do like_count
      global do candidato: um título de nicho com 3 sobreposições fortes
      ganha de um blockbuster com 30 fracas.
    * Piso duro: candidato fora se a soma dos pares contribuintes < piso.
      Um ou dois co-likes é ruído; abaixo do piso, silêncio em vez de
      recomendar no feeling.
    * Proveniência: os top-k pares contribuintes por candidato saem do
      próprio fold - alimenta o "12 pessoas que curtiram Dark e 1899
      também curtiram Severance" da UI.
  """

  @lambda 1.0
  @alpha 0.5
  @beta 1
  @floor 3
  @top_k 3
  @pool_size 200

  @type id :: integer
  @type pair_row :: %{
          title_a_id: id,
          title_b_id: id,
          likes: non_neg_integer,
          a_like_b_dislike: non_neg_integer,
          a_dislike_b_like: non_neg_integer
        }
  @type provenance :: %{top_pairs: [{id, non_neg_integer}]}

  @doc """
  Ranqueia candidatos por "quem tem gosto sobreposto curtiu isso".

  `likes`/`dislikes` são os title_ids da pessoa, `pair_rows` as linhas
  de `pair_counts` que tocam qualquer um deles, `popularity` o mapa
  `title_id => like_count`. Títulos já na lista nunca são candidatos.
  Devolve até 200 `{title_id, score, provenance}` em score decrescente.
  """
  @spec score(
          likes :: [id],
          dislikes :: [id],
          pair_rows :: [pair_row],
          popularity :: %{id => non_neg_integer},
          opts :: keyword
        ) :: [{id, float, provenance}]
  def score(likes, dislikes, pair_rows, popularity, _opts \\ []) do
    liked = MapSet.new(likes)
    mine = MapSet.union(liked, MapSet.new(dislikes))

    pair_rows
    |> Enum.reduce(%{}, &accumulate(&1, &2, liked, mine))
    |> Enum.filter(fn {_id, c} -> c.total >= @floor end)
    |> Enum.map(&score_candidate(&1, popularity))
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(@pool_size)
  end

  defp accumulate(row, acc, liked, mine) do
    case orient(row, mine) do
      {user_tid, candidate_tid} ->
        count = row.likes
        sign = if MapSet.member?(liked, user_tid), do: 1.0, else: -@lambda

        Map.update(acc, candidate_tid, contribution(sign * count, user_tid, count), fn c ->
          %{
            raw: c.raw + sign * count,
            total: c.total + count,
            pairs: [{user_tid, count} | c.pairs]
          }
        end)

      nil ->
        acc
    end
  end

  # {título da pessoa, candidato} — linhas entre dois títulos da própria
  # pessoa ou sem nenhum não geram candidato
  defp orient(row, mine) do
    a_mine = MapSet.member?(mine, row.title_a_id)
    b_mine = MapSet.member?(mine, row.title_b_id)

    cond do
      a_mine and not b_mine -> {row.title_a_id, row.title_b_id}
      b_mine and not a_mine -> {row.title_b_id, row.title_a_id}
      true -> nil
    end
  end

  defp contribution(raw, user_tid, count),
    do: %{raw: raw, total: count, pairs: [{user_tid, count}]}

  defp score_candidate({id, c}, popularity) do
    pop = Map.get(popularity, id, 0)
    score = c.raw / (:math.pow(pop, @alpha) + @beta)
    top_pairs = c.pairs |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(@top_k)

    {id, score, %{top_pairs: top_pairs}}
  end
end
