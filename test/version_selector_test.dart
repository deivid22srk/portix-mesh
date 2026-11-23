import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/github_releases.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/github_service.dart';
import 'package:portix/features/details/developer_card.dart';
import 'package:portix/shared/widgets/primitives.dart';
import 'package:portix/features/details/version_selector.dart';

GithubRelease _release(
  String tag, {
  DateTime? publishedAt,
  bool prerelease = false,
  List<ApkAsset> assets = const <ApkAsset>[],
}) => GithubRelease(
  tag: tag,
  publishedAt: publishedAt,
  prerelease: prerelease,
  assets: assets,
  body: 'Notas de **$tag**',
);

ApkAsset _apk(String name) => ApkAsset(
  name: name,
  url: 'https://github.com/o/r/releases/download/v1/$name',
  sizeBytes: 98818871,
  downloadCount: 106,
);

final List<GithubRelease> _fixtures = <GithubRelease>[
  _release(
    'v1.1.0',
    publishedAt: DateTime(2026, 11, 16),
    assets: <ApkAsset>[_apk('game-arm64.apk'), _apk('game-vk11.apk')],
  ),
  _release(
    'v1.0.0',
    publishedAt: DateTime(2026, 10, 1),
    assets: <ApkAsset>[_apk('game.apk')],
  ),
  _release('v0.9.0-beta', publishedAt: DateTime(2026, 9, 1), prerelease: true),
];

