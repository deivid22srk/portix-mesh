import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/features/device_specs/data/device_specs_models.dart';
import 'package:portix/features/device_specs/data/device_specs_repository.dart';
import 'package:portix/features/device_specs/device_specs_providers.dart';
import 'package:portix/features/device_specs/device_specs_screen.dart';
import 'package:portix/features/device_specs/device_specs_search_screen.dart';
import 'package:portix/models/compat_report.dart';
import 'package:portix/shared/widgets/feedback_report_row.dart';

import 'device_specs_screen_test.dart' show FakeSpecsRepo;

void main() {
  const DeviceSpecsDetail detail = DeviceSpecsDetail(
    slug: 'test_redmi_note_10-2',
    brand: 'Xiaomi',
    name: 'Redmi Note 10',
    groups: <DeviceSpecGroup>[
      DeviceSpecGroup(
        title: 'Platform',
        rows: <DeviceSpecRow>[
          DeviceSpecRow(key: 'Chipset', values: <String>['Snapdragon 678']),
        ],
      ),
    ],
  );

  const CompatReport report = CompatReport(
    author: 'Maria Silva',
    authorHandle: 'maria',
    status: 'good',
    rating: 4,
    fps: 60,
    brand: 'Xiaomi',
    model: 'Redmi Note 10',
    soc: 'Snapdragon 678',
    gpu: 'Adreno 612',
    ramGb: 4,
    body: 'Roda liso em configurações altas.',
  );

  Widget app({required DeviceSpecsRepository repo}) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: SafeArea(child: FeedbackReportRow(report: report)),
          ),
        ),
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

  Future<void> pumpSteps(WidgetTester tester, Widget child) async {
    // Tela alta: a ficha técnica é um ListView lazy (ver screen_test).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(child);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'toque no nome do aparelho abre a busca de fichas técnicas com o termo',
    (WidgetTester tester) async {
      await pumpSteps(
        tester,
        app(
          repo: FakeSpecsRepo(
            results: const <DeviceSpecsSummary>[
              DeviceSpecsSummary(
                name: 'Redmi Note 10',
                slug: 'test_redmi_note_10-2',
                brand: 'Xiaomi',
              ),
              DeviceSpecsSummary(
                name: 'Redmi Note 10 Pro',
                slug: 'test_redmi_note_10_pro-9',
                brand: 'Xiaomi',
              ),
            ],
          ),
        ),
      );

      // Nome do aparelho destacado como link (com a cor de destaque do tema).
      expect(find.text('Xiaomi Redmi Note 10'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.text('Xiaomi Redmi Note 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // NÃO abriu o sheet do relato: abriu a busca de especificações.
      expect(find.byType(DeviceSpecsSearchScreen), findsOneWidget);
      expect(find.text('Especificações do aparelho'), findsOneWidget);
      // Termo preenchido e dois resultados listados (nada de auto-navegação).
      expect(find.text('Redmi Note 10'), findsOneWidget);
      expect(find.text('Redmi Note 10 Pro'), findsOneWidget);
    },
  );

  testWidgets(
    'resultado único da busca leva direto à ficha técnica do relato',
    (WidgetTester tester) async {
      await pumpSteps(
        tester,
        app(
          repo: FakeSpecsRepo(
            results: const <DeviceSpecsSummary>[
              DeviceSpecsSummary(
                name: 'Redmi Note 10',
                slug: 'test_redmi_note_10-2',
                brand: 'Xiaomi',
              ),
            ],
            detail: detail,
          ),
        ),
      );

      await tester.tap(find.text('Xiaomi Redmi Note 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // O auto-navegate empurra a ficha num post-frame: dois frames extras
      // para a rota abrir e os dados chegarem.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(DeviceSpecsScreen), findsOneWidget);
      expect(find.text('Redmi Note 10'), findsWidgets);
      expect(find.text('Snapdragon 678'), findsOneWidget);
    },
  );

  testWidgets('sheet do relato oferece "Ver ficha técnica" e abre a busca', (
    WidgetTester tester,
  ) async {
    await pumpSteps(
      tester,
      app(
        repo: FakeSpecsRepo(
          results: const <DeviceSpecsSummary>[
            DeviceSpecsSummary(
              name: 'Redmi Note 10',
              slug: 'test_redmi_note_10-2',
              brand: 'Xiaomi',
            ),
            DeviceSpecsSummary(
              name: 'Redmi Note 10 Pro',
              slug: 'test_redmi_note_10_pro-9',
              brand: 'Xiaomi',
            ),
          ],
          detail: detail,
        ),
      ),
    );

    // Abre o detalhe completo do relato (toque no corpo do relato).
    await tester.tap(find.text('Roda liso em configurações altas.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ver ficha técnica'), findsOneWidget);

    await tester.tap(find.text('Ver ficha técnica'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DeviceSpecsSearchScreen), findsOneWidget);
    expect(find.text('Xiaomi Redmi Note 10'), findsWidgets);
  });

  testWidgets('relato sem aparelho informado não abre a ficha técnica', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: SafeArea(
              child: FeedbackReportRow(
                report: CompatReport(author: 'João', status: 'good'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/specs/search',
          builder: (BuildContext context, GoRouterState state) =>
              const DeviceSpecsSearchScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceSpecsRepositoryProvider.overrideWithValue(FakeSpecsRepo()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Reserva localizada e sem chevron: não há ficha técnica para abrir.
    expect(find.text('Aparelho'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.text('Aparelho'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DeviceSpecsSearchScreen), findsNothing);
  });
}
