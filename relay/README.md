# PORTIX Relay

Relay WebSocket **descartável** da malha PORTIX. Ele **não guarda catálogo nem
dados de usuário** — só conta quem está na sala e repassa mensagens entre os
dispositivos conectados.

> A malha funciona com **qualquer número** de relays, inclusive um. Hospede
> quantos quiser; o app tenta todos ao mesmo tempo e a rede se reconstrói
> sozinha se um cair.

## Rodar local

```bash
npm install
npm start          # http://localhost:8080
```

## Deploy no Railway

1. Crie um projeto no [Railway](https://railway.app) e aponte para este
   repositório, escolhendo a pasta **`relay/`** como raiz (o `railway.json`
   já define o build por Dockerfile e o healthcheck `/health`).
2. O Railway injeta `PORT` automaticamente; não precisa configurar nada.
3. Copie a URL pública (`https://SEU-APP.up.railway.app`) e cole no app em
   **Menu → Dados e Rede → Servidores da malha** (o app converte `https` em
   `wss` sozinho).

Variáveis opcionais: `RELAY_ID`, `STALE_MS`, `SWEEP_MS`, `MAX_ROOM_DEVICES`.

## Endpoints

- `GET /health` → `{ ok, relay, rooms, devices, uptime_s }`
- `GET /` → o mesmo resumo
- `ws://` na raiz → protocolo da malha

## Protocolo (resumo)

| Direção | Mensagem |
| --- | --- |
| cliente → relay | `{ "t": "hello", "room", "device", "name" }` |
| cliente → relay | `{ "t": "ping" }` |
| cliente → relay | `{ "t": "pub", "op": <json> }` |
| relay → cliente | `{ "t": "welcome", "device", "relay", "room" }` |
| relay → cliente | `{ "t": "presence", "room", "count", "devices" }` |
| relay → cliente | `{ "t": "op", "from", "op" }` |
| relay → cliente | `{ "t": "pong" }` |

O campo `op` é opaco para o relay: o conteúdo (favoritos, biblioteca, relatos)
é definido pelo app.

## Testes

```bash
npm test
```
