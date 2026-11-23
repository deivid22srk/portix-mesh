// Golden de apoio: renderiza os componentes novos da tela de detalhes com
// dados reais (releases do VinTeRuS/spore-re capturadas da API do GitHub).
// Gera PNGs para auditoria visual do CRÍTICO.
//   flutter test test/screenshots_golden_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/github_releases.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/core/github_service.dart';
import 'package:portix/features/details/developer_card.dart';
import 'package:portix/features/details/version_selector.dart';
import 'package:portix/shared/widgets/game_media.dart';
import 'package:portix/shared/widgets/markdown_lite.dart';
import 'package:portix/shared/widgets/primitives.dart';

import 'package:portix/features/details/game_detail_page.dart';
import 'package:portix/features/downloads/downloads_controller.dart';
import 'package:portix/models/download_task.dart';
import 'package:portix/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/detail_fixtures.dart';
import 'fakes/fake_catalog.dart';

const DownloadTask kDoneTask = DownloadTask(
  gameId: 'spore-1',
  title: 'Spore',
  slug: 'spore',
  status: DownloadStatus.done,
  progress: 1,
  releaseTag: 'v0.1.4',
  packageName: 'com.portix.spore',
  apkPath: '/tmp/spore.apk',
);

/// Downloads ociosos para os goldens: sem tocar no canal nativo.
class IdleDownloads extends DownloadsController {
  @override
  List<DownloadTask> build() => const <DownloadTask>[];
}

const String _outDir = 'goldens_out';

