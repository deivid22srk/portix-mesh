import 'game.dart';
import 'parsing.dart';

class DownloadRecord {
  const DownloadRecord({
    required this.gameId,
    required this.status,
    required this.progress,
    this.title = '',
    this.slug = '',
    this.coverUrl,
    this.portKey,
  });

  final String gameId;
  final String status;
  final int progress;
  final String title;
  final String slug;
  final String? coverUrl;
  final String? portKey;

  factory DownloadRecord.fromMap(Map<String, dynamic> map) => DownloadRecord(
    gameId: asTextOr(map['game_id'], ''),
    status: asTextOr(map['status'], 'queued'),
    progress: asInt(map['progress']),
    title: asTextOr(map['title'], ''),
    slug: asTextOr(map['slug'], ''),
    coverUrl: asText(map['cover_url']),
    portKey: asText(map['port_key']),
  );
}

class Collections {
  const Collections({
    this.favorites = const <Game>[],
    this.library = const <Game>[],
    this.downloads = const <DownloadRecord>[],
  });

  final List<Game> favorites;
  final List<Game> library;
  final List<DownloadRecord> downloads;

  static const Collections empty = Collections();

  bool isFavorite(String gameId) =>
      favorites.any((Game game) => game.id == gameId);

  bool isInLibrary(String gameId) =>
      library.any((Game game) => game.id == gameId);

  Collections withFavorite(Game game) => Collections(
    favorites: <Game>[
      game,
      ...favorites.where((Game item) => item.id != game.id),
    ],
    library: library,
    downloads: downloads,
  );

  Collections withoutFavorite(String gameId) => Collections(
    favorites: favorites
        .where((Game game) => game.id != gameId)
        .toList(growable: false),
    library: library,
    downloads: downloads,
  );

  Collections withLibraryGame(Game game) => Collections(
    favorites: favorites,
    library: <Game>[game, ...library.where((Game item) => item.id != game.id)],
    downloads: downloads,
  );

  Collections withoutLibraryGame(String gameId) => Collections(
    favorites: favorites,
    library: library
        .where((Game game) => game.id != gameId)
        .toList(growable: false),
    downloads: downloads,
  );

  factory Collections.fromMap(Map<String, dynamic> map) => Collections(
    favorites: asMapList(
      map['favorites'],
    ).map(Game.fromMap).toList(growable: false),
    library: asMapList(
      map['library'],
    ).map(Game.fromMap).toList(growable: false),
    downloads: asMapList(
      map['downloads'],
    ).map(DownloadRecord.fromMap).toList(growable: false),
  );
}
