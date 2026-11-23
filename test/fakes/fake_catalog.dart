// Catálogo fake (sem Supabase) para testes de widget da página de detalhes.
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/models/app_update.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/compat_report.dart';

import 'package:portix/models/game_detail.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/news.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/models/public_profile.dart';
import 'package:portix/models/search.dart';
import 'package:portix/models/user_result.dart';

import 'detail_fixtures.dart';

class FakeCatalogRepository implements CatalogRepository {
  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async => const HomeFeed();

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets();

  @override
  Future<GameDetail> fetchGame(String slug) async => kSporeDetail;

  @override
  Future<SearchPayload> search(SearchRequest request) async =>
      const SearchPayload();

  @override
  Future<NewsPayload> fetchNews({int offset = 0, int limit = 20}) async =>
      const NewsPayload();

  @override
  Future<NewsItem?> fetchNewsArticle(String slug) async => null;

  @override
  Future<List<CompatReport>> fetchCompatReports(String gameId) async =>
      const <CompatReport>[];

  @override
  Future<UserProfile> fetchProfile() async => const UserProfile(id: 'me');

  @override
  Future<void> setHandle(String handle) async {}

  @override
  Future<List<UserResult>> searchUsers(String query) async =>
      const <UserResult>[];

  @override
  Future<PublicProfile> fetchPublicProfile(String id) async =>
      PublicProfile(id: id);

  @override
  Future<AppUpdate?> fetchLatestUpdate() async => null;

  @override
  Future<void> updateProfile({String? displayName, String? coverUrl}) async {}

  @override
  Future<Collections> fetchCollections() async => Collections.empty;

  @override
  Future<bool> toggleFavorite(String gameId) async => true;

  @override
  Future<bool> toggleLibrary(String gameId) async => true;

  @override
  Future<void> addToLibrary(String gameId) async {}

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
  }) async {}

  @override
  Future<void> syncDownload({
    required String gameId,
    required String? portKey,
    required String status,
    required int progress,
  }) async {}
}
