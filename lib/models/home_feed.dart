import 'game.dart';
import 'parsing.dart';

class PlatformInfo {
  const PlatformInfo({
    required this.slug,
    required this.name,
    required this.kind,
    required this.portCount,
  });

  final String slug;
  final String name;
  final String kind;
  final int portCount;

  bool get isSecondary => kind == 'other' || kind == 'multi';

  factory PlatformInfo.fromMap(Map<String, dynamic> map) => PlatformInfo(
    slug: asTextOr(map['slug'], ''),
    name: asTextOr(map['name'], '—'),
    kind: asTextOr(map['kind'], 'console'),
    portCount: asInt(map['port_count']),
  );
}

class GenreInfo {
  const GenreInfo({required this.name, required this.gameCount});

  final String name;
  final int gameCount;

  factory GenreInfo.fromMap(Map<String, dynamic> map) => GenreInfo(
    name: asTextOr(map['name'], '—'),
    gameCount: asInt(map['game_count']),
  );
}

class CatalogStats {
  const CatalogStats({this.games = 0, this.ports = 0, this.platforms = 0});

  final int games;
  final int ports;
  final int platforms;

  factory CatalogStats.fromMap(Map<String, dynamic> map) => CatalogStats(
    games: asInt(map['games']),
    ports: asInt(map['ports']),
    platforms: asInt(map['platforms']),
  );
}

// Facetas usadas pelos filtros de busca. Separadas do feed para permitir
// abrir a busca sem depender do carregamento completo da home.
class CatalogFacets {
  const CatalogFacets({
    this.platforms = const <PlatformInfo>[],
    this.genres = const <GenreInfo>[],
  });

  final List<PlatformInfo> platforms;
  final List<GenreInfo> genres;

  static const CatalogFacets empty = CatalogFacets();

  factory CatalogFacets.fromMap(Map<String, dynamic> map) => CatalogFacets(
    platforms: mapList(map['platforms'], PlatformInfo.fromMap),
    genres: mapList(map['genres'], GenreInfo.fromMap),
  );
}

/// Motivo da personalização de uma seção (ex.: gênero dominante do histórico).
/// Alimenta a microcopy "porque você curte".
class FeedSectionReason {
  const FeedSectionReason({required this.kind, required this.value});

  final String kind;
  final String value;

  static FeedSectionReason? maybeFrom(Object? value) {
    if (value is! Map) {
      return null;
    }
    final Map<String, dynamic> map = asMap(value);
    final String? kind = asText(map['kind']);
    final String? text = asText(map['value']);
    if (kind == null || text == null) {
      return null;
    }
    return FeedSectionReason(kind: kind, value: text);
  }
}

/// Uma seção do feed novo (`get_home_feed`): `hero`, `row` ou `grid`.
class HomeFeedSection {
  const HomeFeedSection({
    required this.key,
    required this.kind,
    this.title,
    this.reason,
    this.cursor,
    this.items = const <Game>[],
  });

  final String key;
  final String kind;
  final String? title;
  final FeedSectionReason? reason;

  /// Cursor keyset da próxima página (`{"score": 1.23, "id": "uuid"}`).
  /// Só a seção de descoberta pagina.
  final Map<String, dynamic>? cursor;
  final List<Game> items;

  bool get isHero => kind == 'hero';
  bool get isGrid => kind == 'grid';
  bool get isRow => kind == 'row';
  bool get isCategory => key.startsWith('category:');

  HomeFeedSection copyWith({
    List<Game>? items,
    Map<String, dynamic>? cursor,
    bool clearCursor = false,
  }) => HomeFeedSection(
    key: key,
    kind: kind,
    title: title,
    reason: reason,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    items: items ?? this.items,
  );

  factory HomeFeedSection.fromMap(Map<String, dynamic> map) => HomeFeedSection(
    key: asTextOr(map['key'], ''),
    kind: asTextOr(map['kind'], 'row'),
    title: asText(map['title']),
    reason: FeedSectionReason.maybeFrom(map['reason']),
    cursor: map['cursor'] is Map ? asMap(map['cursor']) : null,
    items: mapList(map['items'], Game.fromMap),
  );

  /// Serializa no mesmo formato lido por [HomeFeedSection.fromMap].
  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    'kind': kind,
    'title': title,
    'cursor': cursor,
    'items': items.map((Game game) => game.toMap()).toList(growable: false),
  };
}

class HomeFeed {
  const HomeFeed({
    this.sections = const <HomeFeedSection>[],
    this.personalized = false,
    this.seed = '',
    this.degraded = false,
    this.trending = const <Game>[],
    this.recent = const <Game>[],
    this.topRated = const <Game>[],
    this.free = const <Game>[],
    this.classics = const <Game>[],
    this.platforms = const <PlatformInfo>[],
    this.genres = const <GenreInfo>[],
    this.stats = const CatalogStats(),
  });

