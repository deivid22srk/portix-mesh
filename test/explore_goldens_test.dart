// Goldens de apoio: renderiza a tela Explorar redesenhada (descoberta,
// sugestões, resultados, filtros, vazio, erro) nos temas e larguras pedidos
// para auditoria visual do CRÍTICO.
//   GOLDENS=1 flutter test test/explore_goldens_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/theme/themes.dart';
import 'package:portix/core/env.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/features/explore/explore_page.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/compat_report.dart';
import 'package:portix/models/explore.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/news.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/models/public_profile.dart';
import 'package:portix/models/search.dart';
import 'package:portix/models/user_result.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/models/app_update.dart';

const String _outDir = 'goldens_out/explore';

Game _game(String id, String title, {String? genre, String? developer}) => Game(
  id: id,
  slug: id,
  title: title,
  genre: genre ?? 'Aventura',
  developer: developer ?? 'PortStudio',
  rating: 4.5,
  ratingCount: 12,
  visitCount: 900,
  platforms: <String>['Android'],
);

class _ExploreFakeRepo
    implements CatalogRepository, ExploreDiscoveryRepository {
  @override
  Future<SearchPayload> search(SearchRequest request) async {
    if (request.query.toLowerCase().contains('vazio')) {
      return SearchPayload(
        items: const <Game>[],
        total: 0,
        suggestion: 'Frontier',
      );
    }
    return SearchPayload(
      items: <Game>[
        _game('r1', 'Super Frontier Odyssey'),
        _game('r2', 'Frontier Legends II'),
        _game('r3', 'Frontier Kart 8'),
        _game('r4', 'Frontier Tactics'),
        _game('r5', 'Frontier Quest'),
        _game('r6', 'Frontier Rush 3D'),
      ],
      total: 128,
      cursor: const <String, dynamic>{},
    );
  }

  @override
  Future<SuggestPayload> suggest(String query) async => SuggestPayload(
    games: <Game>[
      _game('s1', 'Super Frontier Odyssey', developer: 'PortStudio'),
      _game('s2', 'Frontier Legends II', developer: 'NovaSoft'),
    ],
    genres: <GenreInfo>[const GenreInfo(name: 'Aventura', gameCount: 32)],
    developers: <DeveloperInfo>[
      const DeveloperInfo(name: 'PortStudio', gameCount: 14),
    ],
    platforms: const <PlatformInfo>[],
  );

  @override
  Future<ExploreFeed> fetchExploreFeed() async => _feed;

  @override
  ExploreFeed? readCachedExploreFeed() => null;

  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async => const HomeFeed();

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets(
    platforms: <PlatformInfo>[
      PlatformInfo(
        slug: 'gb',
        name: 'Game Boy',
        kind: 'handheld',
        portCount: 120,
      ),
      PlatformInfo(
        slug: 'psx',
        name: 'PlayStation',
        kind: 'console',
        portCount: 210,
      ),
    ],
    genres: <GenreInfo>[
      GenreInfo(name: 'Aventura', gameCount: 32),
      GenreInfo(name: 'RPG', gameCount: 28),
    ],
  );

  @override
  Future<GameDetail> fetchGame(String slug) => throw UnimplementedError();

  @override
  Future<NewsPayload> fetchNews({int offset = 0, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<NewsItem?> fetchNewsArticle(String slug) => throw UnimplementedError();

  @override
  Future<List<CompatReport>> fetchCompatReports(String gameId) =>
      throw UnimplementedError();

  @override
  Future<UserProfile> fetchProfile() => throw UnimplementedError();

  @override
  Future<void> setHandle(String handle) => throw UnimplementedError();

  @override
  Future<List<UserResult>> searchUsers(String query) =>
      throw UnimplementedError();

  @override
  Future<PublicProfile> fetchPublicProfile(String id) =>
      throw UnimplementedError();

  @override
  Future<AppUpdate?> fetchLatestUpdate() => throw UnimplementedError();

  @override
  Future<void> updateProfile({String? displayName, String? coverUrl}) =>
      throw UnimplementedError();

  @override
  Future<Collections> fetchCollections() => throw UnimplementedError();

  @override
  Future<bool> toggleFavorite(String gameId) => throw UnimplementedError();

  @override
  Future<bool> toggleLibrary(String gameId) => throw UnimplementedError();

  @override
  Future<void> addToLibrary(String gameId) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<void> syncDownload({
    required String gameId,
    required String? portKey,
    required String status,
    required int progress,
  }) => throw UnimplementedError();
}

class _BrokenSearchRepo extends _ExploreFakeRepo {
  @override
  Future<SearchPayload> search(SearchRequest request) async {
    throw const AppFailure(FailureKind.network);
  }
}

final ExploreFeed _feed = ExploreFeed(
  trending: <Game>[
    _game('t1', 'Super Frontier Odyssey'),
    _game('t2', 'Frontier Legends II'),
    _game('t3', 'Frontier Kart 8'),
    _game('t4', 'Frontier Tactics'),
  ],
  newReleases: <Game>[
    _game('n1', 'Nova Frontier', developer: 'NovaSoft'),
    _game('n2', 'Frontier Origins', developer: 'NovaSoft'),
  ],
  topRated: <Game>[
    _game('q1', 'Frontier Kingdom', developer: 'KingsForge'),
    _game('q2', 'Frontier Chronicles', developer: 'KingsForge'),
  ],
  free: <Game>[_game('f1', 'Frontier Libre'), _game('f2', 'Frontier Free Run')],
  popularSearches: <Game>[
    _game('p1', 'Frontier Odyssey'),
    _game('p2', 'Frontier Legends'),
    _game('p3', 'Frontier Kart'),
    _game('p4', 'Frontier Tactics'),
  ],
  genres: <GenreInfo>[
    const GenreInfo(name: 'Aventura', gameCount: 32),
    const GenreInfo(name: 'RPG', gameCount: 28),
    const GenreInfo(name: 'Corrida', gameCount: 21),
    const GenreInfo(name: 'Plataforma', gameCount: 18),
    const GenreInfo(name: 'Puzzle', gameCount: 15),
    const GenreInfo(name: 'Luta', gameCount: 11),
  ],
);

/// Fontes embutidas do app (Poppins + MaterialIcons) para o golden ficar
/// fiel ao real — ícones deixam de renderizar como tofu.
Future<void> _loadFonts() async {
  for (final String path in <String>[
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
    'assets/fonts/Poppins-SemiBold.ttf',
    'assets/fonts/Poppins-Bold.ttf',
  ]) {
    final ByteData data = await rootBundle.load(path);
    final FontLoader loader = FontLoader('Poppins')
      ..addFont(Future<ByteData>.value(data));
    await loader.load();
  }
  final ByteData icons = await rootBundle.load(
    'fonts/MaterialIcons-Regular.otf',
  );
  final FontLoader iconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(icons));
  await iconsLoader.load();
}

Future<void> _pumpExplore(
  WidgetTester tester,
  Size size,
  AppColorsTheme theme,
  String name,
  _ExploreFakeRepo repo, {
  String query = '',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Busca por deep link (/explore?q=…): a Explorar não tem mais campo de
  // busca — resultados chegam pela rota, como na produção.
  final GoRouter router = GoRouter(
    initialLocation: Uri(
      path: '/explore',
      queryParameters: query.isEmpty ? null : <String, String>{'q': query},
    ).toString(),
    routes: <RouteBase>[
      GoRoute(
        path: '/explore',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: ExplorePage(initialQuery: state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/game/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
      ),
      child: MaterialApp.router(
        theme: AppTheme.build(theme),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_outDir/$name.png'),
  );
}

bool get _goldensEnabled => Platform.environment['GOLDENS'] == '1';

void main() {
  setUpAll(() async {
    if (!_goldensEnabled) {
      return;
    }
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  testWidgets('descoberta mobile 375 escuro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      auroraDark,
      'descoberta_375_escuro',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('descoberta mobile 375 claro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      auroraLight,
      'descoberta_375_claro',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('descoberta tablet 768 oceano', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(768, 1024),
      oceano,
      'descoberta_768_oceano',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('descoberta desktop 1440 escuro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(1440, 900),
      auroraDark,
      'descoberta_1440_escuro',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('resultados mobile 375 escuro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      auroraDark,
      'resultados_375_escuro',
      _ExploreFakeRepo(),
      query: 'frontier',
    );
  });

  testWidgets('resultados tablet 768 midnight', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(768, 1024),
      midnight,
      'resultados_768_midnight',
      _ExploreFakeRepo(),
      query: 'frontier',
    );
  });

  testWidgets('resultados desktop 1440 claro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(1440, 900),
      auroraLight,
      'resultados_1440_claro',
      _ExploreFakeRepo(),
      query: 'frontier',
    );
  });

  testWidgets('vazio com sugestão 375 escuro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      auroraDark,
      'vazio_375_escuro',
      _ExploreFakeRepo(),
      query: 'vazio',
    );
  });

  testWidgets('erro offline 375 escuro', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      auroraDark,
      'erro_375_escuro',
      _BrokenSearchRepo(),
      query: 'frontier',
    );
  });

  testWidgets('floresta descoberta 375', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      floresta,
      'descoberta_375_floresta',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('midnight descoberta 375', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      midnight,
      'descoberta_375_midnight',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('vice descoberta 375', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      vice,
      'descoberta_375_vice',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('dourado descoberta 375', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(375, 812),
      dourado,
      'descoberta_375_dourado',
      _ExploreFakeRepo(),
    );
  });

  testWidgets('citrico resultados 768', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpExplore(
      tester,
      const Size(768, 1024),
      citrico,
      'resultados_768_citrico',
      _ExploreFakeRepo(),
      query: 'frontier',
    );
  });
}
