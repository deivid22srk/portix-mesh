import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mesh_config.dart';
import 'mesh_identity.dart';

/// Um dispositivo visto na malha.
class MeshPeer {
  const MeshPeer({
    required this.deviceId,
    required this.name,
    required this.viaLan,
  });

  final String deviceId;
  final String name;
  final bool viaLan;
}

/// Retrato da malha: quantos dispositivos e por quais caminhos.
class MeshPresence {
  const MeshPresence({
    this.devices = 0,
    this.relaysOnline = 0,
    this.relaysTotal = 0,
    this.lanDevices = 0,
    this.peers = const <MeshPeer>[],
  });

  /// Dispositivos distintos (fora o próprio) vistos nos relays + LAN.
  final int devices;
  final int relaysOnline;
  final int relaysTotal;
  final int lanDevices;
  final List<MeshPeer> peers;

  bool get isEmpty => devices == 0;
}

/// Estado de um relay conectado.
class MeshRelayStatus {
  const MeshRelayStatus({required this.url, required this.online});

  final String url;
  final bool online;
}

class _SeenPeer {
  _SeenPeer({required this.deviceId, required this.name, required this.seenAt});

  final String deviceId;
  String name;
  int seenAt;
  bool viaLan = false;
}

/// Nó local da malha P2P.
///
/// Conecta a **todos** os relays configurados ao mesmo tempo (nenhum é
/// obrigatório), mantém a presença e transmite `ops` entre os dispositivos.
/// Também anuncia na rede local, para funcionar sem relay nenhum.
///
/// Nada aqui é crítico para o app: o catálogo é local. Se todos os relays
/// caírem, o app continua 100% funcional — só a contagem de dispositivos
/// online no momento fica em zero.
class MeshNode {
  MeshNode({
    required this.identity,
    required MeshConfig config,
    required this.onOp,
    this.onSyncRequest,
  }) : _config = config,
       _relayUrls = config.relayUrls();

  final MeshIdentity identity;
  final MeshConfig _config;

  /// Recebe um op de outro dispositivo (o store faz o merge).
  final void Function(Map<String, dynamic> op) onOp;

  /// Pede o estado completo (usado no `sync` de entrada).
  final void Function()? onSyncRequest;

  List<String> _relayUrls;
  final List<_RelayConnection> _connections = <_RelayConnection>[];
  final Map<String, _SeenPeer> _seen = <String, _SeenPeer>{};

  final StreamController<MeshPresence> _presence =
      StreamController<MeshPresence>.broadcast();
  MeshPresence _current = const MeshPresence();
  _LanDiscovery? _lan;
  Timer? _sweep;
  Timer? _sync;
  bool _started = false;

  static const Duration _peerTtl = Duration(seconds: 45);
  static const Duration _sweepEvery = Duration(seconds: 5);
  static const Duration _syncEvery = Duration(seconds: 45);

  Stream<MeshPresence> get presence => _presence.stream;
  MeshPresence get current => _current;
  int get devices => _current.devices;

  /// Estado de cada relay configurado (para a tela de rede).
  List<MeshRelayStatus> get relays => <MeshRelayStatus>[
    for (final _RelayConnection connection in _connections)
      MeshRelayStatus(url: connection.url, online: connection.online),
  ];

  bool get running => _started;

  /// Liga a malha (idempotente). Nunca lança.
  Future<void> start() async {
    if (_started || !_config.enabled) {
      return;
    }
    _started = true;
    _relayUrls = _config.relayUrls();
    await _applyRelays();
    _lan = _LanDiscovery(
      identity: identity,
      onBeacon: _onLanBeacon,
      onGone: (String deviceId) => _seen.remove(deviceId),
    );
    await _lan!.start();
    _sweep = Timer.periodic(_sweepEvery, (_) => _prune());
    _sync = Timer.periodic(_syncEvery, (_) => onSyncRequest?.call());
    _emit();
  }

  Future<void> stop() async {
    _started = false;
    _sweep?.cancel();
    _sync?.cancel();
    await _lan?.stop();
    _lan = null;
    for (final _RelayConnection connection in _connections) {
      connection.dispose();
    }
    _connections.clear();
    _seen.clear();
    _emit();
  }

  /// Reaplica a lista de relays (após edição nas configurações).
  Future<void> reloadRelays() async {
    if (!_started) {
      return;
    }
    _relayUrls = _config.relayUrls();
    await _applyRelays();
    _emit();
  }

