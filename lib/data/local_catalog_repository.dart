import '../core/cache_store.dart';
import '../core/env.dart';
import '../core/mesh/mesh_node.dart';
import '../core/mesh/mesh_store.dart';
import '../models/app_update.dart';
import '../models/collections.dart';
import '../models/compat_report.dart';
import '../models/explore.dart';
import '../models/game.dart';
import '../models/game_detail.dart';
import '../models/home_feed.dart';
import '../models/news.dart';
import '../models/parsing.dart';
import '../models/profile.dart';
import '../models/public_profile.dart';
import '../models/search.dart';
import '../models/user_result.dart';
import 'catalog_repository.dart';
import 'local_catalog.dart';

/// Backend do PORTIX **sem servidor**: o catálogo é local (asset embutido) e
/// os dados do usuário vivem no aparelho, sincronizados pela malha P2P.
///
/// Implementa o mesmo contrato do antigo repositório Supabase, então nenhuma
/// tela precisou mudar de ideia: o que mudou foi a origem dos dados.
class LocalCatalogRepository
    implements
        CatalogRepository,
        HomeFeedAlgorithmRepository,
        ExploreDiscoveryRepository {
  LocalCatalogRepository({
    required CacheStore cache,
    required MeshStore store,
    MeshNode? mesh,
    Future<LocalCatalog> Function()? catalog,
  }) : _cache = cache,
       _store = store,
       _mesh = mesh,
       _catalogLoader = catalog ?? LocalCatalog.load;

  final CacheStore _cache;
  final MeshStore _store;
  final MeshNode? _mesh;
  final Future<LocalCatalog> Function() _catalogLoader;

  LocalCatalog? _catalog;
  Future<LocalCatalog>? _loading;
  List<Map<String, dynamic>>? _developers;
  final Map<String, List<Map<String, dynamic>>> _discoverCache =
      <String, List<Map<String, dynamic>>>{};

  static const String _homeFeedCacheKey = 'home_feed_v2';
  static const String _homeCacheKey = 'home_feed';
  static const String _exploreCacheKey = 'explore_feed_v1';

  static const int _feedPageSize = 12;

  Future<LocalCatalog> _ready() {
    final LocalCatalog? loaded = _catalog;
    if (loaded != null) {
      return Future<LocalCatalog>.value(loaded);
    }
    return _loading ??= _catalogLoader().then((
      LocalCatalog catalog,
    ) {
      _catalog = catalog;
      return catalog;
    });
  }

  /// Catálogo já carregado, quando houver (as telas abrem sem await).
  LocalCatalog? get loadedCatalog => _catalog;

  Future<void> warmUp() async {
    await _ready();
  }

  // --------------------------------------------------------------- leitura

  @override
  HomeFeed? readCachedHome() {
    final Map<String, dynamic>? fresh = _cache.readMap(_homeFeedCacheKey);
    final Map<String, dynamic>? raw = fresh ?? _cache.readMap(_homeCacheKey);
    if (raw == null) {
      return null;
    }
    try {
      return HomeFeed.fromMap(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<HomeFeed> fetchHome() async {
    final LocalCatalog catalog = await _ready();
    final Map<String, dynamic> map = <String, dynamic>{
      'trending': _games(_topByActivity(catalog, 20)),
      'recent': _games(_topByRecent(catalog, 20)),
      'top_rated': _games(_topByRating(catalog, 20)),
      'free': _games(
        catalog.games.where((Map<String, dynamic> g) => g['is_free'] == true)
            .take(20)
            .toList(),
      ),
      'classics': _games(_classics(catalog, 20)),
      'platforms': catalog.platforms,
      'genres': catalog.genres,
      'stats': catalog.stats,
    };
    await _cache.writeMap(_homeCacheKey, map);
    return HomeFeed.fromMap(map);
  }

  @override
  Future<HomeFeed> fetchHomeFeed({
    required String seed,
    List<String> seen = const <String>[],
    Map<String, dynamic>? cursor,
    List<String>? sections,
  }) async {
    final LocalCatalog catalog = await _ready();
    final List<Map<String, dynamic>> discover = _discoverOrder(catalog, seed);
    final List<String> wanted = sections ?? const <String>[];
    final List<HomeFeedSection> built = <HomeFeedSection>[];
    final bool onlyDiscover = wanted.length == 1 && wanted.first == 'discover';

    if (!onlyDiscover) {
      final List<Map<String, dynamic>> featured = _topByActivity(catalog, 6);
      if (featured.isNotEmpty) {
        built.add(
          HomeFeedSection(
            key: 'featured',
            kind: 'hero',
            items: _games(featured),
          ),
        );
      }
      _addRow(built, 'trending', _topByActivity(catalog, 20));
      _addRow(built, 'new_releases', _topByRecent(catalog, 20));
      _addRow(built, 'free', _free(catalog, 20));
      _addRow(built, 'classics', _classics(catalog, 20));
      final List<Map<String, dynamic>> rated = _topByRating(catalog, 20);
      if (rated.isNotEmpty) {
        _addRow(built, 'top_rated', rated);
      }
      for (final Map<String, dynamic> genre in catalog.genres.take(4)) {
        final String name = genre['name']?.toString() ?? '';
        if (name.isEmpty) {
          continue;
        }
        final List<Map<String, dynamic>> items = catalog.games
            .where(
              (Map<String, dynamic> g) => _matchesGenre(g, name),
            )
            .take(20)
            .toList();
        if (items.length >= 3) {
          built.add(
            HomeFeedSection(
              key: 'category:${name.toLowerCase()}',
              kind: 'row',
              title: name,
              items: _games(items),
            ),
          );
        }
      }
    }

    final List<Map<String, dynamic>> page = discover
        .take(_feedPageSize)
        .toList();
    built.add(
      HomeFeedSection(
        key: 'discover',
        kind: 'grid',
        items: _games(page),
        cursor: discover.length <= _feedPageSize
            ? null
            : <String, dynamic>{'score': _feedPageSize, 'id': 'discover'},
      ),
    );

    final Map<String, dynamic> map = <String, dynamic>{
      'seed': seed,
      'personalized': false,
      'degraded': false,
      'sections': <Map<String, dynamic>>[
        for (final HomeFeedSection section in built) section.toMap(),
      ],
      'platforms': catalog.platforms,
      'genres': catalog.genres,
      'stats': catalog.stats,
    };
    await _cache.writeMap(_homeFeedCacheKey, map);
    return HomeFeed.fromMap(map);
  }

  @override
  Future<HomeFeed> loadMoreDiscover({
    required String seed,
    required Map<String, dynamic> cursor,
    List<String> seen = const <String>[],
    List<String>? sections,
  }) async {
    final LocalCatalog catalog = await _ready();
    final List<Map<String, dynamic>> discover = _discoverOrder(catalog, seed);
    final int offset = asInt(cursor['score']);
    final int end = offset + _feedPageSize;
    final List<Map<String, dynamic>> page = offset >= discover.length
        ? const <Map<String, dynamic>>[]
        : discover.sublist(offset, end > discover.length ? discover.length : end);
    return HomeFeed.fromMap(<String, dynamic>{
      'seed': seed,
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'discover',
          'kind': 'grid',
          'items': _games(page),
          'cursor': (page.isEmpty || end >= discover.length)
              ? null
              : <String, dynamic>{'score': end, 'id': 'discover'},
        },
      ],
    });
  }

  @override
  Future<void> recordImpressions(
    List<Map<String, dynamic>> items, {
    String? sessionId,
  }) async {
    // As impressões são uma métrica de servidor. Sem servidor, elas só
    // importam se o usuário quiser; aqui respeitamos o opt-out e não fazemos
    // nada além disso (nenhum dado sai do aparelho).
    if (items.isEmpty ||
        !feedImpressionsAllowed(_cache.readString(kFeedImpressionsPrefKey))) {
      return;
    }
  }

  @override
  Future<CatalogFacets> fetchFacets() async {
    final LocalCatalog catalog = await _ready();
    return CatalogFacets.fromMap(<String, dynamic>{
      'platforms': catalog.platforms,
      'genres': catalog.genres,
    });
  }

  @override
  Future<GameDetail> fetchGame(String slug) async {
    final LocalCatalog catalog = await _ready();
    final Map<String, dynamic>? game = catalog.game(slug);
    if (game == null) {
      throw const AppFailure(FailureKind.notFound);
    }
    return GameDetail.fromMap(<String, dynamic>{
      'game': _decorate(game),
      'ports': catalog.ports(slug),
      'reviews': _store.reviewsFor(slug),
      'related': _games(_related(catalog, game, 8)),
      'compat': _store.compatSummaryFor(slug),
    });
  }

  @override
  Future<SearchPayload> search(SearchRequest request) async {
    final LocalCatalog catalog = await _ready();
    final int offset = asInt(request.cursor?['o']);
    final List<Map<String, dynamic>> all = _filter(catalog, request);
    final List<Map<String, dynamic>> sorted = _sort(all, request);
    final List<Map<String, dynamic>> page = _page(
      sorted,
      offset: offset,
      size: request.limit,
      seen: const <String>[],
    );
    final int next = offset + page.length;
    return SearchPayload(
      items: _games(page),
      total: sorted.length,
      cursor: (next >= sorted.length)
          ? null
          : <String, dynamic>{'o': next},
      suggestion: page.isEmpty ? _suggestion(catalog, request.query) : null,
    );
  }

  @override
  Future<SuggestPayload> suggest(String query) async {
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return const SuggestPayload();
    }
    final LocalCatalog catalog = await _ready();
    final List<Map<String, dynamic>> games = catalog.games
        .where(
          (Map<String, dynamic> g) =>
              (g['title']?.toString().toLowerCase() ?? '').contains(term),
        )
        .take(8)
        .toList();
    final List<Map<String, dynamic>> genres = catalog.genres
        .where(
          (Map<String, dynamic> g) =>
              (g['name']?.toString().toLowerCase() ?? '').contains(term),
        )
        .take(4)
        .toList();
    return SuggestPayload.fromMap(<String, dynamic>{
      'games': _games(games),
      'genres': genres,
      'developers': _developersOf(catalog)
          .where(
            (Map<String, dynamic> d) =>
                (d['name']?.toString().toLowerCase() ?? '').contains(term),
          )
          .take(4)
          .toList(),
      'platforms': catalog.platforms
          .where(
            (Map<String, dynamic> p) =>
                (p['name']?.toString().toLowerCase() ?? '').contains(term),
          )
          .take(4)
          .toList(),
    });
  }

  @override
  ExploreFeed? readCachedExploreFeed() {
    final Map<String, dynamic>? raw = _cache.readMap(_exploreCacheKey);
    if (raw == null) {
      return null;
    }
    try {
      return ExploreFeed.fromMap(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<ExploreFeed> fetchExploreFeed() async {
    final LocalCatalog catalog = await _ready();
    final Map<String, dynamic> map = <String, dynamic>{
      'trending': _games(_topByActivity(catalog, 12)),
      'new_releases': _games(_topByRecent(catalog, 12)),
      'top_rated': _games(_topByRating(catalog, 12)),
      'free': _games(_free(catalog, 12)),
      'popular_searches': _games(_topByActivity(catalog, 8)),
      'genres': catalog.genres,
      'stats': catalog.stats,
    };
    await _cache.writeMap(_exploreCacheKey, map);
    return ExploreFeed.fromMap(map);
  }

  @override
  Future<NewsPayload> fetchNews({int offset = 0, int limit = 20}) async {
    final LocalCatalog catalog = await _ready();
    final List<Map<String, dynamic>> items = _newsItems(catalog);
    final List<NewsItem> page = <NewsItem>[];
    for (int i = offset; i < items.length && page.length < limit; i++) {
      page.add(NewsItem.fromMap(items[i]));
    }
    return NewsPayload(items: page, total: items.length);
  }

  @override
  Future<NewsItem?> fetchNewsArticle(String slug) async {
    final LocalCatalog catalog = await _ready();
    for (final Map<String, dynamic> item in _newsItems(catalog)) {
      if (item['slug'] == slug) {
        return NewsItem.fromMap(item);
      }
    }
    return null;
  }

  @override
  Future<List<CompatReport>> fetchCompatReports(String gameId) async {
    await _ready();
    return _store
        .compatReportsFor(gameId)
        .map(CompatReport.fromMap)
        .toList(growable: false);
  }

  @override
  Future<AppUpdate?> fetchLatestUpdate() async => null;

  // ---------------------------------------------------------------- perfil

  @override
  Future<UserProfile> fetchProfile() async {
    return UserProfile(
      id: _store.deviceId,
      displayName: _store.displayName,
      coverUrl: _store.coverUrl,
      handle: _store.handle,
    );
  }

  @override
  Future<void> setHandle(String handle) async {
    _emit(_store.saveProfile(handle: handle.trim()));
  }

  @override
  Future<void> updateProfile({String? displayName, String? coverUrl}) async {
    _emit(
      _store.saveProfile(
        displayName: displayName,
        coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
      ),
    );
  }

  @override
  Future<List<UserResult>> searchUsers(String query) async {
    final String term = query.trim().toLowerCase();
    final List<UserResult> results = <UserResult>[];
    for (final Map<String, dynamic> peer in _store.peerProfiles()) {
      final String handle = peer['handle']?.toString() ?? '';
      final String name = peer['display_name']?.toString() ?? '';
      if (handle.isEmpty && name.isEmpty) {
        continue;
      }
      if (term.isEmpty ||
          handle.toLowerCase().contains(term) ||
          name.toLowerCase().contains(term)) {
        results.add(UserResult.fromMap(peer));
      }
    }
    return results;
  }

  @override
  Future<PublicProfile> fetchPublicProfile(String id) async {
    final Map<String, dynamic>? peer = _store.peerProfile(id);
    if (peer == null) {
      throw const AppFailure(FailureKind.notFound);
    }
    final LocalCatalog catalog = await _ready();
    final List<Object?> libraryIds = peer['library'] is List
        ? peer['library'] as List<Object?>
        : const <Object?>[];
    final List<Map<String, dynamic>> library = <Map<String, dynamic>>[];
    for (final Object? slug in libraryIds) {
      final Map<String, dynamic>? game = catalog.game(slug.toString());
      if (game != null) {
        library.add(_decorate(game));
      }
    }
    return PublicProfile.fromMap(<String, dynamic>{
      ...peer,
      'library': _games(library),
    });
  }

  // ------------------------------------------------------------- coleções

  @override
  Future<Collections> fetchCollections() async {
    final LocalCatalog catalog = await _ready();
    return Collections(
      favorites: _games(_byIds(catalog, _store.favoriteIds())),
      library: _games(_byIds(catalog, _store.libraryIds())),
      downloads: const <DownloadRecord>[],
    );
  }

  @override
  Future<bool> toggleFavorite(String gameId) async {
    final Map<String, dynamic>? op = _store.toggleFavorite(gameId);
    if (op != null) {
      _emit(op);
    }
    return _store.isFavorite(gameId);
  }

  @override
  Future<bool> toggleLibrary(String gameId) async {
    final Map<String, dynamic>? op = _store.toggleLibrary(gameId);
    if (op != null) {
      _emit(op);
    }
    return _store.isInLibrary(gameId);
  }

  @override
  Future<void> addToLibrary(String gameId) async {
    final Map<String, dynamic>? op = _store.setLibrary(gameId, true);
    if (op != null) {
      _emit(op);
    }
  }

  @override
  Future<void> submitReview({
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
  }) async {
    _emit(
      _store.submitReview(
        gameId: gameId,
        rating: rating,
        body: body,
        verdict: verdict,
        fps: fps,
        brand: brand,
        model: model,
        soc: soc,
        gpu: gpu,
        ramGb: ramGb,
      ),
    );
  }

  @override
  Future<void> syncDownload({
    required String gameId,
    required String? portKey,
    required String status,
    required int progress,
  }) async {
    // A fila de downloads é local (shared_preferences). Nada a sincronizar
    // com o servidor; a malha não transporta progresso de download.
  }

  // ----------------------------------------------------------------- utils

  void _emit(Map<String, dynamic> op) {
    _mesh?.publish(op);
  }

  List<Game> _games(List<Map<String, dynamic>> raw) =>
      raw.map((Map<String, dynamic> g) => Game.fromMap(_decorate(g)))
          .toList(growable: false);

  Map<String, dynamic> _decorate(Map<String, dynamic> raw) {
    final String slug = raw['slug']?.toString() ?? '';
    final List<Map<String, dynamic>> reviews = slug.isEmpty
        ? const <Map<String, dynamic>>[]
        : _store.reviewsFor(slug);
    double average = 0;
    if (reviews.isNotEmpty) {
      int sum = 0;
      for (final Map<String, dynamic> review in reviews) {
        sum += asInt(review['rating']);
      }
      average = sum / reviews.length;
    }
    return <String, dynamic>{
      ...raw,
      'rating_avg': average,
      'rating_count': reviews.length,
    };
  }

  void _addRow(
    List<HomeFeedSection> into,
    String key,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return;
    }
    into.add(
      HomeFeedSection(key: key, kind: 'row', items: _games(items)),
    );
  }

  List<Map<String, dynamic>> _byIds(LocalCatalog catalog, List<String> ids) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final String id in ids) {
      final Map<String, dynamic>? game = catalog.game(id);
      if (game != null) {
        result.add(game);
      }
    }
    return result;
  }

  String _activity(Map<String, dynamic> game) =>
      game['latest_activity']?.toString() ?? '';

  String _released(Map<String, dynamic> game) =>
      game['released_on']?.toString() ?? '';

  int _ports(Map<String, dynamic> game) => asInt(game['port_count']);

  List<Map<String, dynamic>> _topByActivity(LocalCatalog catalog, int limit) {
    final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.of(
      catalog.games,
    );
    games.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int byActivity = _activity(b).compareTo(_activity(a));
      if (byActivity != 0) {
        return byActivity;
      }
      return _ports(b) - _ports(a);
    });
    return games.take(limit).toList();
  }

  List<Map<String, dynamic>> _topByRecent(LocalCatalog catalog, int limit) {
    final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.of(
      catalog.games,
    );
    games.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int byReleased = _released(b).compareTo(_released(a));
      if (byReleased != 0) {
        return byReleased;
      }
      return _activity(b).compareTo(_activity(a));
    });
    return games.take(limit).toList();
  }

  List<Map<String, dynamic>> _topByRating(LocalCatalog catalog, int limit) {
    final List<Map<String, dynamic>> rated = catalog.games
        .where((Map<String, dynamic> g) => g['slug'] != null)
        .where(
          (Map<String, dynamic> g) =>
              _store.reviewsFor(g['slug'].toString()).isNotEmpty,
        )
        .toList();
    rated.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final double ra = _ratingOf(a['slug'].toString());
      final double rb = _ratingOf(b['slug'].toString());
      return rb.compareTo(ra);
    });
    return rated.take(limit).toList();
  }

  double _ratingOf(String slug) {
    final List<Map<String, dynamic>> reviews = _store.reviewsFor(slug);
    if (reviews.isEmpty) {
      return 0;
    }
    int sum = 0;
    for (final Map<String, dynamic> review in reviews) {
      sum += asInt(review['rating']);
    }
    return sum / reviews.length;
  }

  List<Map<String, dynamic>> _free(LocalCatalog catalog, int limit) {
    final List<Map<String, dynamic>> games = catalog.games
        .where((Map<String, dynamic> g) => g['is_free'] == true)
        .toList();
    games.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int byActivity = _activity(b).compareTo(_activity(a));
      if (byActivity != 0) {
        return byActivity;
      }
      return _ports(b) - _ports(a);
    });
    return games.take(limit).toList();
  }

  List<Map<String, dynamic>> _classics(LocalCatalog catalog, int limit) {
    final List<Map<String, dynamic>> games = catalog.games
        .where((Map<String, dynamic> g) => _isClassic(g))
        .toList();
    games.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return asInt(a['year']) - asInt(b['year']);
    });
    return games.take(limit).toList();
  }

  bool _isClassic(Map<String, dynamic> game) {
    final int year = asInt(game['year']);
    return year > 0 && year <= 2005;
  }

  List<Map<String, dynamic>> _related(
    LocalCatalog catalog,
    Map<String, dynamic> game,
    int limit,
  ) {
    final String slug = game['slug']?.toString() ?? '';
    final String genre = game['genre']?.toString() ?? '';
    final List<String> platforms = asStringList(game['platforms']);
    final List<String> tokens = <String>[
      for (final String token in genre.split(','))
        if (token.trim().isNotEmpty) token.trim().toLowerCase(),
    ];
    final List<Map<String, dynamic>> scored = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> other in catalog.games) {
      if (other['slug'] == slug) {
        continue;
      }
      int score = 0;
      final String otherPlatform = asStringList(other['platforms']).isEmpty
          ? ''
          : asStringList(other['platforms']).first;
      if (platforms.contains(otherPlatform)) {
        score += 2;
      }
      for (final String token in tokens) {
        if (_matchesGenre(other, token)) {
          score += 1;
        }
      }
      if (score > 0) {
        scored.add(<String, dynamic>{'game': other, 'score': score});
      }
    }
    scored.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int byScore = asInt(b['score']) - asInt(a['score']);
      if (byScore != 0) {
        return byScore;
      }
      return _ports(b['game'] as Map<String, dynamic>) -
          _ports(a['game'] as Map<String, dynamic>);
    });
    return scored
        .take(limit)
        .map((Map<String, dynamic> e) => e['game'] as Map<String, dynamic>)
        .toList();
  }

  bool _matchesGenre(Map<String, dynamic> game, String genre) {
    final String raw = game['genre']?.toString().toLowerCase() ?? '';
    final String wanted = genre.toLowerCase();
    for (final String token in raw.split(',')) {
      if (token.trim() == wanted) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _filter(
    LocalCatalog catalog,
    SearchRequest request,
  ) {
    final SearchFilters filters = request.filters;
    final String query = request.query.trim().toLowerCase();
    final String? platformName = filters.platform == null
        ? null
        : catalog.platformName(filters.platform!);
    return catalog.games.where((Map<String, dynamic> game) {
      if (platformName != null) {
        final List<String> platforms = asStringList(game['platforms']);
        if (!platforms.contains(platformName)) {
          return false;
        }
      }
      if (filters.genre != null && !_matchesGenre(game, filters.genre!)) {
        return false;
      }
      if (filters.freeOnly && game['is_free'] != true) {
        return false;
      }
      if (filters.needsRom && game['needs_rom'] != true) {
        return false;
      }
      if (filters.minRating != null &&
          _ratingOf(game['slug']?.toString() ?? '') < filters.minRating!) {
        return false;
      }
      if (query.isNotEmpty) {
        final String title = game['title']?.toString().toLowerCase() ?? '';
        final String genre = game['genre']?.toString().toLowerCase() ?? '';
        if (!title.contains(query) && !genre.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _sort(
    List<Map<String, dynamic>> games,
    SearchRequest request,
  ) {
    final String query = request.query.trim().toLowerCase();
    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.of(
      games,
    );
    switch (request.filters.sort) {
      case 'relevance':
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final int byScore = _relevance(b, query) - _relevance(a, query);
          if (byScore != 0) {
            return byScore;
          }
          return _activity(b).compareTo(_activity(a));
        });
        break;
      case 'recent':
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return _released(b).compareTo(_released(a));
        });
        break;
      case 'rating':
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final double ra = _ratingOf(a['slug']?.toString() ?? '');
          final double rb = _ratingOf(b['slug']?.toString() ?? '');
          return rb.compareTo(ra);
        });
        break;
      case 'az':
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return (a['title']?.toString().toLowerCase() ?? '').compareTo(
            b['title']?.toString().toLowerCase() ?? '',
          );
        });
        break;
      case 'year':
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return asInt(b['year']) - asInt(a['year']);
        });
        break;
      default:
        sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final int byActivity = _activity(b).compareTo(_activity(a));
          if (byActivity != 0) {
            return byActivity;
          }
          return _ports(b) - _ports(a);
        });
        break;
    }
    return sorted;
  }

  int _relevance(Map<String, dynamic> game, String query) {
    if (query.isEmpty) {
      return _ports(game);
    }
    final String title = game['title']?.toString().toLowerCase() ?? '';
    if (title == query) {
      return 1000;
    }
    if (title.startsWith(query)) {
      return 500;
    }
    if (title.contains(query)) {
      return 250;
    }
    if ((game['genre']?.toString().toLowerCase() ?? '').contains(query)) {
      return 100;
    }
    return 10 + _ports(game);
  }

  String? _suggestion(LocalCatalog catalog, String query) {
    final String term = query.trim().toLowerCase();
    if (term.length < 3) {
      return null;
    }
    String? best;
    int bestDistance = 1 << 30;
    for (final Map<String, dynamic> game in catalog.games) {
      final String title = game['title']?.toString() ?? '';
      final int distance = _prefixDistance(title.toLowerCase(), term);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = title;
      }
    }
    return best;
  }

  /// Distância simples (divergência no prefixo) — suficiente para "você quis
  /// dizer...?" sem trazer uma implementação de Levenshtein.
  int _prefixDistance(String a, String b) {
    final int length = a.length < b.length ? a.length : b.length;
    int distance = (a.length - b.length).abs();
    for (int i = 0; i < length; i++) {
      if (a[i] != b[i]) {
        distance++;
      }
    }
    return distance;
  }

  List<Map<String, dynamic>> _page(
    List<Map<String, dynamic>> source, {
    required int offset,
    required int size,
    required List<String> seen,
  }) {
    final Set<String> excluded = <String>{...seen};
    final List<Map<String, dynamic>> page = <Map<String, dynamic>>[];
    for (int i = offset; i < source.length && page.length < size; i++) {
      final Map<String, dynamic> game = source[i];
      final String slug = game['slug']?.toString() ?? '';
      if (excluded.contains(slug)) {
        continue;
      }
      page.add(game);
    }
    return page;
  }

  /// Ordem de descoberta estável por sessão (seed ⇒ mesma ordem). Embaralha
  /// de forma determinística para o "Para você" ter variação sem servidor.
  List<Map<String, dynamic>> _discoverOrder(LocalCatalog catalog, String seed) {
    final List<Map<String, dynamic>>? cached = _discoverCache[seed];
    if (cached != null) {
      return cached;
    }
    final List<Map<String, dynamic>> ordered = List<Map<String, dynamic>>.of(
      catalog.games,
    );
    final int start = seed.isEmpty ? 0 : seed.hashCode;
    int state = start == 0 ? 0x9e3779b9 : start;
    for (int i = ordered.length - 1; i > 0; i--) {
      state ^= state << 13;
      state ^= state >>> 7;
      state ^= state << 17;
      final int j = (state & 0x7fffffff) % (i + 1);
      final Map<String, dynamic> tmp = ordered[i];
      ordered[i] = ordered[j];
      ordered[j] = tmp;
    }
    if (_discoverCache.length > 8) {
      _discoverCache.clear();
    }
    _discoverCache[seed] = ordered;
    return ordered;
  }

  List<Map<String, dynamic>> _developersOf(LocalCatalog catalog) {
    final List<Map<String, dynamic>>? cached = _developers;
    if (cached != null) {
      return cached;
    }
    final Map<String, int> counts = <String, int>{};
    for (final Map<String, dynamic> game in catalog.games) {
      final String developer = game['developer']?.toString() ?? '';
      if (developer.isNotEmpty) {
        counts[developer] = (counts[developer] ?? 0) + 1;
      }
    }
    final List<Map<String, dynamic>> developers = <Map<String, dynamic>>[
      for (final MapEntry<String, int> entry in counts.entries)
        <String, dynamic>{'name': entry.key, 'game_count': entry.value},
    ];
    developers.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return asInt(b['game_count']) - asInt(a['game_count']);
    });
    _developers = developers;
    return developers;
  }

  List<Map<String, dynamic>> _newsItems(LocalCatalog catalog) {
    final List<Map<String, dynamic>> games = catalog.games
        .where((Map<String, dynamic> g) => _activity(g).isNotEmpty)
        .toList();
    games.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return _activity(b).compareTo(_activity(a));
    });
    return <Map<String, dynamic>>[
      for (final Map<String, dynamic> game in games.take(60))
        <String, dynamic>{
          'id': 'news-${game['slug']}',
          'slug': game['slug'],
          'category': 'Ports',
          'title': game['title'],
          'author': game['developer'],
          'summary': _newsSummary(game),
          'cover_url': game['cover_url'],
          'source_name': asStringList(game['platforms']).isEmpty
              ? null
              : asStringList(game['platforms']).first,
          'published_at': _activity(game),
        },
    ];
  }

  String _newsSummary(Map<String, dynamic> game) {
    final String developer = game['developer']?.toString() ?? '';
    final String platform = asStringList(game['platforms']).isEmpty
        ? ''
        : asStringList(game['platforms']).first;
    final String ports = _ports(game) > 1 ? ' · ${_ports(game)} ports' : '';
    if (developer.isEmpty) {
      return '$platform$ports';
    }
    return '$developer · $platform$ports';
  }
}
