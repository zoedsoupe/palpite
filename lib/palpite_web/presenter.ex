defmodule PalpiteWeb.Presenter do
  @moduledoc """
  Camada de apresentação: monta URLs de pôster do TMDB (hotlink direto,
  nunca proxy) e traduz enums internos pra rótulos pt-BR. Nada aqui
  toca em banco nem em rede.
  """

  @image_base "https://image.tmdb.org/t/p"

  @doc "Pôster pequeno (w92), usado em linhas de busca e na lista."
  @spec thumb(String.t() | nil) :: String.t() | nil
  def thumb(nil), do: nil
  def thumb(path), do: "#{@image_base}/w92#{path}"

  @doc "Pôster médio (w342), usado no card de recomendação."
  @spec card(String.t() | nil) :: String.t() | nil
  def card(nil), do: nil
  def card(path), do: "#{@image_base}/w342#{path}"

  @types %{
    "film" => "Filme",
    "series" => "Série",
    "anime" => "Anime",
    "cartoon" => "Desenho"
  }

  @doc "Rótulo singular do tipo, exibido no meta do card e das linhas."
  @spec type_label(String.t() | atom) :: String.t()
  def type_label(type), do: Map.get(@types, to_string(type), to_string(type))

  @doc "Opções do filtro de formato, na ordem da UI."
  @spec type_options() :: [{atom, String.t()}]
  def type_options,
    do: [film: "Filmes", series: "Séries", anime: "Animes", cartoon: "Desenhos"]

  @doc "Nome pt-BR de um ID de gênero, dado o catálogo de gêneros."
  @spec genre_name(integer, [%{id: integer, name: String.t()}]) :: String.t() | nil
  def genre_name(id, genres) do
    case Enum.find(genres, &(&1.id == id)) do
      nil -> nil
      genre -> genre.name
    end
  end
end
