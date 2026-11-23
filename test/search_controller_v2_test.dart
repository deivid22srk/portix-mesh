// Testes do SearchController v2 (busca da Explorar): debounce, cancelamento
// de requisição obsoleta, cursor keyset, cache offline, "Você quis dizer…?",
// histórico local e ordenação automática.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/core/env.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/search/search_controller.dart';
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

class _FakeRepo implements CatalogRepository, ExploreDiscoveryRepository {
  _FakeRepo();

  /// Quantas próximas chamadas de search falham (simulando rede/RPC caída).
  int failNext = 0;

  final List<String> queries = <String>[];
  final List<int> pages = <int>[];
  final List<String> suggestQueries = <String>[];

  Future<SearchPayload> Function(SearchRequest request)? onSearch;

  @override
  Future<SearchPayload> search(SearchRequest request) async {
    if (failNext > 0) {
      failNext--;
      throw const AppFailure(FailureKind.network);
    }
    queries.add(request.query);
    pages.add(request.cursor == null ? 0 : 1);
    final Future<SearchPayload>? custom = onSearch?.call(request);
    if (custom != null) {
      return custom;
    }
    return SearchPayload(
      items: <Game>[
        Game(
          id: '${request.query}-${request.cursor ?? 'p0'}',
          slug: 'a',
          title: 'A',
        ),
      ],
      total: 1,
      cursor: null,
    );
  }

  @override
  Future<SuggestPayload> suggest(String query) async {
    suggestQueries.add(query);
    return SuggestPayload(
      games: <Game>[Game(id: 'g', slug: 'slug-g', title: 'Jogo G')],
    );
  }

  @override
  Future<ExploreFeed> fetchExploreFeed() async => const ExploreFeed();

  @override
  ExploreFeed? readCachedExploreFeed() => null;

  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() => throw UnimplementedError();

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets();

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

Future<ProviderContainer> _makeContainer(_FakeRepo repo) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  test(
    'debounce de 280ms: digitação rápida dispara UMA requisição (a última)',
    () async {
      fakeAsync((FakeAsync async) async {
        final _FakeRepo repo = _FakeRepo();
        final ProviderContainer container = await _makeContainer(repo);
        addTearDown(container.dispose);
        final SearchController controller = container.read(
          searchControllerProvider.notifier,
        );

        controller.setQuery('m');
        async.elapse(const Duration(milliseconds: 100));
        controller.setQuery('mar');
        async.elapse(const Duration(milliseconds: 100));
        controller.setQuery('mario');
        // Antes do debounce completar: nada foi enviado.
        expect(repo.queries, isEmpty);
        async.elapse(kSearchDebounce);
        async.elapse(const Duration(milliseconds: 50));

        expect(repo.queries, <String>['mario']);
      });
    },
  );

  test('requisição antiga não sobrescreve a nova (race condition)', () async {
    final _FakeRepo repo = _FakeRepo();
    final Completer<void> gate = Completer<void>();
    repo.onSearch = (SearchRequest request) {
      if (request.query == 'lento') {
        // Completa só quando o teste liberar o gate.
        return gate.future.then(
          (_) => SearchPayload(
            items: <Game>[
              const Game(id: 'lento', slug: 'lento', title: 'Lento'),
            ],
            total: 1,
          ),
        );
      }
      return Future<SearchPayload>.value(
        SearchPayload(
          items: <Game>[
            const Game(id: 'rapido', slug: 'rapido', title: 'Rápido'),
          ],
          total: 1,
        ),
      );
    };
    final ProviderContainer container = await _makeContainer(repo);
    addTearDown(container.dispose);
    final SearchController controller = container.read(
      searchControllerProvider.notifier,
    );

    final Future<void> slow = controller.submitQuery('lento');
    // Digitação nova chega enquanto a anterior está em voo.
    controller.submitQuery('rapido');
    await pumpEventQueue();
    expect(
      container.read(searchControllerProvider).items.first.title,
      'Rápido',
    );

    // A lenta termina DEPOIS: o resultado antigo é descartado.
    gate.complete();
    await slow;
    await pumpEventQueue();
    expect(
      container.read(searchControllerProvider).items.first.title,
      'Rápido',
      reason: 'a resposta da busca antiga não pode sobrescrever a nova',
    );
    expect(container.read(searchTextProvider), 'rapido');
  });

