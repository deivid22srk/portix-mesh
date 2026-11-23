import 'game.dart';
import 'home_feed.dart';
import 'parsing.dart';

/// Critérios de ordenação da busca.
///  relevance — ranking por relevância (exato > prefixo > parcial > similar)
///  trending  — mais baixados/visitados (popularidade)
///  recent    — mais recentes (released_on desc)
///  rating    — melhor avaliados
///  az        — ordem alfabética (A–Z, acento/caixa ignorados)
///  year      — ano de lançamento desc (legado, mantido)
const List<String> kSearchSorts = <String>[
  'relevance',
  'trending',
  'recent',
  'rating',
  'az',
];

/// Ordenação padrão do modo descoberta.
const String kDefaultSort = 'trending';

class SearchFilters {
  const SearchFilters({
    this.platform,
    this.genre,
    this.freeOnly = false,
    this.needsRom = false,
    this.minRating,
    this.sort = kDefaultSort,
  });

  final String? platform;
  final String? genre;
  final bool freeOnly;
  final bool needsRom;

  /// Avaliação mínima (0 = sem filtro; existe `rating_avg` real no catálogo).
  final double? minRating;

  final String sort;

  bool get isDefault =>
      platform == null &&
      genre == null &&
      !freeOnly &&
      !needsRom &&
      minRating == null &&
      sort == kDefaultSort;

  int get activeCount =>
      (platform == null ? 0 : 1) +
      (genre == null ? 0 : 1) +
      (freeOnly ? 1 : 0) +
      (needsRom ? 1 : 0) +
      (minRating == null ? 0 : 1) +
      (sort == kDefaultSort ? 0 : 1);

  /// Igualdade de conteúdo (o sheet devolve instâncias novas a cada aplicação).
  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.platform == platform &&
      other.genre == genre &&
      other.freeOnly == freeOnly &&
      other.needsRom == needsRom &&
      other.minRating == minRating &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(platform, genre, freeOnly, needsRom, minRating, sort);

  SearchFilters copyWith({
    String? platform,
    String? genre,
    bool? freeOnly,
    bool? needsRom,
    double? minRating,
    String? sort,
    bool clearPlatform = false,
    bool clearGenre = false,
    bool clearMinRating = false,
  }) => SearchFilters(
    platform: clearPlatform ? null : (platform ?? this.platform),
    genre: clearGenre ? null : (genre ?? this.genre),
    freeOnly: freeOnly ?? this.freeOnly,
    needsRom: needsRom ?? this.needsRom,
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    sort: sort ?? this.sort,
  );
}

class SearchRequest {
  const SearchRequest({
    this.query = '',
    this.filters = const SearchFilters(),
    this.offset = 0,
    this.limit = 24,
    this.cursor,
  });

  final String query;
  final SearchFilters filters;
  final int offset;
  final int limit;

  /// Cursor keyset da próxima página (devolvido pela RPC `search_games_v2`).
  final Map<String, dynamic>? cursor;
}

class SearchPayload {
  const SearchPayload({
    this.items = const <Game>[],
    this.total = 0,
    this.cursor,
    this.suggestion,
  });

  final List<Game> items;
  final int total;

  /// Cursor keyset para a próxima página; null = fim da lista.
  final Map<String, dynamic>? cursor;

  /// "Você quis dizer…?": título mais próximo quando a busca não achou nada.
  final String? suggestion;
}

// ---------------------------------------------------------------------------
// Sugestões instantâneas (`search_suggest`): uma chamada, quatro tipos.
// ---------------------------------------------------------------------------

class DeveloperInfo {
  const DeveloperInfo({required this.name, required this.gameCount});

  final String name;
  final int gameCount;

  factory DeveloperInfo.fromMap(Map<String, dynamic> map) => DeveloperInfo(
    name: asTextOr(map['name'], '—'),
    gameCount: asInt(map['game_count']),
  );
}

class SuggestPayload {
  const SuggestPayload({
    this.games = const <Game>[],
    this.genres = const <GenreInfo>[],
    this.developers = const <DeveloperInfo>[],
    this.platforms = const <PlatformInfo>[],
  });

  final List<Game> games;
  final List<GenreInfo> genres;
  final List<DeveloperInfo> developers;
  final List<PlatformInfo> platforms;

  bool get isEmpty =>
      games.isEmpty &&
      genres.isEmpty &&
      developers.isEmpty &&
      platforms.isEmpty;

  factory SuggestPayload.fromMap(Map<String, dynamic> map) => SuggestPayload(
    games: mapList(map['games'], Game.fromMap),
    genres: mapList(map['genres'], GenreInfo.fromMap),
    developers: mapList(map['developers'], DeveloperInfo.fromMap),
    platforms: mapList(map['platforms'], PlatformInfo.fromMap),
  );
}
