import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/auth.dart';
import 'package:portix/core/env.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/features/home/home_page.dart';
import 'package:portix/features/search/search_controller.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/home_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_feed_repository.dart';

// Estados completos da Início: erro/offline, rate limit, vazio e feed carregado
// — cada um com a ação "Tentar novamente" quando faz sentido.

class _GuestAccountController extends AccountController {
  @override
  AccountState build() => const AccountState();
}

Future<ProviderContainer> _container(FakeFeedRepository repository) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(repository),
      accountProvider.overrideWith(_GuestAccountController.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpHome(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(411, 891),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  // 1º frame: loading; seguintes: resolução do future do feed.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('offline: mostra estado sem conexão com retry', (
    WidgetTester tester,
  ) async {
    final FakeFeedRepository repository = FakeFeedRepository(
      onFetch: (_) async => throw const AppFailure(FailureKind.network),
    );
    final ProviderContainer container = await _container(repository);
    await _pumpHome(tester, container);

    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      repository.seeds.length,
      greaterThanOrEqualTo(2),
      reason: 'tentar novamente refaz a busca do feed',
    );
  });

  testWidgets('rate limit: mostra estado próprio com retry', (
    WidgetTester tester,
  ) async {
    final FakeFeedRepository repository = FakeFeedRepository(
      onFetch: (_) async => throw const AppFailure(FailureKind.rateLimited),
    );
    final ProviderContainer container = await _container(repository);
    await _pumpHome(tester, container);

    expect(find.text('Muitas requisições'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('vazio: mostra estado vazio com retry', (
    WidgetTester tester,
  ) async {
    final FakeFeedRepository repository = FakeFeedRepository(
      onFetch: (_) async => const HomeFeed(),
    );
    final ProviderContainer container = await _container(repository);
    await _pumpHome(tester, container);

    expect(find.text('Nada por aqui ainda'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('feed carregado: renderiza as seções do payload', (
    WidgetTester tester,
  ) async {
    final FakeFeedRepository repository = FakeFeedRepository(
      onFetch: (_) async => HomeFeed(
        seed: 's',
        sections: <HomeFeedSection>[
          HomeFeedSection(
            key: 'trending',
            kind: 'row',
            items: <Game>[
              const Game(id: 'a', slug: 'a', title: 'Alfa'),
              const Game(id: 'b', slug: 'b', title: 'Beta'),
            ],
          ),
        ],
      ),
    );
    final ProviderContainer container = await _container(repository);
    await _pumpHome(tester, container);
    // Deixa a animação de entrada (RevealOnMount) evoluir sem travar.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Em alta'), findsOneWidget);
    expect(find.text('Alfa'), findsOneWidget);
  });

  testWidgets('"Ver tudo" navega para a Explorar com o filtro da seção', (
    WidgetTester tester,
  ) async {
    // Regressão: onAction recebia `() => _seeAll(...)` mas _seeAll DEVOLVIA um
    // closure — o toque rodava _seeAll e descartava o retorno, sem navegar.
    final FakeFeedRepository repository = FakeFeedRepository(
      onFetch: (_) async => HomeFeed(
        seed: 's',
        sections: <HomeFeedSection>[
          HomeFeedSection(
            key: 'trending',
            kind: 'row',
            items: <Game>[const Game(id: 'a', slug: 'a', title: 'Alfa')],
          ),
        ],
      ),
    );
    final ProviderContainer container = await _container(repository);
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: HomePage()),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');

    await tester.tap(find.text('Ver tudo'));
    await tester.pumpAndSettle();

    // Navegou para a Explorar e levou o filtro da seção (Em alta → trending).
    expect(router.routerDelegate.currentConfiguration.uri.path, '/explore');
    expect(container.read(searchControllerProvider).filters.sort, 'trending');
  });
}
