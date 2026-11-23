# Explorar — redesign (busca, descoberta, filtros)

Branch: `feat/explorar-redesign` · Migration: `supabase/migrations/0025_search_discovery.sql`

## Problemas da linha de base (medidos, não presumidos)

Medição local: Postgres 17, catálogo real do CI (839 jogos), 20 termos de teste
(`supabase/tests/55_search_v2_tests.sql`).

| Problema | Evidência (antes) |
| --- | --- |
| Busca sensível a acento | `search_games('Simulacao')` → **0 resultados** (70 jogos de "Simulação") |
| Sem tolerância a typo | `'Jgo 479 Frontier'` / `'Frontir'` / `'Arenna'` → **0 resultados** |
| Paginação por offset | duplicata/pulo possível se o catálogo mudar entre páginas; `count(*) over()` reconta o total em TODA página |
| Explorar sem modo descoberta | nenhuma RPC agregada; tela era uma grade plana de "trending" |
| Re-render por tecla | `state.query` mudava a cada tecla e reconstruía a grade |

Já existiam e foram preservados: debounce (320→280 ms) e cancelamento por
requestId no `SearchController` (a race condition da versão mais antiga já
estava resolvida); índices GIN pg_trgm em `title`/`developer` (0001); RLS
pública de leitura em `games`; cache de imagens (`CachedNetworkImage`).

## O que a migration 0025 entrega

- **`extensions.f_unaccent` / `f_norm`** — wrapper IMMUTABLE de `unaccent`
  (exigência do Postgres para índices) + minúsculas. Normalizador único usado
  no índice e no filtro.
- **Índices de expressão** — GIN trigramas sobre texto NORMALIZADO de
  `title`/`developer`/`genre` + índices de ordenação (`visit_count`,
  `rating_avg`). O filtro combinado usa `BitmapOr` com **zero Seq Scan**
  (verificado com `EXPLAIN ANALYZE` no CI — `supabase/tests/56_search_explain.sql`).
- **`search_games_v2`** — filtro tolerante (substring normalizado **OU**
  trigramas, `pg_trgm.similarity_threshold = 0.30`), ranking em camadas
  (exato 3.0 > prefixo 2.0 > parcial 1.2 > similaridade) com desempate por
  popularidade, **paginação keyset por cursor** (sem duplicata — testado
  percorrendo todas as páginas), total contado só na 1ª página e sugestão
  "Você quis dizer…?" (comparação palavra a palavra) quando zera.
- **`search_suggest`** — jogos + categorias + desenvolvedores + plataformas
  numa chamada (sugestão de plataforma vira FILTRO, não busca textual).
- **`explore_feed`** — seções da descoberta agregadas (uma chamada por tela,
  convenção do app): Em alta, Novidades, Mais avaliados, Grátis,
  "Em alta nas buscas", categorias e stats.
- RPCs legadas (`search_games`, `home_feed`) **intactas** como fallback.

Latência local (10 chamadas): busca com termo **6,2 ms**, descoberta
**2,0 ms**, sugestões **1,8 ms**, explore_feed **1,5 ms** (meta < 150 ms).

Sobre o plano de execução: no volume atual (839 jogos, seletividade de 8-30%
no seed), o planner escolhe Seq Scan e é o plano CERTO (3 ms). O que os
testes (56) provam de forma determinística é a **compatibilidade de índice**
da forma da consulta: com `enable_seqscan=off`, o planner produz `BitmapOr`
sobre os índices GIN de trigramas — o índice assume o caminho principal
quando a tabela crescer. Os testes 55/56 rodam no CI
(`tools/feed/run_sql_tests.sh`).

## Decisões e suposições

1. **"Em alta nas buscas"** — não existe tabela de termos de busca (e criar
   coleta seria desnecessário); proxy conservador = popularidade
   (`visit_count`), a mesma métrica de "Em alta" da Início.
2. **Tags** — o schema não tem tabela de tags; busca cobre título,
   desenvolvedor, gênero e plataforma (nomes); "categoria" = gênero.
