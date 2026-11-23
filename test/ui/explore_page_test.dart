// Testes de widget da tela Explorar (descoberta): seções, categorias com
// NAVEGAÇÃO para a tela do gênero, ausência de campo de busca, estados de
// resultados por deep link, histórico, acessibilidade e a REGRESSÃO do laço
// rota↔estado (a busca na tela de busca não pode ser derrubada pela Explorar).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/env.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/explore/explore_page.dart';
import 'package:portix/features/search/search_controller.dart';
import 'package:portix/shared/widgets/app_header.dart';
import 'package:portix/models/app_update.dart';
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

Game _game(String id, String title, {String? genre, String? developer}) => Game(
  id: id,
  slug: id,
  title: title,
  genre: genre,
  developer: developer,
  coverUrl: null,
);

class _FakeRepo implements CatalogRepository, ExploreDiscoveryRepository {
  _FakeRepo();

  final List<String> queries = <String>[];
  Future<SearchPayload> Function(SearchRequest request)? onSearch;
  bool failSearch = false;
  bool failExplore = false;
  ExploreFeed? cachedExplore;

  @override
  Future<SearchPayload> search(SearchRequest request) async {
    queries.add(request.query);
    if (failSearch) {
      throw const AppFailure(FailureKind.network);
    }
    final Future<SearchPayload>? custom = onSearch?.call(request);
    if (custom != null) {
      return custom;
    }
    return SearchPayload(
      items: <Game>[
        _game('r1', 'Result Alpha'),
        _game('r2', 'Result Beta'),
        _game('r3', 'Result Gamma'),
      ],
      total: 3,
    );
  }

  @override
  Future<SuggestPayload> suggest(String query) async => SuggestPayload(
    games: <Game>[_game('s1', 'Super Mario World', developer: 'Nintendo')],
    genres: <GenreInfo>[const GenreInfo(name: 'Plataforma', gameCount: 9)],
  );

  @override
  Future<ExploreFeed> fetchExploreFeed() async {
    if (failExplore) {
      throw const AppFailure(FailureKind.network);
    }
    return ExploreFeed(
      trending: <Game>[_game('t1', 'Em Alta Um'), _game('t2', 'Em Alta Dois')],
      newReleases: <Game>[_game('n1', 'Novidade Um')],
      topRated: <Game>[_game('q1', 'Avaliado Um')],
      free: <Game>[_game('f1', 'Grátis Um')],
      popularSearches: <Game>[_game('p1', 'Em Alta Nas Buscas')],
      genres: <GenreInfo>[
        const GenreInfo(name: 'Aventura', gameCount: 12),
        const GenreInfo(name: 'RPG', gameCount: 8),
        const GenreInfo(name: 'Puzzle', gameCount: 5),
      ],
    );
  }

  @override
  ExploreFeed? readCachedExploreFeed() => cachedExplore;

  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async => const HomeFeed();

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets(
    platforms: <PlatformInfo>[],
    genres: <GenreInfo>[const GenreInfo(name: 'Aventura', gameCount: 12)],
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

Future<(ProviderContainer, GoRouter)> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  Map<String, String> initialQuery = const <String, String>{},
  Size size = const Size(390, 844),
  List<String> recentSearches = const <String>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (recentSearches.isNotEmpty) 'search.recent': recentSearches,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final GoRouter router = GoRouter(
    initialLocation: Uri(
      path: '/explore',
      queryParameters: initialQuery.isEmpty ? null : initialQuery,
    ).toString(),
    routes: <RouteBase>[
      GoRoute(
        path: '/explore',
        // A casca (MainShell) fornece o Scaffold em produção.
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: ExplorePage(initialQuery: state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/game/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('detalhe-${state.pathParameters['slug']}')),
      ),
      GoRoute(
        path: '/genre/:name',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('genero-${state.pathParameters['name']}')),
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('tela de busca')),
      ),
    ],
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(); // post-frame (ensureLoaded)
  await tester.pumpAndSettle();
  return (container, router);
}

