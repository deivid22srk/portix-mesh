import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/apk_tools.dart';
import 'package:portix/core/github_releases.dart';
import 'package:portix/core/github_service.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/details/game_detail_page.dart';
import 'package:portix/features/downloads/downloads_controller.dart';
import 'package:portix/models/app_update.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/compat_report.dart';
import 'package:portix/models/compat_summary.dart';
import 'package:portix/models/download_task.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/news.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/models/public_profile.dart';
import 'package:portix/models/search.dart';
import 'package:portix/models/user_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Fakes
// ============================================================================

class FakeCatalogRepository implements CatalogRepository {
  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async => const HomeFeed();

  @override
  Future<CatalogFacets> fetchFacets() async => const CatalogFacets();

  @override
  Future<GameDetail> fetchGame(String slug) async => _detail;

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

/// Controller que parte de uma tarefa já concluída e grava chamadas de start.
class FakeDownloadsController extends DownloadsController {
  final List<({String url, String? releaseTag})> started =
      <({String url, String? releaseTag})>[];

  @override
  List<DownloadTask> build() => <DownloadTask>[_doneTask];

  @override
  void start(
    Game game, {
    GamePort? port,
    String? urlOverride,
    String? releaseTag,
    bool restart = false,
  }) {
    started.add((url: urlOverride ?? '', releaseTag: releaseTag));
  }
}

// ============================================================================
// Fixtures (releases reais de VinTeRuS/spore-re)
// ============================================================================

const Game _game = Game(
  id: 'spore-1',
  slug: 'spore',
  title: 'Spore',
  genre: 'Sandbox',
  platforms: <String>['Android'],
  downloadCount: 1200,
  rating: 4.6,
  ratingCount: 132,
  description: 'Port de Spore para Android.',
);

const GamePort _port = GamePort(
  id: 'p1',
  portKey: 'spore-re',
  platformName: 'Android',
  platformSlug: 'android',
  url: 'https://github.com/VinTeRuS/spore-re',
);

const GameDetail _detail = GameDetail(
  game: _game,
  ports: <GamePort>[_port],
  compat: CompatSummary(),
);

ApkAsset _apk(String name) => ApkAsset(
  name: name,
  url: 'https://github.com/VinTeRuS/spore-re/releases/download/v1/$name',
  sizeBytes: 98818871,
  downloadCount: 106,
);

final List<GithubRelease> _releases = <GithubRelease>[
  GithubRelease(
    tag: 'v0.1.4',
    publishedAt: DateTime(2026, 11, 16),
    assets: <ApkAsset>[_apk('spore.apk'), _apk('spore-vk11.apk')],
  ),
  GithubRelease(
    tag: 'v0.1.3',
    publishedAt: DateTime(2026, 11, 15),
    assets: <ApkAsset>[_apk('spore-v0.1.3.apk')],
  ),
  GithubRelease(
    tag: 'v0.1.2-beta',
    prerelease: true,
    publishedAt: DateTime(2026, 11, 14),
    assets: const <ApkAsset>[],
  ),
];

const DownloadTask _doneTask = DownloadTask(
  gameId: 'spore-1',
  title: 'Spore',
  slug: 'spore',
  status: DownloadStatus.done,
  progress: 1,
  releaseTag: 'v0.1.4',
  packageName: 'com.portix.spore',
  apkPath: '/tmp/spore.apk',
);

Future<ProviderContainer> _container({
  FakeDownloadsController? downloads,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      gameDetailProvider.overrideWith(
        (Ref ref, String slug) => Future<GameDetail>.value(_detail),
      ),
      gameCompatReportsProvider.overrideWith(
        (Ref ref, String gameId) =>
            Future<List<CompatReport>>.value(const <CompatReport>[]),
      ),
      repoReleasesProvider.overrideWith(
        (Ref ref, String repoId) =>
            Future<List<GithubRelease>>.value(_releases),
      ),
      githubUserProvider.overrideWith(
        (Ref ref, String owner) => Future<GithubUser?>.value(
          const GithubUser(
            login: 'VinTeRuS',
            name: 'VinTeRuS404',
            avatarUrl: '',
            htmlUrl: 'https://github.com/VinTeRuS',
            type: 'User',
          ),
        ),
      ),
      installedAppProvider.overrideWith(
        (Ref ref, String packageName) => Future<ApkSummary?>.value(
          const ApkSummary(
            packageName: 'com.portix.spore',
            versionName: '0.1.4',
          ),
        ),
      ),
      downloadsProvider.overrideWith(
        () => downloads ?? FakeDownloadsController(),
      ),
    ],
  );
}

void _mobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt'),
      supportedLocales: const <Locale>[Locale('pt'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark(),
      home: const Scaffold(body: GameDetailPage(slug: 'spore')),
    ),
  );
}

void main() {
  testWidgets(
    'CTA mostra "Abrir o app" com a versão instalada pré-selecionada',
    (WidgetTester tester) async {
      _mobileViewport(tester);
      final ProviderContainer container = await _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await tester.pumpAndSettle();

      expect(find.text('Baixar v0.1.4'), findsNothing);
      expect(find.text('Abrir o app'), findsOneWidget);
      // Estatísticas refletem a versão pré-selecionada.
      expect(find.text('v0.1.4'), findsWidgets);
      expect(find.text('94,2 MB'), findsOneWidget);
    },
  );

  testWidgets(
    'selecionar versão antiga → CTA "Atualizar" e diálogo de downgrade',
    (WidgetTester tester) async {
      _mobileViewport(tester);
      final FakeDownloadsController downloads = FakeDownloadsController();
      final ProviderContainer container = await _container(
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await tester.pumpAndSettle();

      // Task concluída (v0.1.4); o usuário toca na v0.1.3 (card com 1 APK).
      await tester.tap(find.text('v0.1.3'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Atualizar'), findsOneWidget);

      // Toca no CTA: 1 asset (sem sheet) → isOlderThan → diálogo de downgrade.
      await tester.tap(find.text('Atualizar'));
      await tester.pumpAndSettle();

      expect(find.text('Versão mais antiga'), findsOneWidget);
      expect(find.textContaining('v0.1.4 já está instalada'), findsOneWidget);
      expect(find.text('Baixar assim mesmo'), findsOneWidget);
      expect(downloads.started, isEmpty); // nada baixado antes da confirmação

      await tester.tap(find.text('Baixar assim mesmo'));
      await tester.pumpAndSettle();

      // Download da versão específica (não a mais recente) comprovado:
      expect(downloads.started, hasLength(1));
      expect(downloads.started.single.releaseTag, 'v0.1.3');
      expect(
        downloads.started.single.url,
        'https://github.com/VinTeRuS/spore-re/releases/download/v1/spore-v0.1.3.apk',
      );
    },
  );

  testWidgets('escolher "Depois" no diálogo de downgrade não baixa', (
    WidgetTester tester,
  ) async {
    _mobileViewport(tester);
    final FakeDownloadsController downloads = FakeDownloadsController();
    final ProviderContainer container = await _container(downloads: downloads);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('v0.1.3'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depois'));
    await tester.pumpAndSettle();

    expect(downloads.started, isEmpty);
  });

  testWidgets('release sem APK: card desabilitado e badge Beta', (
    WidgetTester tester,
  ) async {
    _mobileViewport(tester);
    final ProviderContainer container = await _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.textContaining('Nenhum arquivo .apk'), findsOneWidget);
  });
}
