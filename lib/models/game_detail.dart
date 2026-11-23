import 'compat_summary.dart';
import 'game.dart';
import 'parsing.dart';

class GamePort {
  const GamePort({
    required this.id,
    required this.portKey,
    required this.platformName,
    required this.platformSlug,
    this.project,
    this.source,
    this.url,
    this.dataUrl,
    this.developer,
    this.version,
    this.lastUpdate,
    this.dateAdded,
    this.needsGameFiles = false,
    this.needsGameFilesNote,
    this.works,
    this.controllerSupport,
    this.notes,
    this.visits = 0,
  });

  final String id;
  final String portKey;
  final String platformName;
  final String platformSlug;
  final String? project;
  final String? source;
  final String? url;
  final String? dataUrl;
  final String? developer;
  final String? version;
  final DateTime? lastUpdate;
  final DateTime? dateAdded;
  final bool needsGameFiles;
  final String? needsGameFilesNote;
  final String? works;
  final String? controllerSupport;
  final String? notes;
  final int visits;

  bool get isFree {
    final String label = (source ?? '').toLowerCase();
    return label.startsWith('free') || label.startsWith('mirror');
  }

  factory GamePort.fromMap(Map<String, dynamic> map) => GamePort(
    id: asTextOr(map['id'], ''),
    portKey: asTextOr(map['port_key'], ''),
    platformName: asTextOr(map['platform_name'], '—'),
    platformSlug: asTextOr(map['platform_slug'], ''),
    project: asText(map['project']),
    source: asText(map['source']),
    url: asText(map['url']),
    dataUrl: asText(map['data_url']),
    developer: asText(map['developer']),
    version: asText(map['version']),
    lastUpdate: asDate(map['last_update']),
    dateAdded: asDate(map['date_added']),
    needsGameFiles: map['needs_game_files'] == true,
    needsGameFilesNote: asText(map['needs_game_files_note']),
    works: asText(map['works']),
    controllerSupport: asText(map['controller_support']),
    notes: asText(map['notes']),
    visits: asInt(map['visits']),
  );
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.body,
    required this.author,
    this.createdAt,
    this.verdict = 'good',
    this.fps,
    this.brand,
    this.model,
    this.soc,
    this.gpu,
    this.ramGb,
    this.authorRole,
    this.authorId,
    this.authorHandle,
    this.authorCover,
  });

  final String id;
  final int rating;
  final String body;
  final String author;
  final DateTime? createdAt;
  final String verdict;
  final int? fps;
  final String? brand;
  final String? model;
  final String? soc;
  final String? gpu;
  final int? ramGb;

  /// 'root' | 'admin' | 'moderator' quando o autor é administrador.
  final String? authorRole;

  final String? authorId;
  final String? authorHandle;
  final String? authorCover;

  String get deviceLabel {
    final List<String> parts = <String>[?brand, ?model];
    return parts.isEmpty ? 'Aparelho' : parts.join(' ');
  }

  factory Review.fromMap(Map<String, dynamic> map) => Review(
    id: asTextOr(map['id'], ''),
    rating: asInt(map['rating']),
    body: asTextOr(map['body'], ''),
    author: asTextOr(map['author'], ''),
    createdAt: asDate(map['created_at']),
    verdict: asTextOr(map['verdict'], 'good'),
    fps: map['fps'] == null ? null : asInt(map['fps']),
    brand: asText(map['brand']),
    model: asText(map['model']),
    soc: asText(map['soc']),
    gpu: asText(map['gpu']),
    ramGb: map['ram_gb'] == null ? null : asInt(map['ram_gb']),
    authorId: asText(map['author_id']),
    authorHandle: asText(map['author_handle']),
    authorCover: asText(map['author_cover']),
  );
}

class GameDetail {
  const GameDetail({
    required this.game,
    this.ports = const <GamePort>[],
    this.reviews = const <Review>[],
    this.related = const <Game>[],
    this.compat = const CompatSummary(),
  });

  final Game game;
  final List<GamePort> ports;
  final List<Review> reviews;
  final List<Game> related;
  final CompatSummary compat;

  GamePort? get primaryPort {
    for (final GamePort port in ports) {
      if (port.url != null) {
        return port;
      }
    }
    return ports.isEmpty ? null : ports.first;
  }

  factory GameDetail.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> game = asMap(map['game']);
    if (game.isEmpty) {
      throw const FormatException('detalhe sem jogo');
    }
    return GameDetail(
      game: Game.fromMap(game),
      ports: asMapList(
        map['ports'],
      ).map(GamePort.fromMap).toList(growable: false),
      reviews: asMapList(
        map['reviews'],
      ).map(Review.fromMap).toList(growable: false),
      related: asMapList(
        map['related'],
      ).map(Game.fromMap).toList(growable: false),
      compat: CompatSummary.fromMap(asMap(map['compat'])),
    );
  }
}