  /// Seções do feed novo, na ordem de exibição devolvida pelo servidor.
  final List<HomeFeedSection> sections;

  /// `true` quando o servidor encontrou histórico do usuário e personalizou.
  final bool personalized;

  /// Semente da sessão que gerou este feed (mesma seed ⇒ mesma ordem).
  final String seed;

  /// `true` quando o payload veio do fallback (RPC legada ou cache).
  final bool degraded;

  // ---- campos legados (RPC `home_feed`): mantidos como fallback ----
  final List<Game> trending;
  final List<Game> recent;
  final List<Game> topRated;
  final List<Game> free;
  final List<Game> classics;
  final List<PlatformInfo> platforms;
  final List<GenreInfo> genres;
  final CatalogStats stats;

  bool get isEmpty =>
      sections.isEmpty &&
      trending.isEmpty &&
      recent.isEmpty &&
      topRated.isEmpty &&
      free.isEmpty &&
      classics.isEmpty;

  HomeFeedSection? sectionByKey(String key) {
    for (final HomeFeedSection section in sections) {
      if (section.key == key) {
        return section;
      }
    }
    return null;
  }

  /// Lista de destaque para o carrossel: usa a seção `featured` do feed novo;
  /// no payload legado, prioriza populares e completa com recentes, sem repetir.
  List<Game> get highlights {
    final HomeFeedSection? featured = sectionByKey('featured');
    if (featured != null && featured.items.isNotEmpty) {
      return featured.items.take(6).toList(growable: false);
    }
    final List<Game> result = <Game>[];
    final Set<String> seen = <String>{};
    for (final List<Game> source in <List<Game>>[trending, recent, topRated]) {
      for (final Game game in source) {
        if (seen.add(game.id)) {
          result.add(game);
        }
        if (result.length >= 6) {
          return result;
        }
      }
    }
    return result;
  }

  HomeFeed copyWith({
    List<HomeFeedSection>? sections,
    bool? personalized,
    String? seed,
    bool? degraded,
    List<Game>? trending,
    List<Game>? recent,
    List<Game>? topRated,
    List<Game>? free,
    List<Game>? classics,
    List<PlatformInfo>? platforms,
    List<GenreInfo>? genres,
    CatalogStats? stats,
  }) => HomeFeed(
    sections: sections ?? this.sections,
    personalized: personalized ?? this.personalized,
    seed: seed ?? this.seed,
    degraded: degraded ?? this.degraded,
    trending: trending ?? this.trending,
    recent: recent ?? this.recent,
    topRated: topRated ?? this.topRated,
    free: free ?? this.free,
    classics: classics ?? this.classics,
    platforms: platforms ?? this.platforms,
    genres: genres ?? this.genres,
    stats: stats ?? this.stats,
  );

  factory HomeFeed.fromMap(Map<String, dynamic> map) {
    List<Game> games(String key) => mapList(map[key], Game.fromMap);
    final List<PlatformInfo> platforms = mapList(
      map['platforms'],
      PlatformInfo.fromMap,
    );
    final List<GenreInfo> genres = mapList(map['genres'], GenreInfo.fromMap);
    final CatalogStats stats = CatalogStats.fromMap(asMap(map['stats']));

    if (map.containsKey('sections')) {
      return HomeFeed(
        sections: mapList(map['sections'], HomeFeedSection.fromMap),
        personalized: map['personalized'] == true,
        seed: asTextOr(map['seed'], ''),
        degraded: map['degraded'] == true,
        platforms: platforms,
        genres: genres,
        stats: stats,
      );
    }

    // Payload LEGADO (`home_feed`): converte as cinco listas em seções para o
    // fallback continuar renderizável pela mesma tela e marca `degraded`.
    final List<Game> trending = games('trending');
    final List<Game> recent = games('recent');
    final List<Game> topRated = games('top_rated');
    final List<Game> free = games('free');
    final List<Game> classics = games('classics');
    return HomeFeed(
      trending: trending,
      recent: recent,
      topRated: topRated,
      free: free,
      classics: classics,
      sections: <HomeFeedSection>[
        if (trending.isNotEmpty)
          HomeFeedSection(key: 'trending', kind: 'row', items: trending),
        if (recent.isNotEmpty)
          HomeFeedSection(key: 'new_releases', kind: 'row', items: recent),
        if (topRated.isNotEmpty)
          HomeFeedSection(key: 'top_rated', kind: 'row', items: topRated),
        if (free.isNotEmpty)
          HomeFeedSection(key: 'free', kind: 'row', items: free),
        if (classics.isNotEmpty)
          HomeFeedSection(key: 'classics', kind: 'row', items: classics),
      ],
      degraded: true,
      platforms: platforms,
      genres: genres,
      stats: stats,
    );
  }
}