  Future<void> _applyRelays() async {
    for (final _RelayConnection connection in _connections) {
      connection.dispose();
    }
    _connections.clear();
    for (final String url in _relayUrls) {
      final _RelayConnection connection = _RelayConnection(
        url: url,
        identity: identity,
        onOp: onOp,
        onPresence: _onRelayPresence,
        onStatus: _emit,
      );
      _connections.add(connection);
      connection.start();
    }
  }

  /// Publica um op em todos os relays conectados.
  void publish(Map<String, dynamic> op) {
    for (final _RelayConnection connection in _connections) {
      connection.publish(op);
    }
  }

  /// Pede o estado completo (sync de entrada).
  void requestSync() => onSyncRequest?.call();

  void _onRelayPresence(List<dynamic> devices) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final Object? item in devices) {
      if (item is! Map) {
        continue;
      }
      final String deviceId = item['device']?.toString() ?? '';
      if (deviceId.isEmpty || deviceId == identity.deviceId) {
        continue;
      }
      final String name = item['name']?.toString() ?? '';
      final _SeenPeer? existing = _seen[deviceId];
      if (existing == null) {
        _seen[deviceId] = _SeenPeer(
          deviceId: deviceId,
          name: name,
          seenAt: now,
        );
        onSyncRequest?.call();
      } else {
        existing.seenAt = now;
        if (name.isNotEmpty) {
          existing.name = name;
        }
      }
    }
    _emit();
  }

  void _onLanBeacon(MeshPeer peer) {
    final _SeenPeer? existing = _seen[peer.deviceId];
    if (existing == null) {
      _seen[peer.deviceId] = _SeenPeer(
        deviceId: peer.deviceId,
        name: peer.name,
        seenAt: DateTime.now().millisecondsSinceEpoch,
      )..viaLan = true;
      onSyncRequest?.call();
    } else {
      existing.seenAt = DateTime.now().millisecondsSinceEpoch;
      existing.viaLan = true;
      if (peer.name.isNotEmpty) {
        existing.name = peer.name;
      }
    }
    _emit();
  }

  void _prune() {
    final int cutoff =
        DateTime.now().millisecondsSinceEpoch - _peerTtl.inMilliseconds;
    bool removed = false;
    _seen.removeWhere((String _, _SeenPeer peer) {
      if (peer.seenAt < cutoff) {
        removed = true;
        return true;
      }
      return false;
    });
    if (removed) {
      _emit();
    }
  }

  void _emit() {
    final List<MeshPeer> peers = <MeshPeer>[
      for (final _SeenPeer peer in _seen.values)
        MeshPeer(
          deviceId: peer.deviceId,
          name: peer.name,
          viaLan: peer.viaLan,
        ),
    ];
    final MeshPresence next = MeshPresence(
      devices: peers.length,
      relaysOnline: _connections.where((_RelayConnection c) => c.online).length,
      relaysTotal: _connections.length,
      lanDevices: peers.where((MeshPeer p) => p.viaLan).length,
      peers: peers,
    );
    // Só emite quando algo muda de fato: o nó roda em background e uma
    // emissão por batida acordaria a UI sem necessidade.
    if (_sameAs(next, _current)) {
      return;
    }
    _current = next;
    if (!_presence.isClosed) {
      _presence.add(next);
    }
  }

  bool _sameAs(MeshPresence a, MeshPresence b) =>
      a.devices == b.devices &&
      a.relaysOnline == b.relaysOnline &&
      a.relaysTotal == b.relaysTotal &&
      a.lanDevices == b.lanDevices;

  Future<void> dispose() async {
    await stop();
    await _presence.close();
  }
}

// ---------------------------------------------------------------------------
// Uma conexão WebSocket com um relay, com reconexão exponencial.
// ---------------------------------------------------------------------------

class _RelayConnection {
  _RelayConnection({
    required this.url,
    required this.identity,
    required this.onOp,
    required this.onPresence,
    required this.onStatus,
  });

  final String url;
  final MeshIdentity identity;
  final void Function(Map<String, dynamic> op) onOp;
  final void Function(List<dynamic> devices) onPresence;
  final void Function() onStatus;

  WebSocket? _socket;
  Timer? _retry;
  Timer? _heartbeat;
  int _attempt = 0;
  bool _disposed = false;

  bool get online => _socket != null;

  void start() => _connect();