/// Fonte real (Liberation Sans) para os goldens ficarem legíveis: o Poppins
/// do Google Fonts não carrega no ambiente de teste (rede bloqueada).
Future<void> _loadFonts() async {
  final ByteData regular =
      await File(
        '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      ).readAsBytes().then(
        (List<int> bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
      );
  final ByteData bold =
      await File(
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
      ).readAsBytes().then(
        (List<int> bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
      );
  final FontLoader loader = FontLoader('Liberation Sans')
    ..addFont(Future<ByteData>.value(regular))
    ..addFont(Future<ByteData>.value(bold));
  await loader.load();
}

ApkAsset _apk(String name, {required int size, required int downloads}) =>
    ApkAsset(
      name: name,
      url:
          'https://github.com/VinTeRuS/spore-re/releases/download/v0.1.4/$name',
      sizeBytes: size,
      downloadCount: downloads,
    );

// Dados REAIS capturados de GET /repos/VinTeRuS/spore-re/releases (17/11/2026).
final List<GithubRelease> _sporeReleases = <GithubRelease>[
  GithubRelease(
    tag: 'v0.1.4',
    name: 'v0.1.4',
    publishedAt: DateTime(2026, 11, 16, 19, 45),
    body:
        'Early build, expect bugs.\n- `spore.apk` is for **Vulkan 1.3 GPUs** (most phones)\n- `spore-vk11.apk` for older ones with Vulkan 1.1',
    assets: <ApkAsset>[
      _apk('spore.apk', size: 98818871, downloads: 106),
      _apk('spore-vk11.apk', size: 98495287, downloads: 92),
    ],
  ),
  GithubRelease(
    tag: 'v0.1.3',
    publishedAt: DateTime(2026, 11, 15, 17, 59),
    body: 'Early build, expect bugs.',
    assets: <ApkAsset>[
      _apk('spore.apk', size: 98814775, downloads: 7),
      _apk('spore-vk11.apk', size: 98495287, downloads: 239),
    ],
  ),
  GithubRelease(
    tag: 'v0.1.2-beta',
    prerelease: true,
    publishedAt: DateTime(2026, 11, 15, 8, 32),
    assets: const <ApkAsset>[], // release sem APK compatível (caso de borda)
  ),
];

bool get _goldensEnabled => Platform.environment['GOLDENS'] == '1';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repoReleasesProvider.overrideWith(
          (Ref ref, String repoId) =>
              Future<List<GithubRelease>>.value(_sporeReleases),
        ),
        githubUserProvider.overrideWith(
          // Avatar vazio nos goldens: o CachedNetworkImage exige plugin de
          // path_provider indisponível em testes; o fallback de iniciais é
          // exatamente o que a foto quebrada renderizaria.
          (Ref ref, String owner) => Future<GithubUser?>.value(
            const GithubUser(
              login: 'VinTeRuS',
              name: 'VinTeRuS404',
              avatarUrl: '',
              htmlUrl: 'https://github.com/VinTeRuS',
              type: 'User',
              publicRepos: 13,
              followers: 37,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt'),
        supportedLocales: const <Locale>[Locale('pt'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _readableTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tema do app com a fonte de teste aplicada a todo o textTheme.
ThemeData _readableTheme() {
  final ThemeData base = AppTheme.dark();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Liberation Sans'),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'Liberation Sans',
    ),
  );
}

Future<void> _snap(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_outDir/$name.png'),
  );
  stderr.writeln('golden gerado: $_outDir/$name.png');
}

void main() {
  setUpAll(() async {
    // Ferramenta local de evidência visual (GOLDENS=1 para gerar PNGs).
    // No CI não existem arquivos de referência nem a mesma fonte — pula.
    if (Platform.environment['GOLDENS'] != '1') {
      stderr.writeln('goldens pulado (defina GOLDENS=1 para gerar)');
      return;
    }
    await Directory(_outDir).create(recursive: true);
    await _loadFonts();
  });

  testWidgets('mobile 375px — seletor + novidades (3 releases reais)', (
    WidgetTester tester,
  ) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpAt(
      tester,
      const Size(375, 860),
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (BuildContext context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Spore',
                  style: context.texts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                VersionSelector(
                  repoId: 'VinTeRuS/spore-re',
                  selectedTag: null,
                  installedTag: 'v0.1.3',
                  onSelected: (GithubRelease release) {},
                ),
                const SizedBox(height: 24),
                MarkdownLite(data: _sporeReleases.first.body ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
    await _snap(tester, 'seletor_mobile_375');
  });

  testWidgets('wide 768px — seletor segmentado + desenvolvedor', (
    WidgetTester tester,
  ) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpAt(
      tester,
      const Size(768, 760),
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[DeveloperCard(owner: 'VinTeRuS')],
                ),
              ),
              SizedBox(width: 32),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    VersionSelector(
                      repoId: 'VinTeRuS/spore-re',
                      selectedTag: null,
                      installedTag: 'v0.1.3',
                      onSelected: (GithubRelease release) {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _snap(tester, 'seletor_dev_wide_768');
  });

  testWidgets('estado rate limit (403/429) da seção de versões', (
    WidgetTester tester,
  ) async {
    if (!_goldensEnabled) {
      return;
    }
    tester.view.physicalSize = const Size(375, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoReleasesProvider.overrideWith(
            (Ref ref, String repoId) => Future<List<GithubRelease>>.error(
              const GitHubApiException(GitHubErrorKind.rateLimit),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          supportedLocales: const <Locale>[Locale('pt'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _readableTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: VersionSelector(
                repoId: 'VinTeRuS/spore-re',
                selectedTag: null,
                installedTag: null,
                onSelected: (GithubRelease release) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _snap(tester, 'estado_rate_limit');
  });

  testWidgets('hero com capa procedural (sem rede) — header real', (
    WidgetTester tester,
  ) async {
    if (!_goldensEnabled) {
      return;
    }
    await _pumpAt(
      tester,
      const Size(375, 240),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 122,
              height: 164,
              child: GameCover(imageUrl: null, title: 'Spore', memWidth: 360),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Spore'),
                  SizedBox(height: 8),
                  RatingLine(rating: 4.6, count: 132),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await _snap(tester, 'hero_mobile_375');
  });

  Future<ProviderContainer> pageContainer() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        gameDetailProvider.overrideWith(
          (Ref ref, String slug) => Future<GameDetail>.value(kSporeDetail),
        ),
        repoReleasesProvider.overrideWith(
          (Ref ref, String repoId) =>
              Future<List<GithubRelease>>.value(kSporeReleases),
        ),
        githubUserProvider.overrideWith(
          (Ref ref, String owner) => Future<GithubUser?>.value(kSporeUser),
        ),
        downloadsProvider.overrideWith(IdleDownloads.new),
      ],
    );
  }

  Future<void> pumpFullPage(
    WidgetTester tester,
    Size size,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt'),
          supportedLocales: const <Locale>[Locale('pt'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _readableTheme(),
          home: const Scaffold(body: GameDetailPage(slug: 'spore')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TELA COMPLETA mobile 375px', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    final ProviderContainer container = await pageContainer();
    addTearDown(container.dispose);
    await pumpFullPage(tester, const Size(375, 860), container);
    await _snap(tester, 'detalhes_completo_375');
  });

  testWidgets('TELA COMPLETA tablet 768px (2 colunas)', (
    WidgetTester tester,
  ) async {
    if (!_goldensEnabled) {
      return;
    }
    final ProviderContainer container = await pageContainer();
    addTearDown(container.dispose);
    await pumpFullPage(tester, const Size(768, 1024), container);
    await _snap(tester, 'detalhes_completo_768');
  });

  testWidgets('TELA COMPLETA desktop 1440px', (WidgetTester tester) async {
    if (!_goldensEnabled) {
      return;
    }
    final ProviderContainer container = await pageContainer();
    addTearDown(container.dispose);
    await pumpFullPage(tester, const Size(1440, 900), container);
    await _snap(tester, 'detalhes_completo_1440');
  });
}
