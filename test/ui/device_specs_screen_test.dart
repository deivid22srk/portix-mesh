import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/env.dart';
import 'package:portix/features/device_specs/data/device_specs_models.dart';
import 'package:portix/features/device_specs/data/device_specs_repository.dart';
import 'package:portix/features/device_specs/device_specs_providers.dart';
import 'package:portix/features/device_specs/device_specs_screen.dart';
import 'package:portix/features/device_specs/device_specs_search_screen.dart';
import 'package:portix/shared/widgets/states.dart';

/// Repositório falso: resultados de busca e ficha fixos, sem rede.
class FakeSpecsRepo implements DeviceSpecsRepository {
  FakeSpecsRepo({this.results = const <DeviceSpecsSummary>[], this.detail});

  final List<DeviceSpecsSummary> results;
  final DeviceSpecsDetail? detail;

  @override
  Future<List<DeviceSpecsBrand>> brands() async => const <DeviceSpecsBrand>[];

  @override
  Future<List<DeviceSpecsSummary>> search(
    String query, {
    String? brandHint,
  }) async => results;

  @override
  Future<DeviceSpecsDetail> device(String slug) async {
    final DeviceSpecsDetail? fixed = detail;
    if (fixed == null) {
      throw const AppFailure(FailureKind.notFound);
    }
    return fixed;
  }
}

void main() {
  const DeviceSpecsDetail detail = DeviceSpecsDetail(
    slug: 'test_poco_x6_pro-1',
    brand: 'Xiaomi',
    name: 'Poco X6 Pro',
    thumbnail: 'https://img/poco.jpg',
    images: <String>['https://img/1.jpg', 'https://img/2.jpg'],
    releaseInfo: 'Released 2024, January 10',
    dimensionsInfo: '186g, 8.3mm thickness',
    osInfo: 'Android 14, HyperOS',
    storageInfo: '256GB/512GB storage',
    groups: <DeviceSpecGroup>[
      DeviceSpecGroup(
        title: 'Display',
        rows: <DeviceSpecRow>[
          DeviceSpecRow(key: 'Type', values: <String>['AMOLED 120Hz']),
          DeviceSpecRow(key: 'Size', values: <String>['6.67 inches']),
        ],
      ),
      DeviceSpecGroup(
        title: 'Platform',
        rows: <DeviceSpecRow>[
          DeviceSpecRow(
            key: 'Chipset',
            values: <String>['Dimensity 8300 Ultra'],
          ),
        ],
      ),
      DeviceSpecGroup(
        title: 'Battery',
        rows: <DeviceSpecRow>[
          DeviceSpecRow(key: 'Type', values: <String>['6000 mAh']),
        ],
      ),
    ],
  );

  const List<DeviceSpecsSummary> twoResults = <DeviceSpecsSummary>[
    DeviceSpecsSummary(
      name: 'Poco X6 Pro',
      slug: 'test_poco_x6_pro-1',
      imageUrl: 'https://img/poco.jpg',
      brand: 'Xiaomi',
    ),
    DeviceSpecsSummary(
      name: 'Poco X6',
      slug: 'test_poco_x6-2',
      imageUrl: null,
      brand: 'Xiaomi',
    ),
  ];

  Widget app({
    required Widget Function(BuildContext, GoRouterState) home,
    required DeviceSpecsRepository repo,
  }) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: home),
        GoRoute(
          path: '/specs/search',
          builder: (BuildContext context, GoRouterState state) =>
              DeviceSpecsSearchScreen(
                initialQuery: state.uri.queryParameters['q'] ?? '',
              ),
        ),
        GoRoute(
          path: '/specs/:slug',
          builder: (BuildContext context, GoRouterState state) =>
              DeviceSpecsScreen(slug: state.pathParameters['slug'] ?? ''),
        ),
      ],
    );
    return ProviderScope(
      overrides: [deviceSpecsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    // Tela alta: o ListView da ficha é lazy — com pouca altura as seções
    // abaixo da dobra nem são construídas e as asserções falham.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(child);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('ficha técnica mostra visão geral, galeria e grupos traduzidos', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      app(
        home: (BuildContext context, GoRouterState state) =>
            DeviceSpecsScreen(slug: 'test_poco_x6_pro-1'),
        repo: FakeSpecsRepo(detail: detail),
      ),
    );

    expect(find.text('Poco X6 Pro'), findsWidgets);
    expect(find.text('VISÃO GERAL'), findsOneWidget);
    expect(find.text('Released 2024, January 10'), findsOneWidget);
    expect(find.text('186g, 8.3mm thickness'), findsOneWidget);
    expect(find.text('IMAGENS'), findsOneWidget);
    expect(find.text('TELA'), findsOneWidget);
    expect(find.text('PLATAFORMA'), findsOneWidget);
    expect(find.text('BATERIA'), findsOneWidget);
    expect(find.text('Dimensity 8300 Ultra'), findsOneWidget);
    expect(find.text('Dados da ficha técnica: GSMArena'), findsOneWidget);
    // Thumbnail do herói + duas imagens da galeria.
    expect(find.byType(CachedNetworkImage), findsNWidgets(3));
  });

  testWidgets('erro da API mostra estado de erro com botão de tentar de novo', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      app(
        home: (BuildContext context, GoRouterState state) =>
            DeviceSpecsScreen(slug: 'inexistente'),
        repo: FakeSpecsRepo(),
      ),
    );

    expect(find.byType(ErrorStateView), findsOneWidget);
  });

  testWidgets('busca com dois resultados lista e abre a ficha ao tocar', (
    WidgetTester tester,
  ) async {
    final DeviceSpecsRepository repo = FakeSpecsRepo(
      results: twoResults,
      detail: detail,
    );
    await pump(
      tester,
      app(
        home: (BuildContext context, GoRouterState state) =>
            const DeviceSpecsSearchScreen(initialQuery: 'poco x6'),
        repo: repo,
      ),
    );

    expect(find.text('Poco X6 Pro'), findsOneWidget);
    expect(find.text('Poco X6'), findsOneWidget);

    await tester.tap(find.text('Poco X6 Pro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('VISÃO GERAL'), findsOneWidget);
    expect(find.text('Dimensity 8300 Ultra'), findsOneWidget);
  });

  testWidgets(
    'busca com resultado único abre a ficha direto (fluxo do relato)',
    (WidgetTester tester) async {
      await pump(
        tester,
        app(
          home: (BuildContext context, GoRouterState state) =>
              const DeviceSpecsSearchScreen(initialQuery: 'Xiaomi Poco X6 Pro'),
          repo: FakeSpecsRepo(
            results: <DeviceSpecsSummary>[twoResults.first],
            detail: detail,
          ),
        ),
      );
      // O auto-navegate empurra a ficha num post-frame: dois frames extras
      // para a rota abrir e os dados chegarem.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Sem toque: o resultado único já levou à ficha técnica.
      expect(find.text('VISÃO GERAL'), findsOneWidget);
      expect(find.text('Dimensity 8300 Ultra'), findsOneWidget);
    },
  );

  testWidgets('busca vazia mostra estado vazio localizado', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      app(
        home: (BuildContext context, GoRouterState state) =>
            const DeviceSpecsSearchScreen(initialQuery: 'nada'),
        repo: FakeSpecsRepo(results: const <DeviceSpecsSummary>[]),
      ),
    );

    expect(find.text('Nada encontrado'), findsOneWidget);
    expect(find.textContaining('fichas técnicas'), findsOneWidget);
  });
}
