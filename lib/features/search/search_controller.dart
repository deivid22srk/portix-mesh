import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache_store.dart';
import '../../core/providers.dart';
import '../../data/catalog_repository.dart';
import '../../models/game.dart';
import '../../models/search.dart';
import '../../models/parsing.dart';

enum SearchStatus { idle, loading, loadingMore, ready, empty, error }

/// Texto BRUTO do campo, separado do estado da busca: enquanto o usuário
/// digita, só ESTE provider muda — a grade de resultados não reconstrói a
/// cada tecla (perfil de re-render limpo).
class SearchTextNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final searchTextProvider = NotifierProvider<SearchTextNotifier, String>(
  SearchTextNotifier.new,
);

/// Modo de exibição dos resultados (grade = false, lista = true).
/// A rota o espelha para deep link; por padrão a grade.
class ResultsViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool isList) => state = isList;
}

final resultsViewProvider = NotifierProvider<ResultsViewNotifier, bool>(
  ResultsViewNotifier.new,
);

class SearchState {
  const SearchState({
    this.query = '',
    this.filters = const SearchFilters(),
    this.items = const <Game>[],
    this.total = 0,
    this.cursor,
    this.status = SearchStatus.idle,
    this.error,
    this.stale = false,
    this.suggestion,
  });

  final String query;
  final SearchFilters filters;
  final List<Game> items;
  final int total;

  /// Cursor keyset da próxima página (`search_games_v2`). Null = fim.
  final Map<String, dynamic>? cursor;

  final SearchStatus status;
  final Object? error;

  /// Exibindo payload do cache por falha de rede: os dados podem estar
  /// desatualizados (a tela mostra o aviso).
  final bool stale;

  /// "Você quis dizer…?" (título mais próximo) quando nada foi encontrado.
  final String? suggestion;

  bool get isInitialLoading => status == SearchStatus.loading && items.isEmpty;

  bool get isLoadingMore => status == SearchStatus.loadingMore;

  /// Paginação server-driven: com cursor há próxima página; no fallback
  /// legado (sem cursor) usa o total conhecido.
  bool get hasMore => cursor != null || items.length < total;

  SearchState copyWith({
    String? query,
    SearchFilters? filters,
    List<Game>? items,
    int? total,
    Map<String, dynamic>? cursor,
    bool clearCursor = false,
    SearchStatus? status,
    Object? error,
    bool clearError = false,
    bool? stale,
    String? suggestion,
    bool clearSuggestion = false,
  }) => SearchState(
    query: query ?? this.query,
    filters: filters ?? this.filters,
    items: items ?? this.items,
    total: total ?? this.total,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    stale: stale ?? this.stale,
    suggestion: clearSuggestion ? null : (suggestion ?? this.suggestion),
  );
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

// Últimas buscas ficam no dispositivo: nenhum dado sensível, só conveniência.
// Limite de ~10 itens (política da missão), nunca enviados ao servidor.
final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  static const String _key = 'search.recent';
  static const int _limit = 10;

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ??
      const <String>[];

  void remember(String query) {
    final String clean = query.trim();
    if (clean.isEmpty) {
      return;
    }
    final List<String> next = <String>[
      clean,
      ...state.where(
        (String item) => item.toLowerCase() != clean.toLowerCase(),
      ),
    ].take(_limit).toList(growable: false);
    state = next;
    unawaited(ref.read(sharedPreferencesProvider).setStringList(_key, next));
  }

  /// Remove UM item do histórico (toque no "x" do chip).
  void remove(String query) {
    final List<String> next = state
        .where((String item) => item.toLowerCase() != query.toLowerCase())
        .toList(growable: false);
    state = next;
    unawaited(ref.read(sharedPreferencesProvider).setStringList(_key, next));
  }

  void clear() {
    state = const <String>[];
    unawaited(ref.read(sharedPreferencesProvider).remove(_key));
  }

  /// Restaura um conjunto anterior de buscas (undo do "limpar histórico").
  void restoreAll(List<String> entries) {
    state = List<String>.unmodifiable(entries);
    unawaited(ref.read(sharedPreferencesProvider).setStringList(_key, entries));
  }
}

/// Debounce da busca: dentro da faixa 250–300 ms da especificação.
const Duration kSearchDebounce = Duration(milliseconds: 280);

/// Debounce das sugestões (mais rápido que a busca: é só prefetch de rótulos).
const Duration kSuggestDebounce = Duration(milliseconds: 180);