  test(
    'menos de 2 caracteres volta ao modo descoberta sem requisição',
    () async {
      fakeAsync((FakeAsync async) async {
        final _FakeRepo repo = _FakeRepo();
        final ProviderContainer container = await _makeContainer(repo);
        addTearDown(container.dispose);
        final SearchController controller = container.read(
          searchControllerProvider.notifier,
        );

        controller.setQuery('mar');
        async.elapse(kSearchDebounce + const Duration(milliseconds: 20));
        expect(repo.queries, <String>['mar']);

        controller.setQuery('m');
        async.elapse(kSearchDebounce + const Duration(milliseconds: 20));
        expect(repo.queries, <String>['mar'], reason: 'sem fetch para 1 letra');
        expect(container.read(searchControllerProvider).items, isEmpty);
        expect(
          container.read(searchControllerProvider).status,
          SearchStatus.idle,
        );
      });
    },
  );

  test(
    'ao digitar, a ordenação padrão vira relevância (e volta no clear)',
    () async {
      fakeAsync((FakeAsync async) async {
        final _FakeRepo repo = _FakeRepo();
        final ProviderContainer container = await _makeContainer(repo);
        addTearDown(container.dispose);
        final SearchController controller = container.read(
          searchControllerProvider.notifier,
        );

        expect(
          container.read(searchControllerProvider).filters.sort,
          kDefaultSort,
        );
        controller.setQuery('mario');
        expect(
          container.read(searchControllerProvider).filters.sort,
          'relevance',
        );

        controller.clearQuery();
        expect(
          container.read(searchControllerProvider).filters.sort,
          kDefaultSort,
        );
        async.elapse(const Duration(milliseconds: 20));
      });
    },
  );

  test('cursor keyset: loadMore junta páginas sem duplicar', () async {
    final _FakeRepo repo = _FakeRepo();
    final ProviderContainer container = await _makeContainer(repo);
    addTearDown(container.dispose);
    final SearchController controller = container.read(
      searchControllerProvider.notifier,
    );

    final Map<String, dynamic> cursor = <String, dynamic>{
      'k': 'relevance',
      'a': 1.2,
      'b': 10,
      'id': '00000000-0000-0000-0000-000000000001',
    };
    repo.onSearch = (SearchRequest request) {
      if (request.cursor == null) {
        return Future<SearchPayload>.value(
          SearchPayload(
            items: <Game>[
              const Game(id: 'p1a', slug: 'p1a', title: 'P1A'),
              const Game(id: 'p1b', slug: 'p1b', title: 'P1B'),
            ],
            total: 3,
            cursor: cursor,
          ),
        );
      }
      return Future<SearchPayload>.value(
        SearchPayload(
          items: <Game>[
            const Game(id: 'p2a', slug: 'p2a', title: 'P2A'),
            const Game(
              id: 'p1a',
              slug: 'p1a',
              title: 'P1A',
            ), // duplicado no payload
          ],
          total: 3,
        ),
      );
    };

    await controller.submitQuery('mario');
    await controller.loadMore();

    final List<String> ids = container
        .read(searchControllerProvider)
        .items
        .map((Game g) => g.id)
        .toList();
    expect(ids, <String>['p1a', 'p1b', 'p2a'], reason: 'merge por id');
    expect(container.read(searchControllerProvider).total, 3);
  });

