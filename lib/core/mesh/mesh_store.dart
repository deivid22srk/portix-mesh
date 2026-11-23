import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Store local-first dos dados do usuário, com merge sem servidor.
///
/// Cada alteração vira um **op** com carimbo lógico `(t, d)` e é:
///   1. aplicada localmente (fonte de verdade do aparelho);
///   2. publicada na malha (ver [MeshNode]) para os outros dispositivos.
///
/// O merge é *last-write-wins* por `(t, d)`: sem relógio sincronizado, o par
/// `(carimbo, dispositivo)` desempata de forma determinística em qualquer
/// ordem de chegada. É o mínimo necessário para dois aparelhos convergirem
/// sem um servidor central decidir.
class MeshStore {
  MeshStore(this._prefs, this._deviceId) : _data = _load(_prefs);

  final SharedPreferences _prefs;
  final String _deviceId;
  final Map<String, dynamic> _data;
  static const String _storeKey = 'mesh.store';

  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _revision = 0;
  int _lastTs = 0;

  /// Emite a cada mudança local ou remota (a UI revalida o que estiver aberto).
  Stream<int> get changes => _changes.stream;
  int get revision => _revision;
  String get deviceId => _deviceId;

  // --------------------------------------------------------------- carregar

  static Map<String, dynamic> _load(SharedPreferences prefs) {
    final String? raw = prefs.getString(_storeKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
          for (final String key in _buckets) {
            if (data[key] is! Map) {
              data[key] = <String, dynamic>{};
            }
          }
          return data;
        }
      } on Object {
        // Store corrompido: recomeça; a malha repopula pelo sync dos pares.
      }
    }
    return <String, dynamic>{
      for (final String key in _buckets) key: <String, dynamic>{},
    };
  }

  static const List<String> _buckets = <String>[
    'fav',
    'lib',
    'review',
    'peer',
    'profile',
  ];

  Map<String, dynamic> _bucket(String name) =>
      _data[name] as Map<String, dynamic>;

  void _persist() {
    _revision++;
    _prefs.setString(_storeKey, jsonEncode(_data));
    if (!_changes.isClosed) {
      _changes.add(_revision);
    }
  }

  int _stamp() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _lastTs = now > _lastTs ? now : _lastTs + 1;
    return _lastTs;
  }

  /// Ordem total dos carimbos: `t` e, no empate, o id do dispositivo.
  static bool _wins(
    Map<String, dynamic> candidate,
    Map<String, dynamic>? current,
  ) {
    if (current == null) {
      return true;
    }
    final int a = (candidate['t'] as num?)?.toInt() ?? 0;
    final int b = (current['t'] as num?)?.toInt() ?? 0;
    if (a != b) {
      return a > b;
    }
    final String da = candidate['d']?.toString() ?? '';
    final String db = current['d']?.toString() ?? '';
    return da.compareTo(db) > 0;
  }

  // ------------------------------------------------------------- favoritos

  bool isFavorite(String gameId) =>
      _entryValue(_bucket('fav')[gameId]) == true;

  /// Alterna o favorito e devolve o op para publicar (null se sem mudança).
  Map<String, dynamic>? toggleFavorite(String gameId) =>
      setFavorite(gameId, !isFavorite(gameId));

  Map<String, dynamic>? setFavorite(String gameId, bool value) {
    if (isFavorite(gameId) == value) {
      return null;
    }
    final Map<String, dynamic> op = <String, dynamic>{
      'k': 'fav',
      'id': gameId,
      'v': value,
      't': _stamp(),
      'd': _deviceId,
    };
    applyOp(op);
    return op;
  }

  List<String> favoriteIds() => _idsWhere('fav', true);

  // ------------------------------------------------------------- biblioteca

  bool isInLibrary(String gameId) =>
      _entryValue(_bucket('lib')[gameId]) == true;

  Map<String, dynamic>? toggleLibrary(String gameId) =>
      setLibrary(gameId, !isInLibrary(gameId));

  Map<String, dynamic>? setLibrary(String gameId, bool value) {
    if (isInLibrary(gameId) == value) {
      return null;
    }
    final Map<String, dynamic> op = <String, dynamic>{
      'k': 'lib',
      'id': gameId,
      'v': value,
      't': _stamp(),
      'd': _deviceId,
    };
    applyOp(op);
    applyOp(_publishPeer());
    return op;
  }

  List<String> libraryIds() => _idsWhere('lib', true);

  bool? _entryValue(Object? entry) =>
      entry is Map ? entry['v'] as bool? : null;

  List<String> _idsWhere(String bucket, bool value) {
    final List<String> ids = <String>[];
    _bucket(bucket).forEach((String id, Object? entry) {
      if (_entryValue(entry) == value) {
        ids.add(id);
      }
    });
    ids.sort();
    return ids;
  }

  // ---------------------------------------------------------------- relatos

  /// Relatos de compatibilidade derivados das avaliações.
  ///
  /// O app grava o veredito de compatibilidade junto com a nota (a folha de
  /// feedback manda `verdict` em [submitReview]); então os "relatos" são a
  /// mesma informação vista na outra ponta. Formato de `CompatReport.fromMap`.
  List<Map<String, dynamic>> compatReportsFor(String gameId) {
    return <Map<String, dynamic>>[
      for (final Map<String, dynamic> review in reviewsFor(gameId))
        <String, dynamic>{
          'author': review['author'],
          'author_id': review['author_id'],
          'author_handle': review['author_handle'],
          'author_cover': review['author_cover'],
          'author_role': null,
          'status': review['verdict'] ?? 'good',
          'body': review['body'] ?? '',
          'rating': review['rating'] ?? 0,
          'fps': review['fps'],
          'brand': review['brand'],
          'model': review['model'],
          'soc': review['soc'],
          'gpu': review['gpu'],
          'ram_gb': review['ram_gb'],
          'created_at': review['created_at'],
        },
    ];
  }

  /// Contagens por veredito (para o card "Roda no seu celular?").
  Map<String, dynamic> compatSummaryFor(String gameId) {
    final Map<String, int> counts = <String, int>{};
    for (final Map<String, dynamic> report in compatReportsFor(gameId)) {
      final String status = report['status']?.toString() ?? 'good';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    final int total = counts.values.fold(0, (int a, int b) => a + b);
    return <String, dynamic>{
      'perfect': counts['perfect'] ?? 0,
      'good': counts['good'] ?? 0,
      'stutter': counts['stutter'] ?? 0,
      'unplayable': counts['unplayable'] ?? 0,
      'not_run': counts['not_run'] ?? 0,
      'total': total,
    };
  }

  // --------------------------------------------------------------- avaliações

  Map<String, dynamic> submitReview({
    required String gameId,
    required int rating,
    required String body,
    required String verdict,
    int? fps,
    String? brand,
    String? model,
    String? soc,
    String? gpu,
    int? ramGb,
  }) {
    final Map<String, dynamic> op = <String, dynamic>{
      'k': 'review',
      'id': gameId,
      'rating': rating,
      'body': body,
      'verdict': verdict,
      'fps': fps,
      'brand': brand,
      'model': model,
      'soc': soc,
      'gpu': gpu,
      'ram_gb': ramGb,
      't': _stamp(),
      'd': _deviceId,
    };
    applyOp(op);
    return op;
  }

  /// Avaliações conhecidas de um jogo (locais + dos pares), em formato de
  /// `Review.fromMap`.
  List<Map<String, dynamic>> reviewsFor(String gameId) {
    final List<Map<String, dynamic>> reviews = <Map<String, dynamic>>[];
    _bucket('review').forEach((String key, Object? entry) {
      final Map<String, dynamic>? map = _asMap(entry);
      if (map == null || map['id'] != gameId) {
        return;
      }
      final String device = map['d']?.toString() ?? '';
      reviews.add(<String, dynamic>{
        'id': '$gameId|$device',
        'rating': map['rating'] ?? 0,
        'body': map['body'] ?? '',
        'author': _authorName(device),
        'author_id': device,
        'author_handle': _peerField(device, 'handle'),
        'author_cover': _peerField(device, 'cover'),
        'created_at': _isoFromStamp(map['t']),
        'verdict': map['verdict'] ?? 'good',
        'fps': map['fps'],
        'brand': map['brand'],
        'model': map['model'],
        'soc': map['soc'],
        'gpu': map['gpu'],
        'ram_gb': map['ram_gb'],
      });
    });
    return reviews;
  }

  Map<String, dynamic>? myReview(String gameId) =>
      _asMap(_bucket('review')['$gameId|$_deviceId']);

  // ------------------------------------------------------------------- perfil

  Map<String, dynamic> get profile =>
      _asMap(_bucket('profile')['self']) ?? <String, dynamic>{};

  String get displayName => profile['display_name']?.toString() ?? '';
  String? get handle => profile['handle']?.toString();
  String? get coverUrl => profile['cover_url']?.toString();

  /// Grava o perfil local e devolve um op `peer` para a malha.
  Map<String, dynamic> saveProfile({
    String? displayName,
    String? coverUrl,
    String? handle,
    String? level,
  }) {
    final Map<String, dynamic> current = profile;
    final Map<String, dynamic> next = <String, dynamic>{
      'display_name': displayName?.trim() ?? current['display_name'],
      'cover_url': coverUrl ?? current['cover_url'],
      'handle': handle ?? current['handle'],
      'level': level ?? current['level'],
    };
    _bucket('profile')['self'] = <String, dynamic>{
      ...next,
      't': _stamp(),
      'd': _deviceId,
    };
    final Map<String, dynamic> peer = _publishPeer();
    applyOp(peer);
    return peer;
  }

  /// Op `peer` com o retrato público do dispositivo (nome, @, capa, nível,
  /// biblioteca) para os outros mostrarem perfil e busca de usuários.
  Map<String, dynamic> _publishPeer() {
    final Map<String, dynamic> map = <String, dynamic>{
      'k': 'peer',
      'd': _deviceId,
      'name': displayName,
      'handle': handle,
      'cover': coverUrl,
      'level': profile['level'],
      'lib': libraryIds(),
      't': _stamp(),
    };
    return map;
  }

  List<Map<String, dynamic>> peerProfiles() {
    final List<Map<String, dynamic>> peers = <Map<String, dynamic>>[];
    _bucket('peer').forEach((String device, Object? entry) {
      final Map<String, dynamic>? map = _asMap(entry);
      if (map == null) {
        return;
      }
      peers.add(<String, dynamic>{
        'id': device,
        'display_name': map['name']?.toString() ?? '',
        'handle': map['handle'],
        'cover_url': map['cover'],
        'level': map['level'],
        'library': map['lib'] is List ? map['lib'] : const <String>[],
      });
    });
    return peers;
  }

  Map<String, dynamic>? peerProfile(String deviceId) {
    if (deviceId == _deviceId) {
      return <String, dynamic>{
        'id': _deviceId,
        'display_name': displayName,
        'handle': handle,
        'cover_url': coverUrl,
        'level': profile['level'],
        'library': libraryIds(),
      };
    }
    final Map<String, dynamic>? map = _asMap(_bucket('peer')[deviceId]);
    if (map == null) {
      return null;
    }
    return <String, dynamic>{
      'id': deviceId,
      'display_name': map['name']?.toString() ?? '',
      'handle': map['handle'],
      'cover_url': map['cover'],
      'level': map['level'],
      'library': map['lib'] is List ? map['lib'] : const <String>[],
    };
  }

  // ------------------------------------------------------------------- merge

  /// Aplica um op remoto (ou local) com merge LWW.
  void applyOp(Map<String, dynamic> op) {
    final bool changed = _apply(op);
    if (changed) {
      _persist();
    }
  }

  /// Aplica sem persistir/notificar; devolve se houve mudança.
  bool _apply(Map<String, dynamic> op) {
    final Object? kind = op['k'];
    if (kind == 'sync') {
      final Object? entries = op['entries'];
      bool changed = false;
      if (entries is List) {
        for (final Object? entry in entries) {
          if (entry is Map && _apply(Map<String, dynamic>.from(entry))) {
            changed = true;
          }
        }
      }
      return changed;
    }
    final String? id = op['id']?.toString();
    final String device = op['d']?.toString() ?? '';
    switch (kind) {
      case 'fav':
        return _mergeFlag('fav', id, op);
      case 'lib':
        return _mergeFlag('lib', id, op);
      case 'review':
        return _mergeKeyed('review', '$id|$device', op);
      case 'peer':
        return _mergeKeyed('peer', device, op);
      default:
        return false;
    }
  }

  bool _mergeFlag(String bucket, String? id, Map<String, dynamic> op) {
    if (id == null) {
      return false;
    }
    final Map<String, dynamic> map = _bucket(bucket);
    final Map<String, dynamic>? current = _asMap(map[id]);
    if (!_wins(op, current)) {
      return false;
    }
    map[id] = op;
    return true;
  }

  bool _mergeKeyed(String bucket, String key, Map<String, dynamic> op) {
    if (key == '|' || key.isEmpty) {
      return false;
    }
    final Map<String, dynamic> map = _bucket(bucket);
    final Map<String, dynamic>? current = _asMap(map[key]);
    if (!_wins(op, current)) {
      return false;
    }
    map[key] = op;
    return true;
  }

  /// Estado completo como um único op `sync` (usado ao encontrar um par novo).
  Map<String, dynamic> fullState() {
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (final String bucket in <String>['fav', 'lib', 'review']) {
      _bucket(bucket).forEach((String key, Object? entry) {
        final Map<String, dynamic>? map = _asMap(entry);
        if (map != null) {
          entries.add(map);
        }
      });
    }
    entries.add(_publishPeer());
    return <String, dynamic>{'k': 'sync', 'entries': entries};
  }

  // ------------------------------------------------------------------ helpers

  String _authorName(String device) {
    if (device == _deviceId) {
      return displayName.isEmpty ? 'Você' : displayName;
    }
    final String? name = _peerField(device, 'name');
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Jogador ${device.length >= 6 ? device.substring(0, 6) : device}';
  }

  String? _peerField(String device, String field) {
    final Map<String, dynamic>? map = _asMap(_bucket('peer')[device]);
    final Object? value = map?[field];
    final String text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static String? _isoFromStamp(Object? stamp) {
    final int? ts = (stamp as num?)?.toInt();
    if (ts == null || ts <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
        .toIso8601String();
  }

  void dispose() {
    _changes.close();
  }
}