  Future<void> _connect() async {
    if (_disposed) {
      return;
    }
    try {
      final WebSocket socket = await WebSocket.connect(
        url,
      ).timeout(const Duration(seconds: 12));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempt = 0;
      _send(<String, dynamic>{
        't': 'hello',
        'room': kMeshRoom,
        'device': identity.deviceId,
        'name': identity.displayName,
      });
      _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
        _send(<String, dynamic>{'t': 'who'});
      });
      socket.listen(
        _onData,
        onDone: _onDown,
        onError: (Object _) => _onDown(),
        cancelOnError: true,
      );
      onStatus();
    } on Object {
      _onDown();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) {
      return;
    }
    Map<String, dynamic> message;
    try {
      final Object? decoded = jsonDecode(data);
      if (decoded is! Map) {
        return;
      }
      message = Map<String, dynamic>.from(decoded);
    } on Object {
      return;
    }
    switch (message['t']) {
      case 'presence':
        final Object? devices = message['devices'];
        onPresence(devices is List ? devices : const <dynamic>[]);
        break;
      case 'op':
        final Object? op = message['op'];
        if (op is Map) {
          onOp(Map<String, dynamic>.from(op));
        }
        break;
      default:
        break;
    }
  }

  void _onDown() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _socket = null;
    onStatus();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) {
      return;
    }
    _attempt = _attempt >= 5 ? 5 : _attempt + 1;
    final int ms = 1000 * (1 << (_attempt - 1));
    final int capped = ms > 30000 ? 30000 : ms;
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: capped), _connect);
  }

  void publish(Map<String, dynamic> op) {
    _send(<String, dynamic>{'t': 'pub', 'op': op});
  }

  void _send(Map<String, dynamic> message) {
    final WebSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    try {
      socket.add(jsonEncode(message));
    } on Object {
      _onDown();
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _heartbeat?.cancel();
    final WebSocket? socket = _socket;
    _socket = null;
    try {
      socket?.close();
    } on Object {
      // socket já morto
    }
  }
}

// ---------------------------------------------------------------------------
// Descoberta na rede local (UDP broadcast) — sem relay nenhum.
// ---------------------------------------------------------------------------

class _LanDiscovery {
  _LanDiscovery({
    required this.identity,
    required this.onBeacon,
    required this.onGone,
  });

  final MeshIdentity identity;
  final void Function(MeshPeer peer) onBeacon;
  final void Function(String deviceId) onGone;

  static const int _port = 48899;
  static const Duration _beaconEvery = Duration(seconds: 10);

  RawDatagramSocket? _socket;
  Timer? _beacon;
  final Map<String, int> _lastSeen = <String, int>{};

  Future<void> start() async {
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
      );
      _socket = socket;
      socket.broadcastEnabled = true;
      socket.listen(_onEvent);
      _sendBeacon();
      _beacon = Timer.periodic(_beaconEvery, (_) {
        _sendBeacon();
        _prune();
      });
    } on Object {
      // Sem permissão de broadcast (ou porta ocupada): ficamos só com relays.
      _socket = null;
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }
    final Datagram? datagram = _socket?.receive();
    if (datagram == null) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map) {
        return;
      }
      final String deviceId = decoded['device']?.toString() ?? '';
      if (deviceId.isEmpty || deviceId == identity.deviceId) {
        return;
      }
      _lastSeen[deviceId] = DateTime.now().millisecondsSinceEpoch;
      onBeacon(
        MeshPeer(
          deviceId: deviceId,
          name: decoded['name']?.toString() ?? '',
          viaLan: true,
        ),
      );
    } on Object {
      // pacote de outra origem: ignora
    }
  }

  void _prune() {
    final int cutoff =
        DateTime.now().millisecondsSinceEpoch - (_beaconEvery * 3).inMilliseconds;
    _lastSeen.removeWhere((String deviceId, int seenAt) {
      if (seenAt < cutoff) {
        onGone(deviceId);
        return true;
      }
      return false;
    });
  }

  void _sendBeacon() {
    final RawDatagramSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    final List<int> payload = utf8.encode(
      jsonEncode(<String, dynamic>{
        'device': identity.deviceId,
        'name': identity.displayName,
        'room': kMeshRoom,
      }),
    );
    try {
      socket.send(payload, InternetAddress('255.255.255.255'), _port);
    } on Object {
      // broadcast indisponível: relay cobre
    }
  }

  Future<void> stop() async {
    _beacon?.cancel();
    _socket?.close();
    _socket = null;
  }
}