  test(
    'fallback offline: com cache, exibe payload salvo + stale=true',
    () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer container = await _makeContainer(repo);
      addTearDown(container.dispose);
      final SearchController controller = container.read(
        searchControllerProvider.notifier,
      );

      // 1ª busca bem-sucedida grava o cache.
      await controller.submitQuery('mario');
      expect(container.read(searchControllerProvider).stale, isFalse);

      // Rede cai: mesma consulta volta do cache com aviso de desatualização.
      repo.failNext = 1;
      await controller.submitQuery('mario');
      final SearchState state = container.read(searchControllerProvider);
      expect(state.stale, isTrue, reason: 'mostrou dados salvos');
      expect(state.items, isNotEmpty, reason: 'nunca deixa a tela vazia');
      expect(state.status, SearchStatus.ready);
    },
  );

  test(
    'erro SEM cache: estado de erro explicado (tela não fica sem mensagem)',
    () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer container = await _makeContainer(repo);
      addTearDown(container.dispose);
      final SearchController controller = container.read(
        searchControllerProvider.notifier,
      );

      repo.failNext = 1;
      await controller.submitQuery('mario');
      final SearchState state = container.read(searchControllerProvider);
      expect(state.status, SearchStatus.error);
      expect(state.error, isNotNull);
      expect(state.items, isEmpty);
    },
  );

  test('"Você quis dizer…?" chega no estado quando a busca zera', () async {
    final _FakeRepo repo = _FakeRepo();
    final ProviderContainer container = await _makeContainer(repo);
    addTearDown(container.dispose);
    final SearchController controller = container.read(
      searchControllerProvider.notifier,
    );

    repo.onSearch = (SearchRequest request) => Future<SearchPayload>.value(
      const SearchPayload(items: <Game>[], total: 0, suggestion: 'Frontier'),
    );
    await controller.submitQuery('frontir');
    expect(container.read(searchControllerProvider).suggestion, 'Frontier');
  });

  test('histórico local: limite de 10, dedup e remoção de item', () async {
    final _FakeRepo repo = _FakeRepo();
    final ProviderContainer container = await _makeContainer(repo);
    addTearDown(container.dispose);

    for (int i = 0; i < 12; i += 1) {
      container.read(recentSearchesProvider.notifier).remember('busca $i');
    }
    List<String> recent = container.read(recentSearchesProvider);
    expect(recent.length, 10, reason: 'limite de ~10 itens');
    expect(recent.first, 'busca 11');

    container
        .read(recentSearchesProvider.notifier)
        .remember('busca 11'); // dedup: não duplica, sobe para o topo
    recent = container.read(recentSearchesProvider);
    expect(recent.length, 10);
    expect(recent.where((String s) => s == 'busca 11').length, 1);

    container.read(recentSearchesProvider.notifier).remove('busca 11');
    expect(
      container.read(recentSearchesProvider).contains('busca 11'),
      isFalse,
    );
  });

  test(
    'sugestões: debounce próprio, cancelamento e limpeza abaixo de 2 chars',
    () async {
      fakeAsync((FakeAsync async) async {
        final _FakeRepo repo = _FakeRepo();
        final ProviderContainer container = await _makeContainer(repo);
        addTearDown(container.dispose);
        final SuggestController suggest = container.read(
          suggestControllerProvider.notifier,
        );

        suggest.onTyped('fr');
        async.elapse(kSuggestDebounce + const Duration(milliseconds: 20));
        expect(repo.suggestQueries, <String>['fr']);
        expect(
          container.read(suggestControllerProvider).payload.games.first.title,
          'Jogo G',
        );

        // Digitação nova durante o voo: o resultado antigo é descartado.
        suggest.onTyped('fro');
        async.elapse(kSuggestDebounce + const Duration(milliseconds: 20));
        expect(repo.suggestQueries, <String>['fr', 'fro']);

        // Menos de 2 caracteres: estado limpo sem requisição.
        suggest.onTyped('f');
        async.elapse(kSuggestDebounce + const Duration(milliseconds: 20));
        expect(repo.suggestQueries, <String>['fr', 'fro']);
        expect(
          container.read(suggestControllerProvider).payload.isEmpty,
          isTrue,
        );
      });
    },
  );

  test('refresh mantém os itens visíveis (sem flash de esqueleto)', () async {
    final _FakeRepo repo = _FakeRepo();
    final ProviderContainer container = await _makeContainer(repo);
    addTearDown(container.dispose);
    final SearchController controller = container.read(
      searchControllerProvider.notifier,
    );

    await controller.submitQuery('mario');
    expect(container.read(searchControllerProvider).items, isNotEmpty);
    final Future<void> refreshing = controller.refresh();
    expect(
      container.read(searchControllerProvider).items,
      isNotEmpty,
      reason: 'pull-to-refresh não pode limpar a tela',
    );
    await refreshing;
  });

  test(
    'digitar 5 teclas notifica o estado NO MÁXIMO 2 vezes (sem re-render por tecla)',
    () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer container = await _makeContainer(repo);
      addTearDown(container.dispose);

      int notifications = 0;
      final ProviderSubscription<SearchState> sub = container.listen(
        searchControllerProvider,
        (_, SearchState _) => notifications++,
      );
      addTearDown(sub.close);

      final SearchController controller = container.read(
        searchControllerProvider.notifier,
      );
      for (final String step in <String>['m', 'ma', 'mar', 'mari', 'mario']) {
        controller.setQuery(step);
      }
      // 1ª tecla troca trending→relevance (1); 'm' (<2 chars) reseta (1).
      // As demais teclas NÃO escrevem o estado — a grade não reconstrói.
      expect(
        notifications,
        lessThan(3),
        reason: '5 teclas ⇒ no máximo troca de ordenação + reset; nunca 5',
      );
    },
  );

  test(
    'fetch assentado ecoa a query BRUTA do campo (espaço final preservado)',
    () async {
      final _FakeRepo repo = _FakeRepo();
      final ProviderContainer container = await _makeContainer(repo);
      addTearDown(container.dispose);
      final SearchController controller = container.read(
        searchControllerProvider.notifier,
      );

      controller.setQuery('mario ');
      await Future<void>.delayed(
        kSearchDebounce + const Duration(milliseconds: 20),
      );
      await pumpEventQueue();
      expect(
        container.read(searchControllerProvider).query,
        'mario ',
        reason: 'echo bruto no settle, sem apagar o espaço digitado',
      );
      expect(repo.queries, <String>['mario']);
    },
  );
}