/// Mínimo de caracteres para buscar/sugerir.
const int kSearchMinChars = 2;

/// TTL do cache de resultados por consulta+filtros.
const Duration kSearchCacheTtl = Duration(seconds: 90);

class SearchController extends Notifier<SearchState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
    });
    return const SearchState();
  }

  // A busca só dispara na primeira vez que a tela aparece ou quando a home
  // envia um filtro; evita requisição duplicada ao abrir a aba.
  void ensureLoaded() {
    if (state.status == SearchStatus.idle) {
      unawaited(_fetch(reset: true));
    }
  }

  /// A cada tecla: atualiza o TEXTO (provider leve) e agenda o debounce.
  /// O estado do controller NÃO muda por tecla — a grade e a página não
  /// reconstruem até o fetch do debounce assentar.
  void setQuery(String value) {
    ref.read(searchTextProvider.notifier).set(value);
    _debounce?.cancel();
    if (value.trim().length < kSearchMinChars) {
      // Menos de 2 caracteres: volta ao modo descoberta (sem requisição
      // obsoleta e sem "1 resultado" para um byte digitado).
      state = state.copyWith(
        query: value,
        items: const <Game>[],
        total: 0,
        clearCursor: true,
        clearSuggestion: true,
        status: SearchStatus.idle,
        clearError: true,
        stale: false,
      );
      return;
    }
    SearchFilters next = state.filters;
    if (next.sort == kDefaultSort) {
      next = next.copyWith(sort: 'relevance');
    }
    if (next != state.filters) {
      state = state.copyWith(filters: next);
    }
    _debounce = Timer(kSearchDebounce, () {
      unawaited(_fetch(reset: true));
    });
  }

  /// Enter/botão buscar: cancela o debounce pendente e dispara agora.
  /// Devolve o Future do fetch para testes e sincronizações esperarem.
  Future<void> submitQuery(String value) async {
    _debounce?.cancel();
    ref.read(searchTextProvider.notifier).set(value);
    state = state.copyWith(query: value);
    if (value.trim().length < kSearchMinChars) {
      setQuery(value);
      return;
    }
    SearchFilters next = state.filters;
    if (next.sort == kDefaultSort) {
      next = next.copyWith(sort: 'relevance');
    }
    state = state.copyWith(filters: next);
    await _fetch(reset: true);
    final String clean = value.trim();
    if (clean.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).remember(clean);
    }
  }

  /// Limpa o texto e volta ao modo descoberta (Esc do campo / botão "x").
  void clearQuery() {
    _debounce?.cancel();
    ref.read(searchTextProvider.notifier).clear();
    state = state.copyWith(
      query: '',
      items: const <Game>[],
      total: 0,
      clearCursor: true,
      clearSuggestion: true,
      status: SearchStatus.idle,
      clearError: true,
      stale: false,
      filters: state.filters.copyWith(sort: kDefaultSort),
    );
  }

  void browse({
    String? platform,
    String? genre,
    bool freeOnly = false,
    String sort = kDefaultSort,
  }) {
    _debounce?.cancel();
    ref.read(searchTextProvider.notifier).clear();
    state = state.copyWith(
      query: '',
      filters: SearchFilters(
        platform: platform,
        genre: genre,
        freeOnly: freeOnly,
        sort: sort,
      ),
    );
    unawaited(_fetch(reset: true));
  }

  void applyFilters(SearchFilters filters) {
    _debounce?.cancel();
    state = state.copyWith(filters: filters);
    unawaited(_fetch(reset: true));
  }

  void resetFilters() => applyFilters(const SearchFilters());

  /// Puxa para atualizar: mantém os itens visíveis (sem flash de esqueleto) —
  /// o estado nunca some da tela por causa de um refresh.
  Future<void> refresh() => _fetch(reset: true, keepItems: true);

  Future<void> loadMore() async {
    if (state.status != SearchStatus.ready || !state.hasMore) {
      return;
    }
    await _fetch(reset: false);
  }

  /// Chave estável do cache: consulta normalizada + assinatura dos filtros.
  String _cacheKey(String query, SearchFilters filters) =>
      'search.v1:${query.toLowerCase()}|'
      '${filters.platform ?? '-'}/${filters.genre ?? '-'}/'
      '${filters.freeOnly ? 1 : 0}/${filters.needsRom ? 1 : 0}/'
      '${filters.minRating ?? '-'}/${filters.sort}';

  Map<String, dynamic>? _readCache(String key) {
    final CacheStore cache = ref.read(cacheStoreProvider);
    final Map<String, dynamic>? raw = cache.readMap(key);
    if (raw == null) {
      return null;
    }
    final int written = asInt(raw['t']);
    if (DateTime.now().millisecondsSinceEpoch - written >
        kSearchCacheTtl.inMilliseconds) {
      return null;
    }
    final Object? payload = raw['payload'];
    return payload is Map ? asMap(payload) : null;
  }

  Future<void> _writeCache(String key, Map<String, dynamic> payload) async {
    final CacheStore cache = ref.read(cacheStoreProvider);
    await cache.writeMap(key, <String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
  }

  Future<void> _fetch({required bool reset, bool keepItems = false}) async {
    final int requestId = ++_requestId;
    // O TEXTO vem do provider leve (fonte da verdade do campo); a versão
    // trimada serve para a requisição e para o histórico.
    final String query = ref.read(searchTextProvider).trim();
    final SearchFilters filters = state.filters;
    final bool useCursor = !reset && state.cursor != null;
    final String cacheKey = _cacheKey(query, filters);
    // Cache de leitura só na CARGA INICIAL (aba reaberta): digitar/submeter
    // sempre vai à rede — resultados frescos e contrato previsível.
    final bool wasIdle = state.status == SearchStatus.idle;

    state = SearchState(
      query: ref.read(searchTextProvider),
      filters: filters,
      items: (reset && !keepItems) ? const <Game>[] : state.items,
      total: (reset && !keepItems) ? 0 : state.total,
      cursor: useCursor ? state.cursor : null,
      status: reset ? SearchStatus.loading : SearchStatus.loadingMore,
      error: reset ? null : state.error,
      stale: reset ? false : state.stale,
    );

    try {
      Map<String, dynamic> payloadMap;
      if (useCursor) {
        final SearchPayload payload = await ref
            .read(catalogRepositoryProvider)
            .search(
              SearchRequest(
                query: query,
                filters: filters,
                cursor: state.cursor,
              ),
            );
        payloadMap = <String, dynamic>{
          'items': payload.items.map(_gameToMap).toList(),
          'total': payload.total,
          'cursor': payload.cursor,
          'suggestion': payload.suggestion,
        };
      } else {
        // Cache de leitura (TTL curto): só na carga inicial — abre
        // instantâneo quando bate; digitar/submeter sempre refetch.
        final Map<String, dynamic>? cached = reset && wasIdle
            ? _readCache(cacheKey)
            : null;
        if (cached != null) {
          payloadMap = cached;
          if (requestId != _requestId) {
            return;
          }
        } else {
          final SearchPayload payload = await ref
              .read(catalogRepositoryProvider)
              .search(SearchRequest(query: query, filters: filters));
          if (requestId != _requestId) {
            return;
          }
          payloadMap = <String, dynamic>{
            'items': payload.items.map(_gameToMap).toList(),
            'total': payload.total,
            'cursor': payload.cursor,
            'suggestion': payload.suggestion,
          };
          if (query.isNotEmpty) {
            unawaited(_writeCache(cacheKey, payloadMap));
          }
        }
      }

      if (requestId != _requestId) {
        return;
      }
      final List<Game> incoming = asMapList(
        payloadMap['items'],
      ).map(Game.fromMap).toList(growable: false);
      final Map<String, dynamic>? nextCursor = payloadMap['cursor'] is Map
          ? asMap(payloadMap['cursor'])
          : null;
      final List<Game> items = useCursor
          ? _merge(state.items, incoming)
          : incoming;
      // Página seguinte sem total recontado (cursor): preserva o anterior.
      final int total = useCursor ? state.total : asInt(payloadMap['total']);
      state = SearchState(
        // A query BRUTA do campo (searchTextProvider) é a fonte da verdade:
        // ecoada UMA vez, quando o fetch assenta — nunca por tecla, então a
        // grade não reconstrói enquanto o usuário digita.
        query: ref.read(searchTextProvider),
        filters: filters,
        items: items,
        total: total,
        cursor: nextCursor,
        status: items.isEmpty ? SearchStatus.empty : SearchStatus.ready,
        suggestion: asText(payloadMap['suggestion']),
      );
    } on Object catch (error) {
      if (requestId != _requestId) {
        return;
      }
      // Fallback em camadas: (1) cache da MESMA consulta mesmo fora do TTL —
      // melhor dados antigos que tela vazia; (2) estado de erro explicado.
      final Map<String, dynamic>? stalePayload = reset
          ? _staleOnly(cacheKey)
          : null;
      if (reset && stalePayload != null) {
        final List<Game> items = asMapList(
          stalePayload['items'],
        ).map(Game.fromMap).toList(growable: false);
        state = SearchState(
          query: ref.read(searchTextProvider),
          filters: filters,
          items: items,
          total: asInt(stalePayload['total']),
          status: items.isEmpty ? SearchStatus.empty : SearchStatus.ready,
          error: error,
          stale: true,
        );
        return;
      }
      state = SearchState(
        // Idem ao sucesso: nunca ecoar a query trimada/congelada de volta.
        query: ref.read(searchTextProvider),
        filters: filters,
        items: reset ? const <Game>[] : state.items,
        total: reset ? 0 : state.total,
        status: reset ? SearchStatus.error : SearchStatus.ready,
        error: error,
      );
    }
  }

  Map<String, dynamic>? _staleOnly(String key) {
    final Map<String, dynamic>? raw = ref.read(cacheStoreProvider).readMap(key);
    if (raw == null) {
      return null;
    }
    final Object? payload = raw['payload'];
    return payload is Map ? asMap(payload) : null;
  }

  List<Game> _merge(List<Game> current, List<Game> incoming) {
    final Set<String> seen = current.map((Game game) => game.id).toSet();
    final List<Game> next = <Game>[...current];
    for (final Game game in incoming) {
      if (seen.add(game.id)) {
        next.add(game);
      }
    }
    return next;
  }
}

