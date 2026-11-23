// Testes da tela de categoria (gênero): conteúdo, paginação por cursor,
// estado vazio e erro com retry. A tela abre ao tocar um card de categoria
// na Explorar e mantém estado PRÓPRIO (sem provider global de busca).
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/env.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/explore/genre_page.dart';
import 'package:portix/models/app_update.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/compat_report.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/news.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/models/public_profile.dart';
import 'package:portix/models/search.dart';
import 'package:portix/models/user_result.dart';

Game _game(String id, String title) =>
    Game(id: id, slug: id, title: title, genre: 'Aventura', coverUrl: null);

/// Falso repositório: primeira página com cursor; segunda página ao passar
/// o cursor de volta. `fail` derruba TODAS as chamadas (rede).
class _FakeRepo implements CatalogRepository {
  final List<SearchRequest> calls = <SearchRequest>[];
  bool fail = false;
  bool empty = false;

  @override
  Future<SearchPayload> search(SearchRequest request) async {
    calls.add(request);
    if (fail) {
      throw const AppFailure(FailureKind.network);
    }
    if (empty) {
      return const SearchPayload(items: <Game>[], total: 0);
    }
    if (request.cursor != null) {
      return SearchPayload(
        items: <Game>[
          _game('g4', 'Aventura Quatro'),
          _game('g5', 'Aventura Cinco'),
        ],
        total: 5,
      );
    }
    return SearchPayload(
      items: <Game>[
        _game('g1', 'Aventura Um'),
        _game('g2', 'Aventura Dois'),
        _game('g3', 'Aventura Três'),
      ],
      total: 5,
      cursor: const <String, dynamic>{'after': 'g3'},
    );
  }

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets();

  @override
  HomeFeed? readCachedHome() => null;

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

  @override
  Future<HomeFeed> fetchHome() => throw UnimplementedError();

  @override
  Future<GameDetail> fetchGame(String slug) => throw UnimplementedError();

  @override
  Future<NewsPayload> fetchNews({int offset = 0, int limit = 20}) =>
      throw UnimplementedError();
}

Future<void> _pumpGenre(
  WidgetTester tester,
  _FakeRepo repo, {
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final GoRouter router = GoRouter(
    initialLocation: '/genre/Aventura',
    routes: <RouteBase>[
      GoRoute(
        path: '/genre/:name',
        builder: (BuildContext context, GoRouterState state) =>
            GenrePage(genre: state.pathParameters['name'] ?? ''),
      ),
      GoRoute(
        path: '/explore',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        catalogRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(); // post-frame (ensureLoaded → _load)
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra os jogos da categoria com contador', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    await _pumpGenre(tester, repo);

    expect(find.text('Aventura'), findsOneWidget);
    expect(find.text('5 resultados'), findsOneWidget);
    expect(find.text('Aventura Um'), findsOneWidget);
    expect(find.text('Aventura Dois'), findsOneWidget);
    expect(find.text('Aventura Três'), findsOneWidget);
    // A busca é por gênero (sem texto), com o sort padrão.
    expect(repo.calls.single.query, isEmpty);
    expect(repo.calls.single.filters.genre, 'Aventura');
  });

  testWidgets('paginação: "Ver tudo" carrega a segunda página com merge', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    await _pumpGenre(tester, repo);

    await tester.tap(find.text('Ver tudo'));
    // O RevealOnMount dos itens novos agenda delays escalonados (45ms ×
    // índice): cada pump adianta o relógio do FakeAsync e esgota os timers.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(repo.calls.length, 2);
    expect(repo.calls.last.cursor, isNotNull);
    expect(find.text('Aventura Um'), findsOneWidget);
    expect(find.text('Aventura Quatro'), findsOneWidget);
    expect(find.text('Aventura Cinco'), findsOneWidget);
    // Cursor esgotado: o botão "Ver tudo" sai de cena.
    expect(find.text('Ver tudo'), findsNothing);
  });

  testWidgets('categoria sem jogos: estado vazio explicado', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    repo.empty = true;
    await _pumpGenre(tester, repo);

    expect(find.text('Nenhum jogo nesta categoria ainda'), findsOneWidget);
    expect(find.text('Aventura Um'), findsNothing);
  });

  testWidgets('erro de rede: explicado com "Tentar de novo" que recupera', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    repo.fail = true;
    await _pumpGenre(tester, repo);

    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);

    repo.fail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump(const Duration(milliseconds: 200)); // timers do tap
    await tester.pumpAndSettle();

    expect(find.text('Aventura Um'), findsOneWidget);
    expect(find.text('5 resultados'), findsOneWidget);
  });
}
