import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/router.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/auth.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/models/collections.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/profile.dart';
import 'package:portix/shared/widgets/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Arquitetura de informação: TODA configuração existente continua acessível
// após a reorganização em categorias, navegação drill-down + voltar,
// master-detail ≥768px e deep link direto para cada categoria.
// ============================================================================

class _FakeRepository implements CatalogRepository {
  @override
  Future<UserProfile> fetchProfile() async {
    return const UserProfile(id: 'u-1', displayName: 'Ana', handle: 'ana');
  }

  @override
  Future<Collections> fetchCollections() async => Collections.empty;

  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async {
    throw const SocketException('sem rede no teste');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} não usado no teste');
}

class _FixedAccountController extends AccountController {
  _FixedAccountController();

  @override
  AccountState build() => _state;

  final AccountState _state = const AccountState();

  void set(AccountState value) => state = value;
}

class _GatedRepository implements CatalogRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<UserProfile> fetchProfile() async {
    return const UserProfile(id: 'u-1', displayName: 'Ana', handle: 'ana');
  }

  @override
  Future<Collections> fetchCollections() async => Collections.empty;

  @override
  HomeFeed? readCachedHome() => null;

  @override
  Future<HomeFeed> fetchHome() async {
    await gate.future;
    throw const SocketException('sem rede no teste');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} não usado no teste');
}

Future<ProviderContainer> _container({
  required bool signedIn,
  CatalogRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(
        repository ?? _FakeRepository(),
      ),
      accountProvider.overrideWith(_FixedAccountController.new),
    ],
  );
  (container.read(accountProvider.notifier) as _FixedAccountController).set(
    signedIn
        ? const AccountState(
            id: 'u-1',
            displayName: 'Ana',
            handle: 'ana',
            signedIn: true,
          )
        : const AccountState(),
  );
  return container;
}

