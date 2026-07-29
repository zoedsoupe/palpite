# Palpite

Descobrir o que assistir sem algoritmo opaco, sem conta, sem tracking.

Palpite é um recomendador de filmes, séries, animes e desenhos baseado em uma ideia simples: se muita gente que gostou das mesmas coisas que você também gostou de outra coisa, essa coisa provavelmente vale um palpite.

## O pitch

Todo serviço de streaming tem um recomendador. Nenhum te diz por que recomendou aquilo. O Palpite faz o contrário: toda recomendação vem com a proveniência em destaque. "12 pessoas que gostaram de Dark e 1899 também gostaram de Severance." Não é caixa-preta, é aritmética que você pode conferir.

E não existe conta. Você chega, marca 3 títulos que amou, e o app já funciona. Sua identidade é um token em cookie HttpOnly; no banco fica só o hash. Se o token sumir, a lista sumiu junto, e está tudo bem.

## Como funciona

O mecanismo inteiro cabe em uma tabela e uma fórmula:

- Cada like seu atualiza contadores de pares: para cada título T, quantas pessoas que gostaram de T também gostaram de cada outro título.
- O score de um candidato é a soma dessas contagens sobre a sua lista, com duas correções: quem você não gostou pesa contra, e títulos muito populares são amortecidos (todo mundo já gosta deles, isso diz pouco sobre você).
- Candidato com menos de 3 pares contribuindo nem aparece. Sem evidência, sem palpite.

Nada é pré-computado ou cacheado: cada recomendação é recalculada na hora a partir dos contadores atuais.

A página `/honesty` explica o algoritmo em um parágrafo, em linguagem comum, e diz exatamente o que fica guardado no banco.

## Stack

- Elixir 1.19 / OTP 28, Phoenix 1.8 LiveView, Bandit
- SQLite via `ecto_sqlite3`
- TMDB como catálogo (busca e pôsteres, hotlink direto, nada é espelhado)
- Zero JavaScript além do que o LiveView já traz
- Deps mínimas: Phoenix + Req + Mox para testes

A arquitetura segue Functional Core, Imperative Shell: o recomendador é um módulo puro, sem Ecto, que recebe contagens e devolve scores com proveniência. Todo o IO (banco, TMDB, HTTP) vive na borda.

## Rodando local

```sh
mix setup
mix phx.server
```

Abra [`localhost:4000`](http://localhost:4000). Você vai precisar de uma chave de API do TMDB configurada no ambiente.

Testes: `mix test`. Antes de commitar: `mix precommit`.

## O que não é (de propósito)

Sem contas, sem feed, sem notificações, sem gamificação, sem analytics. Não é um clone de Netflix e não tenta ser. O app inteiro tem duas telas: a sua lista e a descoberta.

## Roadmap

- **v0** (atual): likes, descoberta individual, proveniência.
- **Logo depois**: match em grupo (interseção de listas de várias pessoas, mesmo motor de score).
- **Depois, talvez**: dislikes na UI (a coluna já existe no banco desde o dia um).

## Licença

[Apache 2.0](LICENSE). Copyright 2026 Zoey de Souza Pessanha.
