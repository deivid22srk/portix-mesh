import '../models/app_update.dart';
import '../models/collections.dart';
import '../models/compat_report.dart';
import '../models/explore.dart';
import '../models/game_detail.dart';
import '../models/home_feed.dart';
import '../models/news.dart';
import '../models/profile.dart';
import '../models/public_profile.dart';
import '../models/search.dart';
import '../models/user_result.dart';

// ---------------------------------------------------------------------------
// Impressões do feed — política de privacidade, na camada de dados.
//
// O usuário pode desligar o registro de impressões; a ausência da preferência
// significa "permitido" (opt-out explícito, nunca opt-in silencioso).
// ---------------------------------------------------------------------------

/// Chave local (sem o prefixo `cache.` do [CacheStore]) da preferência.
const String kFeedImpressionsPrefKey = 'privacy.feed_impressions';

/// Permitido quando a preferência está ausente ou vale `on`; qualquer outro
/// valor (ex.: `off`) desliga o registro.
bool feedImpressionsAllowed(String? value) => value == null || value == 'on';

/// Capacidade do feed algorítmico (RPC `get_home_feed`, migration 0023).
///
/// Fica SEPARADA de [CatalogRepository] de propósito: implementações legadas
/// (e fakes de teste) continuam válidas sem conhecer a nova RPC; o controller
/// degrada para [CatalogRepository.fetchHome] quando o repositório não a
/// implementa. Assim a assinatura de [CatalogRepository] não muda.
abstract interface class HomeFeedAlgorithmRepository {
  /// Primeira página do feed, com seções, facetas e estatísticas.
  Future<HomeFeed> fetchHomeFeed({
    required String seed,
    List<String> seen,
    Map<String, dynamic>? cursor,
    List<String>? sections,
  });

  /// Próxima página da seção `discover` (paginação keyset por cursor).
  Future<HomeFeed> loadMoreDiscover({
    required String seed,
    required Map<String, dynamic> cursor,
    List<String> seen,
    List<String>? sections,
  });

  /// Registra impressões (cards realmente visíveis). Melhor esforço: nunca
  /// lança — a métrica não é caminho crítico.
  Future<void> recordImpressions(
    List<Map<String, dynamic>> items, {
    String? sessionId,
  });
}

/// Capacidade de descoberta e sugestões da tela Explorar (RPCs da migration
/// 0025). Fica SEPARADA de [CatalogRepository] de propósito — o mesmo padrão
/// de [HomeFeedAlgorithmRepository]: implementações legadas e fakes de teste
/// continuam válidos sem conhecer as RPCs novas.
abstract interface class ExploreDiscoveryRepository {
  /// Feed agregado da Explorar (uma chamada: seções + categorias + termos).
  Future<ExploreFeed> fetchExploreFeed();

  /// Último feed bom em cache local (stale-while-revalidate / offline).
  ExploreFeed? readCachedExploreFeed();

  /// Sugestões instantâneas para o texto digitado. NUNCA lança: a camada
  /// devolve payload vazio em qualquer falha — sugestão não pode quebrar
  /// a digitação.
  Future<SuggestPayload> suggest(String query);
}

abstract class CatalogRepository {
  HomeFeed? readCachedHome();

  Future<HomeFeed> fetchHome();

  Future<CatalogFacets> fetchFacets();

  Future<GameDetail> fetchGame(String slug);

  Future<SearchPayload> search(SearchRequest request);

  Future<NewsPayload> fetchNews({int offset = 0, int limit = 20});

  Future<NewsItem?> fetchNewsArticle(String slug);

  Future<List<CompatReport>> fetchCompatReports(String gameId);

  Future<UserProfile> fetchProfile();

  Future<void> setHandle(String handle);

  Future<List<UserResult>> searchUsers(String query);

  Future<PublicProfile> fetchPublicProfile(String id);

  Future<AppUpdate?> fetchLatestUpdate();

  Future<void> updateProfile({String? displayName, String? coverUrl});

  Future<Collections> fetchCollections();

  Future<bool> toggleFavorite(String gameId);

  Future<bool> toggleLibrary(String gameId);

  Future<void> addToLibrary(String gameId);

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
  });

  Future<void> syncDownload({
    required String gameId,
    required String? portKey,
    required String status,
    required int progress,
  });
}