Future<void> _pumpRouter(
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

  final GoRouter router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (BuildContext context, Widget? child) =>
            MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.0,
              maxScaleFactor: 2.0,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void _go(ProviderContainer container, String location) {
  container.read(routerProvider).go(location);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Sem rede real: rotas não fazem download; channel só para cache interno.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async =>
              (await Directory.systemTemp.createTemp('portix_nav_test')).path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('hub: tabela configuração → categoria', () {
    testWidgets('lista as 6 categorias com título e descrição', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Cabeçalho com perfil resumido (foto, nome, e-mail/handle).
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('@ana'), findsOneWidget);

      const List<String> categorias = <String>[
        'Conta e Perfil',
        'Aparência e Temas',
        'Notificações',
        'Idioma e Região',
        'Dados e Armazenamento',
        'Ajuda e Sobre',
      ];
      for (final String categoria in categorias) {
        expect(
          find.text(categoria),
          findsOneWidget,
          reason: 'categoria $categoria visível no hub',
        );
      }
    });

    testWidgets('todas as configurações existentes continuam presentes', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);

      // 1. Conta e Perfil: entrar/editar/sair + estatísticas.
      _go(container, '/menu/conta');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Instalados'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);

      // 2. Aparência e Temas: seletor completo.
      _go(container, '/menu/aparencia');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Tema'), findsWidgets);
      for (final String tema in <String>[
        'Sistema',
        'Claro',
        'Escuro',
        'Midnight',
        'Oceano',
        'Floresta',
      ]) {
        expect(find.text(tema), findsOneWidget, reason: 'tema $tema');
      }

      // 3. Notificações.
      _go(container, '/menu/notificacoes');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Notificações'), findsWidgets);

      // 4. Idioma e Região.
      _go(container, '/menu/idioma');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Idioma'), findsOneWidget);
      expect(find.text('Português (BR)'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // 5. Dados e Armazenamento.
      _go(container, '/menu/dados');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Recarregar catálogo'), findsOneWidget);
      expect(find.text('Limpar cache local'), findsOneWidget);

      // 6. Ajuda e Sobre: versão + legal.
      _go(container, '/menu/sobre');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('PORTIX'), findsOneWidget);
      expect(find.textContaining('v'), findsWidgets);
      expect(find.text('Termos de uso'), findsOneWidget);
      expect(find.text('Política de privacidade'), findsOneWidget);
    });
  });

  group('navegação', () {
    testWidgets('tap na categoria abre a rota; voltar retorna ao hub', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Aparência e Temas'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('Aparência e Temas'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        find.text('Sistema'),
        findsOneWidget,
        reason: 'conteúdo da categoria aberto',
      );

      // Voltar do sistema (popRoute — igual ao botão físico/navegador).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        find.text('Configurações'),
        findsOneWidget,
        reason: 'voltou ao hub',
      );
    });

    testWidgets('deep link direto para a categoria funciona', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu/aparencia');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Aparência e Temas'), findsWidgets);
      expect(find.text('Floresta'), findsOneWidget);
    });
  });

  group('busca nas configurações', () {
    testWidgets('filtra categorias por título e mostra estado vazio', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'tema');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Aparência e Temas'), findsOneWidget);
      expect(find.text('Dados e Armazenamento'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Nenhuma configuração encontrada'), findsOneWidget);

      // Limpar busca restaura todas.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Dados e Armazenamento'), findsOneWidget);
    });
  });

  group('regressões da iteração 5 (CRÍTICO)', () {
    testWidgets(
      'header do convidado: nome via l10n e Convidado uma única vez',
      (WidgetTester tester) async {
        final ProviderContainer container = await _container(signedIn: false);
        addTearDown(container.dispose);
        await _pumpRouter(tester, container);
        _go(container, '/menu');
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.text('Jogador'),
          findsOneWidget,
          reason: 'fallback do nome resolve via l10n (não pt hardcoded)',
        );
        expect(
          find.text('Convidado'),
          findsOneWidget,
          reason: 'sem duplicação de estado no header',
        );
      },
    );

    testWidgets('header mostra o @handle da identidade local', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.text('@ana'),
        findsOneWidget,
        reason: 'identidade local: o @handle aparece na linha secundária',
      );
    });

    testWidgets('busca sobrevive à troca de categoria (provider)', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'tema');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      _go(container, '/menu/conta');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.text('Aparência e Temas'),
        findsOneWidget,
        reason: 'filtro ativo após voltar ao hub',
      );
      expect(find.text('Dados e Armazenamento'), findsNothing);
      expect(
        (tester.widget(find.byType(TextField)) as TextField).controller!.text,
        'tema',
        reason: 'campo semeado do provider (não em branco)',
      );
    });

    testWidgets(
      'recarregar catálogo sem rede mostra erro (sucesso falso resolvido)',
      (WidgetTester tester) async {
        final ProviderContainer container = await _container(signedIn: true);
        addTearDown(container.dispose);
        await _pumpRouter(tester, container);
        _go(container, '/menu/dados');
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        await tester.tap(find.text('Recarregar catálogo'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.text('Não foi possível atualizar agora'),
          findsOneWidget,
          reason: 'sem "Catálogo atualizado" quando a revalidação falha',
        );
      },
    );

    testWidgets(
      'recarregar catálogo mostra spinner e trava o tap durante o refresh',
      (WidgetTester tester) async {
        final _GatedRepository repo = _GatedRepository();
        final ProviderContainer container = await _container(
          signedIn: true,
          repository: repo,
        );
        addTearDown(container.dispose);
        await _pumpRouter(tester, container);
        _go(container, '/menu/dados');
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        await tester.tap(find.text('Recarregar catálogo'));
        await tester.pump();
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason: 'feedback real durante o await (rede lenta inclusa)',
        );
        expect(
          (tester.widget(
                    find.widgetWithText(SectionTile, 'Recarregar catálogo'),
                  )
                  as SectionTile)
              .onTap,
          isNull,
          reason: 'tap desabilitado durante o refresh (sem reentrância)',
        );

        repo.gate.complete();
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(
          find.text('Não foi possível atualizar agora'),
          findsOneWidget,
          reason: 'fim honesto do refresh bloqueado',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          (tester.widget(
                    find.widgetWithText(SectionTile, 'Recarregar catálogo'),
                  )
                  as SectionTile)
              .onTap,
          isNotNull,
          reason: 'tap reabilitado após o fim do refresh',
        );
      },
    );

    testWidgets('limpar cache limpa os dados locais (cache.profile sai)', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);
      // O perfil entra no cache quando o hub renderiza (header lê o
      // profileProvider) — passa pelo hub antes da categoria de dados.
      _go(container, '/menu');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      _go(container, '/menu/dados');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Limpar cache local'), findsOneWidget);

      // O perfil do usuário está no cache local (SWR da iteração 2).
      expect(
        container.read(cacheStoreProvider).readMap('profile'),
        isNotNull,
        reason: 'pré-condição: o perfil está em cache',
      );

      await tester.tap(find.text('Limpar cache local'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        container.read(cacheStoreProvider).readMap('profile'),
        isNull,
        reason: 'a confirmação promete exatamente o que o código faz',
      );
    });

    testWidgets(
      '/menu em telas largas sem categoria mostra painel de orientação',
      (WidgetTester tester) async {
        final ProviderContainer container = await _container(signedIn: true);
        addTearDown(container.dispose);
        await _pumpRouter(tester, container, size: const Size(1200, 800));
        _go(container, '/menu');
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.text('Selecione uma categoria para ver as opções'),
          findsOneWidget,
        );
        expect(find.text('Conta e Perfil'), findsOneWidget);
      },
    );
  });

  group('responsividade', () {
    testWidgets(
      '768px+: master-detail (lista à esquerda, conteúdo à direita)',
      (WidgetTester tester) async {
        final ProviderContainer container = await _container(signedIn: true);
        addTearDown(container.dispose);
        await _pumpRouter(tester, container, size: const Size(1200, 800));
        _go(container, '/menu/conta');
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        // Lista de categorias visível JUNTO com o conteúdo da categoria.
        expect(find.text('Dados e Armazenamento'), findsOneWidget);
        expect(find.text('Editar perfil'), findsOneWidget);
      },
    );

    testWidgets('375px: drill-down mostra só o conteúdo da categoria', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(tester, container, size: const Size(375, 720));
      _go(container, '/menu/conta');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Editar perfil'), findsOneWidget);
      // Outras categorias não estão na tela (drill-down).
      expect(find.text('Ajuda e Sobre'), findsNothing);
    });

    testWidgets('categorias sobrevivem a texto 2.0 sem overflow', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(signedIn: true);
      addTearDown(container.dispose);
      await _pumpRouter(
        tester,
        container,
        size: const Size(360, 640),
        textScale: 2.0,
      );
      _go(container, '/menu/aparencia');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Tema'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
