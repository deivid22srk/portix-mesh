// Relais WebSocket da malha PORTIX.
//
// Papel: NÃO guarda o catálogo nem dados de usuário. Só faz duas coisas:
//   1. presença — conta e anuncia quantos dispositivos estão na sala;
//   2. retransmissão — repassa ops (favoritos, biblioteca, relatos...) para os
//      outros membros da sala. O relay é "burro" e descartável: se cair, os
//      clientes migram para outro da lista e a malha se reconstrói.
//
// Protocolo (JSON, uma mensagem por frame):
//   cliente → relay
//     { "t": "hello", "room": "portix", "device": "<id>", "name": "<apelido>" }
//     { "t": "ping" }
//     { "t": "pub",   "room": "portix", "op": <qualquer JSON> }
//   relay → cliente
//     { "t": "welcome",  "device": "<id>", "relay": "<id>", "room": "portix" }
//     { "t": "presence", "room": "portix", "count": N, "devices": [ {device,name} ] }
//     { "t": "op",       "from": "<id>", "op": <qualquer JSON> }
//     { "t": "pong" }
//     { "t": "error",    "message": "..." }

import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT || 8080);
const DEFAULT_ROOM = 'portix';
const MAX_ROOM_DEVICES = Number(process.env.MAX_ROOM_DEVICES || 20000);
// Um dispositivo é considerado "presente" enquanto manda sinal de vida. O
// intervalo é folgado para sobreviver a redes móveis instáveis.
const STALE_MS = Number(process.env.STALE_MS || 45000);
const SWEEP_MS = Number(process.env.SWEEP_MS || 15000);

const RELAY_ID = process.env.RELAY_ID || randomUUID().slice(0, 8);

/** room -> Map<deviceId, { sockets:Set<ws>, name:string, seen:number }> */
const rooms = new Map();

function roomOf(name) {
  let room = rooms.get(name);
  if (!room) {
    room = new Map();
    rooms.set(name, room);
  }
  return room;
}

function presencePayload(name) {
  const room = rooms.get(name) || new Map();
  const devices = [...room.entries()]
    .filter(([, entry]) => entry.sockets.size > 0)
    .map(([device, entry]) => ({ device, name: entry.name || '' }));
  return { t: 'presence', room: name, count: devices.length, devices };
}

function broadcast(name, message, exceptSocket) {
  const room = rooms.get(name);
  if (!room) return;
  const raw = JSON.stringify(message);
  for (const entry of room.values()) {
    for (const socket of entry.sockets) {
      if (socket === exceptSocket) continue;
      if (socket.readyState === socket.OPEN) socket.send(raw);
    }
  }
}

function announcePresence(name) {
  broadcast(name, presencePayload(name));
}

function leave(socket) {
  const { room, device } = socket.portix || {};
  if (!room || !device) return;
  const map = rooms.get(room);
  if (!map) return;
  const entry = map.get(device);
  if (!entry) return;
  entry.sockets.delete(socket);
  if (entry.sockets.size === 0) map.delete(device);
  if (map.size === 0) rooms.delete(room);
  announcePresence(room);
}

function attach(socket, room, device, name) {
  const map = roomOf(room);
  let entry = map.get(device);
  if (!entry) {
    if (map.size >= MAX_ROOM_DEVICES) return false;
    entry = { sockets: new Set(), name: name || '', seen: Date.now() };
    map.set(device, entry);
  }
  if (name) entry.name = name;
  entry.seen = Date.now();
  entry.sockets.add(socket);
  socket.portix = { room, device };
  return true;
}

const server = createServer((req, res) => {
  const path = (req.url || '/').split('?')[0];
  if (path === '/health' || path === '/') {
    const summary = {};
    let total = 0;
    for (const [name, map] of rooms.entries()) {
      summary[name] = map.size;
      total += map.size;
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(
      JSON.stringify({
        ok: true,
        relay: RELAY_ID,
        role: 'portix-relay',
        rooms: summary,
        devices: total,
        uptime_s: Math.round(process.uptime()),
      }),
    );
    return;
  }
  res.writeHead(404, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'not_found' }));
});