// ---------------------------------------------------------------------------
// Sugestões instantâneas (enquanto digita): provider leve, com debounce e
// cancelamento próprios — NUNCA lança, NUNCA bloqueia a digitação.
// ---------------------------------------------------------------------------

class SuggestState {
  const SuggestState({
    this.payload = const SuggestPayload(),
    this.query = '',
    this.loading = false,
  });

  final SuggestPayload payload;
  final String query;
  final bool loading;
}

final suggestControllerProvider =
    NotifierProvider<SuggestController, SuggestState>(SuggestController.new);

class SuggestController extends Notifier<SuggestState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  SuggestState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
    });
    return const SuggestState();
  }

  void onTyped(String value) {
    _debounce?.cancel();
    if (value.trim().length < kSearchMinChars) {
      _requestId++; // invalida voos anteriores: nada volta depois de limpar
      state = const SuggestState();
      return;
    }
    _debounce = Timer(kSuggestDebounce, () {
      unawaited(_fetch(value));
    });
  }

  Future<void> _fetch(String value) async {
    final int requestId = ++_requestId;
    state = SuggestState(payload: state.payload, query: value, loading: true);
    final SuggestPayload payload = await _suggest(value);
    if (requestId != _requestId) {
      return; // digitação nova vence: resultado antigo é descartado
    }
    state = SuggestState(payload: payload, query: value, loading: false);
  }

  Future<SuggestPayload> _suggest(String value) async {
    try {
      final ExploreDiscoveryRepository? repo = _suggestRepository();
      if (repo == null) {
        return const SuggestPayload();
      }
      return await repo.suggest(value);
    } on Object {
      return const SuggestPayload();
    }
  }

  ExploreDiscoveryRepository? _suggestRepository() {
    final CatalogRepository repo = ref.read(catalogRepositoryProvider);
    // ExploreDiscoveryRepository NÃO é subtipo de CatalogRepository: um cast
    // explícito é necessário (o SupabaseCatalogRepository implementa ambos).
    return repo is ExploreDiscoveryRepository
        ? repo as ExploreDiscoveryRepository
        : null;
  }
}

Map<String, dynamic> _gameToMap(Game game) => <String, dynamic>{
  'id': game.id,
  'slug': game.slug,
  'title': game.title,
  'year': game.year,
  'genre': game.genre,
  'cover_url': game.coverUrl,
  'developer': game.developer,
  'description': game.description,
  'platforms': game.platforms,
  'port_count': game.portCount,
  'visit_count': game.visitCount,
  'download_count': game.downloadCount,
  'rating_avg': game.rating,
  'rating_count': game.ratingCount,
  'is_free': game.isFree,
  'needs_rom': game.needsRom,
  'released_on': game.releasedOn?.toIso8601String(),
};
