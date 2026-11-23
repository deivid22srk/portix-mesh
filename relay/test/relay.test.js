// Teste de integração do relay: sobe o servidor, conecta dois clientes e
// verifica presença e retransmissão de ops. Sem dependências além de `ws`.
//
//   npm install && npm test

import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';
import { WebSocket } from 'ws';

const PORT = 8137;
const URL = `ws://127.0.0.1:${PORT}`;

const server = spawn(process.execPath, ['server.js'], {
  env: { ...process.env, PORT: String(PORT), SWEEP_MS: '2000' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
server.stderr.on('data', (chunk) => process.stderr.write(chunk));

function connect(device, name) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(URL);
    const inbox = [];
    socket.on('message', (data) => inbox.push(JSON.parse(data.toString())));
    socket.on('error', reject);
    socket.on('open', () => {
      socket.send(JSON.stringify({ t: 'hello', room: 'portix', device, name }));
      resolve({ socket, inbox });
    });
  });
}

function waitFor(inbox, predicate, timeoutMs = 4000) {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const tick = () => {
      const hit = inbox.find(predicate);
      if (hit) return resolve(hit);
      if (Date.now() - started > timeoutMs) {
        return reject(new Error('timeout esperando mensagem no relay'));
      }
      setTimeout(tick, 40);
    };
    tick();
  });
}

function assert(condition, message) {
  if (!condition) throw new Error(`FALHOU: ${message}`);
}

try {
  await delay(600); // deixa o servidor subir

  const health = await fetch(`${URL.replace('ws', 'http')}/health`);
  assert(health.ok, 'health responde 200');

  const a = await connect('device-A', 'Alice');
  await waitFor(a.inbox, (m) => m.t === 'welcome');
  const b = await connect('device-B', 'Bob');
  await waitFor(b.inbox, (m) => m.t === 'welcome');

  const presence = await waitFor(
    a.inbox,
    (m) => m.t === 'presence' && m.count === 2,
  );
  assert(presence.count === 2, 'presença conta os dois dispositivos');

  a.socket.send(JSON.stringify({ t: 'pub', op: { kind: 'favorite', id: 'x' } }));
  const op = await waitFor(b.inbox, (m) => m.t === 'op');
  assert(op.from === 'device-A', 'op traz o autor');
  assert(op.op.id === 'x', 'op chega íntegro ao destino');

  // Sem eco para o autor.
  assert(
    !a.inbox.some((m) => m.t === 'op' && m.op && m.op.id === 'x'),
    'autor não recebe o próprio op de volta',
  );

  b.socket.close();
  const afterLeave = await waitFor(
    a.inbox,
    (m) => m.t === 'presence' && m.count === 1,
  );
  assert(afterLeave.count === 1, 'saída reduz a presença');

  console.log('OK: relay passou em presença, retransmissão e saída.');
  server.kill('SIGTERM');
  process.exit(0);
} catch (error) {
  console.error(error.message);
  server.kill('SIGTERM');
  process.exit(1);
}