void main() {
  testWidgets(
    'modo descoberta: SEM campo de busca, com categorias e carrosséis',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      final (_, GoRouter router) = await _pump(tester, repo);

      // A Explorar é descoberta: nenhum campo de busca aqui — a busca é a
      // tela própria (FAB da navegação).
      expect(find.byType(TextField), findsNothing);

      // Seções da descoberta visíveis na dobra.
      expect(find.text('Categorias'), findsOneWidget);
      expect(find.text('Aventura'), findsWidgets);
      expect(find.text('Em alta'), findsWidgets);
      expect(find.text('Em alta nas buscas'), findsOneWidget);
      expect(find.text('Em Alta Nas Buscas'), findsOneWidget);

      // Slivers são lazy: rolar para ver o restante dos carrosséis.
      for (int i = 0; i < 12; i += 1) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      expect(find.text('Novidades'), findsOneWidget);
      expect(find.text('Mais bem avaliados'), findsOneWidget);
      expect(find.text('Grátis e aberto'), findsOneWidget);
      expect(find.text('Novidade Um'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/explore');
    },
  );

  testWidgets('categoría navegável: toque abre a TELA do gênero com os jogos', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    final (_, GoRouter router) = await _pump(tester, repo);

    // Antes do fix o toque só aplicava um filtro invisível: nada mudava.
    await tester.ensureVisible(find.text('Aventura').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aventura').first);
    await tester.pumpAndSettle();

    // O caminho do TOPO (push incluído) — uri.path devolve a rota base.
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/genre/Aventura',
    );
    expect(find.text('genero-Aventura'), findsOneWidget);
  });

  testWidgets(
    'resultados por deep link: contador, chips de filtros e alternância lista',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      final (_, GoRouter router) = await _pump(
        tester,
        repo,
        initialQuery: <String, String>{'q': 'mario'},
      );

      // Contador anunciado + resultados na grade.
      expect(find.text('3 resultados'), findsOneWidget);
      expect(find.text('Result Alpha'), findsOneWidget);
      // A rota reflete o estado (deep link).
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['q'],
        'mario',
      );

      // Alternância grade → lista (sem refetch).
      final int before = repo.queries.length;
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pump(const Duration(milliseconds: 200)); // timers do tap
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['view'],
        'list',
      );
      expect(repo.queries.length, before);
    },
  );

  testWidgets('x do header limpa a busca e volta à descoberta (rota sem q)', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    final (_, GoRouter router) = await _pump(
      tester,
      repo,
      initialQuery: <String, String>{'q': 'mario'},
    );

    // Resultados visíveis; o x do header é a ÚLTIMA ação do header (tune + x)
    // — outros close_rounded podem existir na árvore (cards, chips).
    expect(find.text('Result Alpha'), findsOneWidget);
    final Finder headerX = find.byType(AppHeaderActionButton).last;
    await tester.ensureVisible(headerX);
    await tester.pumpAndSettle();
    await tester.tap(headerX);
    await tester.pump(const Duration(milliseconds: 200)); // timers do tap
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.queryParameters['q'],
      isNull,
    );
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'sem resultados: "Você quis dizer…?", limpar filtros e categorias',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      repo.onSearch = (SearchRequest request) => Future<SearchPayload>.value(
        SearchPayload(items: const <Game>[], total: 0, suggestion: 'Frontier'),
      );
      await _pump(tester, repo, initialQuery: <String, String>{'q': 'frontir'});

      expect(find.text('Nada encontrado'), findsOneWidget);
      // Sugestão "Você quis dizer…" como chip tocável.
      expect(find.text('Frontier'), findsOneWidget);
    },
  );

  testWidgets('offline: descoberta mostra cache com aviso de desatualização', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    repo.cachedExplore = ExploreFeed(
      trending: <Game>[_game('c1', 'Cache Um')],
      genres: <GenreInfo>[const GenreInfo(name: 'Aventura', gameCount: 3)],
    );
    repo.failExplore = true;
    await _pump(tester, repo);

    // Cache síncrono abre com conteúdo e o banner explica a desatualização.
    expect(find.text('Cache Um'), findsOneWidget);
    expect(
      find.text('Mostrando dados salvos — podem estar desatualizados.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'busca offline sem cache: erro explicado com ação de tentar de novo',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      repo.failSearch = true;
      await _pump(tester, repo, initialQuery: <String, String>{'q': 'mario'});

      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    },
  );

  testWidgets(
    'REGRESSÃO do laço: buscar na tela de busca NÃO manda para explorar',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      final (ProviderContainer container, GoRouter router) = await _pump(
        tester,
        repo,
      );

      // Abre a tela de busca POR CIMA da casca (rota de topo, como no app).
      router.routerDelegate.addListener(() {
        debugPrint(
          'ROTA → ${router.routerDelegate.currentConfiguration.last.matchedLocation}',
        );
      });
      unawaited(router.push('/search'));
      await tester.pumpAndSettle();
      expect(find.text('tela de busca'), findsOneWidget);

      // A tela de busca dispara a busca no controller compartilhado (o que
      // acontece de verdade quando o usuário digita lá). A Explorar está
      // montada embaixo (aba viva) — NÃO pode derrubar esta tela.
      unawaited(
        container.read(searchControllerProvider.notifier).submitQuery('mario'),
      );
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/search',
        reason: 'a busca foi derrubada pela sincronização de rota da Explorar',
      );
      expect(find.text('tela de busca'), findsOneWidget);
      expect(repo.queries, contains('mario'));
    },
  );

  testWidgets(
    'deep link: /explore?q=…&genre=… aplica texto e filtro no abrir',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      await _pump(
        tester,
        repo,
        initialQuery: <String, String>{'q': 'mario', 'genre': 'Aventura'},
      );

      expect(repo.queries, contains('mario'));
      // Chip do filtro ativo removível na barra de resultados.
      expect(find.text('Aventura'), findsWidgets);
    },
  );

  testWidgets(
    'submit dispara EXATAMENTE as buscas esperadas (sem refetch do toggle)',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      await _pump(
        tester,
        repo,
        initialQuery: <String, String>{'q': 'frontier'},
      );

      // Toggle grade/lista NÃO refaz a busca.
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pump(const Duration(milliseconds: 200)); // timers do tap
      await tester.pumpAndSettle();

      expect(repo.queries, <String>['', 'frontier']);
    },
  );

  testWidgets('alvos de toque medidos: chips ≥ 44dp e botões x com 48dp', (
    WidgetTester tester,
  ) async {
    final _FakeRepo repo = _FakeRepo();
    await _pump(tester, repo, recentSearches: <String>['busca antiga']);

    // Chip denso (histórico): altura ≥ 44.
    final Finder pillDense = find.text('busca antiga');
    await tester.ensureVisible(pillDense);
    final Size dense = tester.getSize(
      find
          .ancestor(of: pillDense, matching: find.byType(AnimatedContainer))
          .first,
    );
    expect(dense.height, greaterThanOrEqualTo(44));

    // Chip do histórico: o x de remover tem 48dp.
    final Finder chipX = find.byIcon(Icons.close_rounded).first;
    final Size chipXSize = tester.getSize(chipX);
    expect(
      chipXSize.height,
      greaterThanOrEqualTo(44),
      reason: 'x de remover do histórico com alvo 48dp',
    );
    expect(chipXSize.width, greaterThanOrEqualTo(44));
  });

  testWidgets(
    'filtros ≥ 768px: PAINEL LATERAL ancorado à direita (largura 320-420)',
    (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo();
      await _pump(tester, repo, size: const Size(900, 700));

      // Abre o painel pelo botão de filtros do header.
      await tester.tap(find.byType(AppHeaderActionButton).first);
      await tester.pumpAndSettle();

      // O painel é o Container com raio horizontal-esquerdo dentro do dialog.
      final Finder panel = find.byKey(
        const ValueKey<String>('filter_side_panel'),
      );
      expect(panel, findsOneWidget);
      final Size size = tester.getSize(panel);
      expect(size.width, inExclusiveRange(320, 420));
      // Ancorado à DIREITA: borda direita do painel colada na janela.
      final Rect box = tester.getRect(panel);
      expect(box.right, moreOrLessEquals(900, epsilon: 1));
    },
  );

  testWidgets('filtros < 768px: bottom sheet', (WidgetTester tester) async {
    final _FakeRepo repo = _FakeRepo();
    await _pump(tester, repo, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    // Bottom sheet: sem Dialog na árvore; o sheet ocupa a base.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Filtros'), findsOneWidget);
  });
}