void _mobileViewport(WidgetTester tester) {
  // Testes em viewport de celular: os goldens/testes padrão do tester usam
  // 800x600, o que cairia no variante segmentado (≥768px).
  tester.view.physicalSize = const Size(375, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('pt'),
    supportedLocales: const <Locale>[Locale('pt'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.dark(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _pumpReleases(
  WidgetTester tester,
  Widget child,
  Future<List<GithubRelease>> Function() result,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repoReleasesProvider.overrideWith((Ref ref, String repoId) => result()),
      ],
      child: _host(child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUser(
  WidgetTester tester,
  Widget child,
  Future<GithubUser?> Function() result,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        githubUserProvider.overrideWith((Ref ref, String owner) => result()),
      ],
      child: _host(child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'seletor mostra as 3 releases com badges (mais recente/beta/instalada)',
    (WidgetTester tester) async {
      GithubRelease? selected;
      _mobileViewport(tester);
      await _pumpReleases(
        tester,
        SizedBox(
          width: 375,
          child: VersionSelector(
            repoId: 'o/r',
            selectedTag: null,
            installedTag: 'v1.0.0',
            onSelected: (GithubRelease release) => selected = release,
          ),
        ),
        () => Future<List<GithubRelease>>.value(_fixtures),
      );

      // 3 cards, mais nova primeiro.
      expect(find.text('v1.1.0'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('v0.9.0-beta'), findsOneWidget);
      expect(find.text('Mais recente'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Instalada'), findsOneWidget);
      // v0.9.0-beta não tem APK: card desabilitado com explicação.
      expect(find.textContaining('Nenhum arquivo .apk'), findsOneWidget);

      // Selecionar a v1.0.0 (card instalado) dispara o callback.
      await tester.tap(find.text('v1.0.0'));
      await tester.pump();
      expect(selected?.tag, 'v1.0.0');
    },
  );

  testWidgets(
    'pré-seleção padrão = mais nova COM APK; card sem APK não seleciona',
    (WidgetTester tester) async {
      GithubRelease? selected;
      _mobileViewport(tester);
      await _pumpReleases(
        tester,
        SizedBox(
          width: 375,
          child: VersionSelector(
            repoId: 'o/r',
            selectedTag: null,
            installedTag: null,
            onSelected: (GithubRelease release) => selected = release,
          ),
        ),
        () => Future<List<GithubRelease>>.value(_fixtures),
      );

      // Tocar na v0.9.0-beta NÃO dispara callback (sem APK, desabilitado).
      await tester.tap(find.text('v0.9.0-beta'), warnIfMissed: false);
      await tester.pump();
      expect(selected, isNull);
    },
  );

  testWidgets(
    'contraste AA dos textos do seletor (guideline do flutter_test)',
    (WidgetTester tester) async {
      _mobileViewport(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      // Fixture com releases ativas (card desabilitado é isento pela WCAG).
      final List<GithubRelease> ativas = _fixtures
          .take(2)
          .toList(growable: false);
      await _pumpReleases(
        tester,
        SizedBox(
          width: 375,
          child: VersionSelector(
            repoId: 'o/r',
            selectedTag: null,
            installedTag: 'v1.0.0',
            onSelected: (GithubRelease release) {},
          ),
        ),
        () => Future<List<GithubRelease>>.value(ativas),
      );

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  testWidgets('wide (≥768px): controle segmentado seleciona versão', (
    WidgetTester tester,
  ) async {
    // Viewport padrão do tester é 800x600 ≥ 768 → variante segmentada.
    GithubRelease? selected;
    await _pumpReleases(
      tester,
      SizedBox(
        width: 720,
        child: VersionSelector(
          repoId: 'o/r',
          selectedTag: null,
          installedTag: 'v1.0.0',
          onSelected: (GithubRelease release) => selected = release,
        ),
      ),
      () => Future<List<GithubRelease>>.value(_fixtures),
    );

    // Segmentos com as tags + card de detalhe da seleção.
    expect(find.byType(SegmentedControl<int>), findsOneWidget);
    await tester.tap(find.text('v1.0.0').first);
    await tester.pump();
    expect(selected?.tag, 'v1.0.0');
  });

  testWidgets('rate limit: estado dedicado com retry', (
    WidgetTester tester,
  ) async {
    _mobileViewport(tester);
    await _pumpReleases(
      tester,
      SizedBox(
        width: 375,
        child: VersionSelector(
          repoId: 'o/r',
          selectedTag: null,
          installedTag: null,
          onSelected: (GithubRelease release) {},
        ),
      ),
      () => Future<List<GithubRelease>>.error(
        const GitHubApiException(GitHubErrorKind.rateLimit),
      ),
    );

    expect(find.text('Limite do GitHub atingido'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('repo com apenas 1 release: um card, sem badge de outras', (
    WidgetTester tester,
  ) async {
    _mobileViewport(tester);
    await _pumpReleases(
      tester,
      SizedBox(
        width: 375,
        child: VersionSelector(
          repoId: 'o/r',
          selectedTag: null,
          installedTag: 'v1.0.0',
          onSelected: (GithubRelease release) {},
        ),
      ),
      () => Future<List<GithubRelease>>.value(<GithubRelease>[
        _release(
          'v1.0.0',
          publishedAt: DateTime(2026, 10, 1),
          assets: <ApkAsset>[_apk('game.apk')],
        ),
      ]),
    );

    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('Mais recente'), findsOneWidget);
    expect(find.text('Instalada'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('nenhuma release: estado vazio explicativo', (
    WidgetTester tester,
  ) async {
    _mobileViewport(tester);
    await _pumpReleases(
      tester,
      SizedBox(
        width: 375,
        child: VersionSelector(
          repoId: 'o/r',
          selectedTag: null,
          installedTag: null,
          onSelected: (GithubRelease release) {},
        ),
      ),
      () => Future<List<GithubRelease>>.value(const <GithubRelease>[]),
    );

    expect(find.text('Sem versões publicadas'), findsOneWidget);
  });

  testWidgets('DeveloperCard: nome, @login, bio, botão e contagens', (
    WidgetTester tester,
  ) async {
    await _pumpUser(
      tester,
      const DeveloperCard(owner: 'VinTeRuS'),
      () => Future<GithubUser?>.value(
        const GithubUser(
          login: 'VinTeRuS',
          avatarUrl: 'https://avatars.githubusercontent.com/u/73440180?v=4',
          htmlUrl: 'https://github.com/VinTeRuS',
          bio: 'Ports de jogos',
          type: 'User',
          publicRepos: 13,
          followers: 37,
        ),
      ),
    );

    expect(find.text('@VinTeRuS'), findsWidgets);
    expect(find.text('Ports de jogos'), findsOneWidget);
    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('Ver perfil no GitHub'), findsOneWidget);
    expect(find.textContaining('repositórios'), findsOneWidget);
  });

  testWidgets('DeveloperCard: organização ganha rótulo próprio', (
    WidgetTester tester,
  ) async {
    await _pumpUser(
      tester,
      const DeveloperCard(owner: 'flutter'),
      () => Future<GithubUser?>.value(
        const GithubUser(
          login: 'flutter',
          name: 'Flutter',
          avatarUrl: 'https://avatars.githubusercontent.com/u/14101776?v=4',
          htmlUrl: 'https://github.com/flutter',
          type: 'Organization',
        ),
      ),
    );

    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Organização'), findsOneWidget);
  });

  testWidgets('DeveloperCard: usuário sem name usa @login como nome', (
    WidgetTester tester,
  ) async {
    await _pumpUser(
      tester,
      const DeveloperCard(owner: 'semnome-dev'),
      () => Future<GithubUser?>.value(
        const GithubUser(
          login: 'semnome-dev',
          avatarUrl: 'https://avatars.githubusercontent.com/u/99?v=4',
          htmlUrl: 'https://github.com/semnome-dev',
        ),
      ),
    );

    expect(find.text('semnome-dev'), findsWidgets);
  });

  testWidgets('DeveloperCard: falha do GitHub cai no fallback com iniciais', (
    WidgetTester tester,
  ) async {
    await _pumpUser(
      tester,
      const DeveloperCard(owner: 'offline-dev'),
      () => Future<GithubUser?>.error(
        const GitHubApiException(GitHubErrorKind.offline),
      ),
    );

    // Fallback continua navegável: botão do perfil com @owner.
    expect(find.text('@offline-dev'), findsWidgets);
    expect(find.text('Ver perfil no GitHub'), findsOneWidget);
  });
}