const wss = new WebSocketServer({ server, maxPayload: 512 * 1024 });

wss.on('connection', (socket) => {
  socket.portix = { room: null, device: null };
  socket.isAlive = true;
  socket.on('pong', () => {
    socket.isAlive = true;
  });

  socket.on('message', (data) => {
    let message;
    try {
      message = JSON.parse(data.toString());
    } catch {
      socket.send(JSON.stringify({ t: 'error', message: 'invalid_json' }));
      return;
    }
    if (!message || typeof message.t !== 'string') return;

    // Qualquer mensagem renova o sinal de vida do dispositivo na sala.
    {
      const { room, device } = socket.portix;
      const entry = room && device ? rooms.get(room)?.get(device) : null;
      if (entry) entry.seen = Date.now();
    }

    if (message.t === 'ping') {
      socket.send(JSON.stringify({ t: 'pong' }));
      return;
    }

    if (message.t === 'who') {
      // Presença sob demanda: o cliente pede a foto atual da sala para
      // renovar o TTL dos pares (a sala só anuncia em mudanças).
      const { room } = socket.portix;
      if (room) socket.send(JSON.stringify(presencePayload(room)));
      return;
    }

    if (message.t === 'hello') {
      const room =
        typeof message.room === 'string' && message.room.trim()
          ? message.room.trim().slice(0, 64)
          : DEFAULT_ROOM;
      const device =
        typeof message.device === 'string' && message.device.trim()
          ? message.device.trim().slice(0, 128)
          : randomUUID();
      const name = typeof message.name === 'string' ? message.name.slice(0, 64) : '';
      if (socket.portix.room && socket.portix.room !== room) leave(socket);
      if (!attach(socket, room, device, name)) {
        socket.send(JSON.stringify({ t: 'error', message: 'room_full' }));
        return;
      }
      socket.send(
        JSON.stringify({ t: 'welcome', device, relay: RELAY_ID, room }),
      );
      announcePresence(room);
      return;
    }

    if (message.t === 'pub') {
      const { room } = socket.portix;
      if (!room) {
        socket.send(JSON.stringify({ t: 'error', message: 'hello_required' }));
        return;
      }
      // Retransmite o op para a sala (menos para quem enviou). O relay não
      // interpreta o conteúdo: só entrega.
      broadcast(room, { t: 'op', from: socket.portix.device, op: message.op }, socket);
      return;
    }
  });

  socket.on('close', () => leave(socket));
  socket.on('error', () => leave(socket));
});

// Varre conexões mortas e atualiza a presença da sala.
const sweep = setInterval(() => {
  const now = Date.now();
  for (const [name, map] of rooms.entries()) {
    let changed = false;
    for (const [device, entry] of map.entries()) {
      for (const socket of [...entry.sockets]) {
        if (
          socket.readyState !== socket.OPEN ||
          now - (entry.seen || 0) > STALE_MS
        ) {
          entry.sockets.delete(socket);
          try {
            socket.terminate();
          } catch {
            /* ignore */
          }
          changed = true;
        }
      }
      if (entry.sockets.size === 0) {
        map.delete(device);
        changed = true;
      }
    }
    if (map.size === 0) {
      rooms.delete(name);
      changed = false;
    }
    if (changed) announcePresence(name);
  }
  for (const socket of wss.clients) {
    if (socket.isAlive === false) {
      socket.terminate();
      continue;
    }
    socket.isAlive = false;
    try {
      socket.ping();
    } catch {
      /* ignore */
    }
  }
}, SWEEP_MS);

wss.on('close', () => clearInterval(sweep));

server.listen(PORT, () => {
  console.log(`portix-relay ${RELAY_ID} ouvindo em :${PORT}`);
});

function shutdown() {
  clearInterval(sweep);
  for (const socket of wss.clients) socket.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