3. **Busca por plataforma** sugere um FILTRO (chip) em vez de buscar texto —
   evita ramificar o filtro principal em `unnest(platforms)` (sem índice).
4. **Ordenação ao digitar** — se o usuário está na ordenação padrão
   (`trending`), digitar troca para `relevance` automaticamente; se ele já
   escolheu um critério, é respeitado. `Limpar` restaura `trending`.
5. **Cache de busca** — TTL 90 s por consulta+filtros; usado só na carga
   inicial (aba reaberta) e no FALLBACK offline (erro → payload salvo com
   aviso "dados podem estar desatualizados"). Digitar/submeter sempre vai à
   rede: resultados frescos e contrato previsível para testes.
6. **Histórico de buscas** — só no dispositivo (`SharedPreferences`, chave
   `search.recent`), limite **10** itens, dedup case-insensitive, remover
   item individual e "Limpar tudo" com confirmação + undo. Nada é enviado ao
   servidor (não há tabela de termos).
7. **Impressões de feed** — os carrosséis da Explorar NÃO registram
   impressões: `feed_impressions` alimenta a personalização da Início
   ("visto recentemente"); registrar seções da Explorar distorceria o "Para
   você". Documentado no código.
8. **Filtros escolhidos** — existem dados reais para: plataforma, gênero,
   grátis, precisa de arquivos, avaliação mínima (3/4/4.5+) e ordenação.
   Nada inventado (não há "tamanho" no schema).
9. **Cursor keyset** — tuplas `(r1, r2, id)` em `numeric` (score arredondado
   a 6 casas: `double` na fronteira gerava duplicata por arredondamento
   jsonb); A–Z usa tupla textual. O cliente trata `cursor` como
   `Map?` — `{"cursor": null}` do PostgREST vira fim de lista.
10. **Fallback de RPC** — se `search_games_v2` não existir ainda
    (PostgREST `PGRST202`), o cliente usa a RPC legada (offset) até a
    migration ser aplicada: o deploy do app nunca espera o deploy do SQL.
11. **Route sync** — o estado (q, filtros, sort, view) é espelhado na rota
    `/explore?...` só quando um fetch assenta (nunca por tecla); posição de
    scroll sobrevive via `TabScrollRegistry` (padrão existente).
12. **Acessibilidade** — padrão combobox/listbox: Enter busca, setas navegam
    (handler global com escopo do campo: o `EditableText` pode consumir o
    evento antes do bubbling), Esc limpa/fecha, painel com `Semantics`
    `button`+`selected`, contador com `liveRegion`, alvos de toque ≥ 44dp
    (chips de filtro/histórico e botões "x" com área de 48dp; `AppPill`
    denso = 44dp, padrão = 48dp) — MEDIDOS por teste de widget
    (`test/ui/explore_page_test.dart`: 'alvos de toque medidos').
13. **Filtros ≥ 768px** — painel lateral fixo ancorado à direita (requisito
    literal); mobile mantém bottom sheet.
14. **Hint do campo em 375px** — a microcopy exigida pela missão
    ("Buscar jogos, categorias ou desenvolvedores") truncará com elipse em
    larguras muito estreitas: mantivemos o texto completo (microcopy >
    estética) e o campo continua usável.
15. **Auditoria visual** — goldens do ANTES em
    `docs/auditoria/explorar/antes/`; goldens do DEPOIS (5 temas × 3 larguras
    + estados) em `test/goldens_out/explore/` (gerados por
    `test/explore_goldens_test.dart`, gate GOLDENS=1).

## Como aplicar em produção (requer aprovação)

1. `supabase/migrations/0025_search_discovery.sql` (idempotente; cria
   extensão `unaccent` no schema `extensions`, funções SECURITY INVOKER com
   `search_path` fixo, índices de expressão — só leitura, nenhuma policy
   alterada).
2. Nenhuma migration altera dados nem policies: risco baixo. O rollback é
   `drop function ...` (os índices podem permanecer).
3. O build.yml aplica migrations **apenas no Postgres efêmero do CI**
   (`tools/feed/run_sql_tests.sh`), nunca no Supabase de produção.
