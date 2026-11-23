import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/search/search_controller.dart';
import 'package:portix/features/search/search_page.dart';
import 'package:portix/models/app_update.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/compat_report.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/explore.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/news.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/models/public_profile.dart';
import 'package:portix/models/search.dart';
import 'package:portix/models/user_result.dart';

/// Registro das queries efetivamente enviadas ao repositório (já trimadas).
class _FakeCatalogRepository
    implements CatalogRepository, ExploreDiscoveryRepository {
  final List<String> queries = <String>[];

  @override
  Future<SearchPayload> search(SearchRequest request) async {
    queries.add(request.query);
    const Game game = Game(id: '1', slug: 'super-mario', title: 'Super Mario');
    return SearchPayload(items: const <Game>[game], total: 1);
  }

  @override
  Future<SuggestPayload> suggest(String query) async => SuggestPayload(
    games: <Game>[
      const Game(id: 's1', slug: 'smw', title: 'Super Mario World'),
    ],
    genres: const <GenreInfo>[GenreInfo(name: 'Plataforma', gameCount: 9)],
  );

  @override
  Future<ExploreFeed> fetchExploreFeed() async => const ExploreFeed();

  @override
  ExploreFeed? readCachedExploreFeed() => null;

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

Future<SharedPreferences> _mockPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Future<void> _pumpSearchPage(
  WidgetTester tester,
  _FakeCatalogRepository repo,
  SharedPreferences prefs,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  tester.view.physicalSize = const Size(411, 891);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        catalogRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const SearchPage(),
      ),
    ),
  );
  // 1º pump: post-frame (ensureLoaded + focus); 2º: microtasks da 1ª busca.
  await tester.pump();
  await tester.pump();
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('sugestões instantâneas aparecem ao digitar no campo completo', (
    WidgetTester tester,
  ) async {
    final _FakeCatalogRepository repo = _FakeCatalogRepository();
    final SharedPreferences prefs = await _mockPrefs();
    await _pumpSearchPage(tester, repo, prefs);

    // O SearchField (agora dono da busca) dispara o suggest com debounce
    // de 180 ms além do debounce da busca em si.
    await tester.enterText(find.byType(TextField), 'mario');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Super Mario World'), findsOneWidget);
    expect(find.text('Plataforma'), findsOneWidget);
    expect(repo.queries, contains('mario'));
  });

  testWidgets(
    'regressão: espaço digitado no campo de busca não é apagado pela resposta',
    (WidgetTester tester) async {
      final _FakeCatalogRepository repo = _FakeCatalogRepository();
      final SharedPreferences prefs = await _mockPrefs();
      await _pumpSearchPage(tester, repo, prefs);

      // Usuário digita "mario": debounce disca e a resposta chega.
      await tester.enterText(find.byType(TextField), 'mario');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_fieldText(tester), 'mario');
      expect(repo.queries, <String>['', 'mario']);

      // Usuário digita espaço para buscar "mario kart" — o espaço PRECISA
      // permanecer no campo depois que a resposta da requisição anterior
      // (trimada) chega. Antes da correção, o echo trimado apagava o espaço.
      await tester.enterText(find.byType(TextField), 'mario ');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      expect(_fieldText(tester), 'mario ');
      // O trim continua valendo para a requisição, não para o campo.
      expect(repo.queries, <String>['', 'mario', 'mario']);
    },
  );

  testWidgets(
    'texto digitado durante uma busca em voo não é descartado ao concluir',
    (WidgetTester tester) async {
      final _FakeCatalogRepository repo = _FakeCatalogRepository();
      final SharedPreferences prefs = await _mockPrefs();
      await _pumpSearchPage(tester, repo, prefs);

      await tester.enterText(find.byType(TextField), 'mario');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_fieldText(tester), 'mario');

      // Espaço + mais texto enquanto a resposta ainda não chegou: nada do
      // que o usuário digitou pode ser sobrescrito pela conclusão da busca.
      await tester.enterText(find.byType(TextField), 'mario kart 64');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      expect(_fieldText(tester), 'mario kart 64');
    },
  );

  test(
    'controller preserva a query bruta no estado e trima apenas a requisição',
    () async {
      final SharedPreferences prefs = await _mockPrefs();
      fakeAsync((FakeAsync async) {
        final _FakeCatalogRepository repo = _FakeCatalogRepository();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider.overrideWithValue(repo),
          ],
        );
        try {
          container
              .read(searchControllerProvider.notifier)
              .setQuery('super mario  ');
          async.elapse(const Duration(milliseconds: 400));

          expect(
            container.read(searchControllerProvider).query,
            'super mario  ',
          );
          expect(repo.queries, <String>['super mario']);
        } finally {
          container.dispose();
        }
      });
    },
  );
}
