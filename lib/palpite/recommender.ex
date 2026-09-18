defmodule Palpite.Recommender do
  @moduledoc """
  Shell de leitura do recomendador: a única função do app que compõe
  dados de dois contextos (`Taste`/`pair_counts` + `Catalog`), e faz
  isso lendo, nunca deixando um contexto chamar as entranhas do outro.

  Fluxo de `recommend/2`: entradas da identidade -> uma query de pares
  -> mapa de popularidade -> `Core.score/5` (puro) -> pós-filtro por
  `genres`/`type` no pool -> join com `titles` -> take N. Filtrar nunca
  afeta score, só quais candidatos aparecem.
  """

  import Ecto.Query

  alias Palpite.Catalog.Title
  alias Palpite.Identity
  alias Palpite.Recommender.Core
  alias Palpite.Repo
  alias Palpite.Taste.PairCount
  alias Palpite.Taste.TasteEntry

  @default_limit 20

  @doc """
  Recomenda títulos pra identidade.

  Opções: `:type` (`:film | :series | :anime | :cartoon`), `:genres`
  (lista de IDs de gênero do TMDB), `:limit` (default #{@default_limit}).
  Devolve `%{title, score, provenance}` em score decrescente.
  """
  @spec recommend(Identity.t(), keyword) ::
          {:ok, [%{title: Title.t(), score: float, provenance: Core.provenance()}]}
  def recommend(%Identity{} = identity, opts \\ []) do
    {likes, dislikes} = fetch_lists(identity.id)
    pair_rows = fetch_pairs(likes ++ dislikes)
    popularity = fetch_popularity()

    scored = Core.score(likes, dislikes, pair_rows, popularity, opts)

    {:ok, join_titles(scored, opts)}
  end

  defp fetch_lists(identity_id) do
    Repo.all(
      from(e in TasteEntry,
        where: e.identity_id == ^identity_id,
        select: {e.title_id, e.polarity}
      )
    )
    |> Enum.split_with(fn {_tid, pol} -> pol == "like" end)
    |> then(fn {likes, dislikes} ->
      {Enum.map(likes, &elem(&1, 0)), Enum.map(dislikes, &elem(&1, 0))}
    end)
  end

  defp fetch_pairs([]), do: []

  defp fetch_pairs(ids) do
    Repo.all(
      from(p in PairCount,
        where: p.title_a_id in ^ids or p.title_b_id in ^ids,
        select: %{
          title_a_id: p.title_a_id,
          title_b_id: p.title_b_id,
          likes: p.likes,
          a_like_b_dislike: p.a_like_b_dislike,
          a_dislike_b_like: p.a_dislike_b_like
        }
      )
    )
  end

  defp fetch_popularity do
    Repo.all(from(t in Title, select: {t.id, t.like_count}))
    |> Map.new()
  end

  defp join_titles(scored, opts) do
    ids = Enum.map(scored, &elem(&1, 0))

    titles =
      Repo.all(from(t in Title, where: t.id in ^ids))
      |> Map.new(&{&1.id, &1})

    scored
    |> Enum.flat_map(fn {id, score, provenance} ->
      case titles do
        %{^id => title} -> [%{title: title, score: score, provenance: provenance}]
        _ -> []
      end
    end)
    |> filter_by_type(opts[:type])
    |> filter_by_genres(opts[:genres])
    |> Enum.take(opts[:limit] || @default_limit)
  end

  defp filter_by_type(results, nil), do: results

  defp filter_by_type(results, type),
    do: Enum.filter(results, &(&1.title.type == to_string(type)))

  defp filter_by_genres(results, nil), do: results

  defp filter_by_genres(results, genres),
    do: Enum.filter(results, &Enum.any?(genres, fn g -> g in &1.title.genres end))
end
