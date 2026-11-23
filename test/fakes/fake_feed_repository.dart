// Repositório de feed em memória para os testes do feed algorítmico.
//
// Implementa as duas capacidades (catálogo + feed novo) e registra as chamadas
// para assegurar paginação sem duplicar, rotação de seed e impressões.
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/models/home_feed.dart';

class FakeFeedRepository
    implements CatalogRepository, HomeFeedAlgorithmRepository {
  FakeFeedRepository({
    this.onFetch,
    this.onLegacy,
    this.cached,
    this.loadMorePages = const <HomeFeed>[],
  });

  /// Primeira página do feed novo; por padrão devolve um feed vazio válido.
  Future<HomeFeed> Function(String seed)? onFetch;

  /// RPC legada (fallback). Ausente ⇒ `fetchHome` lança.
  Future<HomeFeed> Function()? onLegacy;

  HomeFeed? cached;

  /// Páginas devolvidas, em ordem, por `loadMoreDiscover`. Quando acabam, o
  /// fake responde uma seção `discover` sem cursor (fim de lista).
  List<HomeFeed> loadMorePages;

  final List<String> seeds = <String>[];
  final List<Map<String, dynamic>> loadMoreCursors = <Map<String, dynamic>>[];
  final List<List<Map<String, dynamic>>> impressionBatches =
      <List<Map<String, dynamic>>>[];

  /// Quantas vezes o fallback legado foi acionado.
  int legacyCalls = 0;
  int _pageIndex = 0;

  @override
  HomeFeed? readCachedHome() => cached;

  @override
  Future<HomeFeed> fetchHome() async {
    legacyCalls++;
    final Future<HomeFeed> Function()? handler = onLegacy;
    if (handler == null) {
      throw StateError('FakeFeedRepository.fetchHome não configurado');
    }
    return handler();
  }

  @override
  Future<HomeFeed> fetchHomeFeed({
    required String seed,
    List<String> seen = const <String>[],
    Map<String, dynamic>? cursor,
    List<String>? sections,
  }) {
    seeds.add(seed);
    final Future<HomeFeed> Function(String seed)? handler = onFetch;
    if (handler == null) {
      return Future<HomeFeed>.value(const HomeFeed());
    }
    return handler(seed);
  }

  @override
  Future<HomeFeed> loadMoreDiscover({
    required String seed,
    required Map<String, dynamic> cursor,
    List<String> seen = const <String>[],
    List<String>? sections,
  }) async {
    loadMoreCursors.add(cursor);
    if (_pageIndex < loadMorePages.length) {
      return loadMorePages[_pageIndex++];
    }
    return const HomeFeed(
      sections: <HomeFeedSection>[
        HomeFeedSection(key: 'discover', kind: 'grid'),
      ],
    );
  }

  @override
  Future<void> recordImpressions(
    List<Map<String, dynamic>> items, {
    String? sessionId,
  }) async {
    impressionBatches.add(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} não usado no fake');
}
