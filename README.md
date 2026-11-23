# PORTIX — Mesh

[![Build APK](https://github.com/deivid22srk/portix-mesh/actions/workflows/build.yml/badge.svg)](https://github.com/deivid22srk/portix-mesh/actions/workflows/build.yml)

**Seus consoles. No seu bolso.** — agora **sem servidor central**.

PORTIX é uma biblioteca Android de _ports_ de jogos clássicos e modernos.
Esta versão troca o backend Supabase por uma arquitetura **local-first + P2P**:

- o **catálogo inteiro viaja dentro do APK** (`assets/catalog/portix.json`);
- os **dados do usuário** (favoritos, biblioteca, relatos) ficam no aparelho e
  sincronizam **direto entre dispositivos**;
- a **contagem de dispositivos conectados** é calculada pela própria malha.

> Projeto de estudo. Todos os créditos dos jogos, ports, capas e links
> pertencem aos projetos originais. O PORTIX não hospeda arquivos.

---

## Por que "praticamente impossível de derrubar"

| Camada | Antes (Supabase) | Agora |
| --- | --- | --- |
| Catálogo | consulta a um Postgres central | **asset local** — navegar/buscar não usa rede |
| Conta | GoTrue + sessão anônima | **identidade local** gerada no aparelho |
| Dados do usuário | tabelas por usuário com RLS | **store local + merge CRDT (LWW)** |
| Entrega de dados | um servidor só | **malha de relays** — qualquer um hospeda, nenhum é obrigatório |
| Rede local | — | **descoberta UDP (mDNS-like)**, funciona sem relay |

Não existe ponto único: se todos os relays caírem, o app continua **100%
funcional** (catálogo e dados locais). A malha só deixa de mostrar a contagem
de dispositivos online naquele instante.

---

## Arquitetura

```
lib/
  core/
    mesh/
      mesh_config.dart     # relays (build + runtime) e liga/desliga
      mesh_identity.dart   # id opaco do dispositivo + nome público
      mesh_store.dart      # store local-first + merge CRDT (LWW)
      mesh_node.dart       # relays WebSocket + descoberta LAN + presença
    auth.dart              # "conta" = identidade local (sem servidor)
    providers.dart         # catálogo local + malha (Riverpod)
  data/
    local_catalog.dart             # índice do asset embutido
    local_catalog_repository.dart  # implementa o contrato sem backend
  features/…                # telas inalteradas (mesmo contrato de dados)
relay/                     # servidor WebSocket (Railway/Docker) — ver relay/README.md
tools/catalog/             # converte o dump NAPL no asset do app
assets/catalog/portix.json # catálogo embutido
```

### Como os dispositivos se acham

1. **Relays WebSocket** — o app conecta a *todos* os relays que você configurar
   ao mesmo tempo. Cada relay só conta presença e retransmite mensagens; não
   guarda catálogo nem dados. Um ponto só = mais frágil; vários = quase
   indestrutível. Qualquer pessoa pode hospedar um (ver `relay/`).
2. **Rede local (UDP broadcast)** — na mesma Wi-Fi, os aparelhos se veem sem
   relay nenhum.

### Como os dados "atualizam" sem servidor

Cada alteração vira um **op** com carimbo lógico `(tempo, dispositivo)`:

- é aplicada localmente (fonte de verdade do aparelho);
- é publicada na malha; cada receptor faz o **merge last-write-wins**;
- ao encontrar um **par novo**, o app publica o **estado completo** (sync), e
  os dois convergem.

Sem relógio sincronizado, o par `(carimbo, dispositivo)` desempata de forma
determinística em qualquer ordem de chegada.

---

## Rede e Railway

O relay vive em [`relay/`](relay/README.md) e já vem pronto para o Railway
(`Dockerfile` + `railway.json` + healthcheck `/health`).

1. No Railway: **New Project → Deploy from repo**, escolha a pasta `relay/`.
2. Copie a URL pública (`https://SEU-APP.up.railway.app`).
3. No app: **Menu → Rede e Malha → cole a URL → Adicionar**. O app converte
   para `wss://` sozinho e mostra quantos relays estão online.

> Para embutir um relay padrão no build, use
> `--dart-define=PORTIX_RELAYS=wss://a.exemplo,wss://b.exemplo`
> (o workflow lê o secret `PORTIX_RELAYS`).

A tela **Rede e Malha** mostra:

- **quantos dispositivos estão conectados agora**;
- quantos relays estão online;
- quantos pares vieram da **rede local**;
- o seu **ID de dispositivo** (opaco, gerado localmente).

---

## Atualizar o catálogo

O catálogo é gerado a partir do dump público do NAPL:

```bash
python3 tools/catalog/build_catalog.py \
  --input /caminho/napl_catalogo_completo.json \
  --output assets/catalog/portix.json
```

Resultado atual: **960 jogos · 1.199 ports · 29 plataformas** (~1,7 MiB).

---

## Rodando localmente

```bash
flutter pub get
flutter run \
  --dart-define=PORTIX_RELAYS=wss://seu-relay.up.railway.app   # opcional
```

Não há configuração obrigatória de backend: sem relays, o app abre com o
catálogo embutido e a descoberta em rede local.

## Build no CI

`.github/workflows/build.yml` roda a cada push em `main`:

1. **`relay`** — `npm install` + testes de presença/retransmissão do relay;
2. **`build`** — portões de UI, `flutter analyze`, `flutter test`, scaffold
   Android, motor Rust (JNI) para as 3 ABIs e APKs release (split + universal),
   publicados no artefato **portix-apk**.

Secrets opcionais: `PORTIX_RELAYS`, `ANDROID_KEYSTORE_*` (assinatura).

## Ainda é Rust + Kotlin

O download real de APK continua no **motor Rust** (`native/portix_downloader`)
via JNI + `DownloadService` em primeiro plano — inalterado nesta migração.

---

## Migração: o que saiu

- `supabase/` (26 migrations), `supabase_flutter`, auth anônima/GoTrue;
- `supabase_catalog_repository.dart` → `local_catalog_repository.dart`;
- `admin_app/` e os workflows/painéis de administração;
- não há mais `SUPABASE_URL`/`SUPABASE_ANON_KEY` em lugar nenhum.

## Segurança

- **Nenhum token no repositório.** O relay não guarda dados; ops são efêmeros.
- A identidade é um id **opaco** (128 bits) gerado no aparelho — não é dado
  pessoal.
- Próximo passo de endurecimento: assinar os `ops` com chave por dispositivo
  (Ed25519) para resistir a relays maliciosos. Hoje o relay é confiável apenas
  para disponibilidade, não para autenticidade.
