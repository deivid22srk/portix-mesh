import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/theme/chrome.dart';
import 'package:portix/core/theme/tokens.dart';
import 'package:portix/features/shell/tab_scroll_registry.dart';
import 'package:portix/shared/widgets/app_header.dart';
import 'package:portix/shared/widgets/app_nav.dart';

// ============================================================================
// Navegação e cabeçalho — contratos que o CRÍTICO cobra:
//   • forma por largura (bottom <768, rail 768–1199, sidebar ≥1200);
//   • ícone preenchido + estado `selected` no destino ativo;
//   • alvo de toque ≥44dp (WCAG 2.2 AA) e rótulo acessível sempre presente;
//   • badge com limite visual "99+";
//   • cabeçalho único com variantes (raiz sliver, interna, busca);
//   • re-toque na aba ativa devolve o topo (TabScrollRegistry).
// ============================================================================

const List<AppNavDestination> _destinations = <AppNavDestination>[
  AppNavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Início',
  ),
  AppNavDestination(
    icon: Icons.sports_esports_outlined,
    activeIcon: Icons.sports_esports_rounded,
    label: 'Explorar',
  ),
  AppNavDestination(
    icon: Icons.article_outlined,
    activeIcon: Icons.article_rounded,
    label: 'Notícias',
  ),
  AppNavDestination(
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    label: 'Hub',
    badgeCount: 3,
  ),
  AppNavDestination(
    icon: Icons.menu_rounded,
    activeIcon: Icons.menu_rounded,
    label: 'Menu',
  ),
];

/// `Semantics` cujo rótulo é [label] — o contrato declarado pelo destino.
Finder _semanticsWithLabel(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

/// Quantos destinos se declaram selecionados (deve ser exatamente 1).
Finder get _selectedSemantics => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.selected == true,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(411, 891),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (BuildContext context, Widget? inner) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: inner!,
        );
      },
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('AppNav.modeFor', () {
    test('<768 usa barra inferior', () {
      expect(AppNav.modeFor(375), AppNavMode.bottom);
      expect(AppNav.modeFor(767.9), AppNavMode.bottom);
    });

    test('768–1199 usa rail', () {
      expect(AppNav.modeFor(768), AppNavMode.rail);
      expect(AppNav.modeFor(1199), AppNavMode.rail);
    });

    test('≥1200 usa sidebar', () {
      expect(AppNav.modeFor(1200), AppNavMode.sidebar);
      expect(AppNav.modeFor(1440), AppNavMode.sidebar);
    });

    test('teto de 5 destinos principais', () {
      expect(AppNav.maxDestinations, 5);
      expect(_destinations.length, lessThanOrEqualTo(AppNav.maxDestinations));
    });

    test('sexto destino é barrado na construção do componente', () {
      expect(
        () => AppNavBottomBar(
          destinations: List<AppNavDestination>.filled(6, _destinations.first),
          currentIndex: 0,
          onSelect: (_) {},
        ),
        throwsAssertionError,
      );
    });

    test('nenhuma largura de telefone deixa destino abaixo de 44dp', () {
      // 320dp é o piso real (tela pequena com display grande). A conta inclui
      // o respiro interno da barra (padding + borda), que o CI já flagrou: sem
      // ele o destino caía a 43,6dp.
      for (final double width in <double>[320, 330, 340, 360, 375, 411, 600]) {
        expect(
          AppNav.bottomBarSlot(width),
          greaterThanOrEqualTo(44),
          reason: 'largura $width',
        );
      }
      expect(AppNav.edgeInset(320), AppSpacing.sm);
      expect(AppNav.edgeInset(AppBreakpoints.narrow), AppSpacing.screen);
    });
  });

  group('AppNavBottomBar (telefone)', () {
    testWidgets('mostra os 5 rótulos sempre visíveis', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );

      for (final AppNavDestination destination in _destinations) {
        expect(find.text(destination.label), findsOneWidget);
      }
    });

    testWidgets('destino ativo usa ícone preenchido e estado selecionado', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: _destinations,
            currentIndex: 1,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.sports_esports_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      // Exatamente um destino se declara selecionado, e o rótulo acessível do
      // ativo é 'Explorar' (o leitor de tela anuncia a seleção).
      expect(_selectedSemantics, findsOneWidget);
      final Semantics active = tester.widget<Semantics>(_selectedSemantics);
      expect(active.properties.label, 'Explorar');
    });

    testWidgets('tocar aciona o índice do destino', (
      WidgetTester tester,
    ) async {
      int? selected;
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (int index) => selected = index,
          ),
        ),
      );

      // Re-toque na aba ativa também chega à casca (é ela quem decide voltar
      // ao topo/raiz), então o item ativo nunca fica "morto".
      await tester.tap(find.text('Início'));
      await tester.pump();
      expect(selected, 0);

      // 'Hub' carrega badge, então o rótulo acessível tem o contador — o
      // alvo do toque é o texto visível.
      await tester.tap(find.text('Hub'));
      await tester.pump();
      expect(selected, 3);
    });

    testWidgets('badge mostra contador e satura em 99+', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: <AppNavDestination>[
              const AppNavDestination(
                icon: Icons.layers_outlined,
                activeIcon: Icons.layers_rounded,
                label: 'Hub',
                badgeCount: 120,
              ),
            ],
            currentIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
      // O contador vai no rótulo acessível, não só no pixel.
      expect(_semanticsWithLabel('Hub, 120 em andamento'), findsOneWidget);
    });

    testWidgets('alvo de toque de cada destino tem ao menos 44dp', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );

      final Finder items = find.byType(AppNavItem);
      expect(items, findsNWidgets(_destinations.length));
      for (int index = 0; index < _destinations.length; index += 1) {
        final Size size = tester.getSize(items.at(index));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('320dp: margem encolhe e o alvo continua em 44dp', (
      WidgetTester tester,
    ) async {
      const double width = 320;
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          // Mesma composição da casca: margem adaptativa + barra + busca.
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppNav.edgeInset(width)),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AppNavBottomBar(
                    destinations: _destinations,
                    currentIndex: 0,
                    onSelect: (_) {},
                  ),
                ),
                SizedBox(width: AppNav.barActionGap(width)),
                const SizedBox(
                  width: AppSpacing.searchFab,
                  height: AppSpacing.searchFab,
                ),
              ],
            ),
          ),
        ),
        size: const Size(width, 720),
      );

      expect(tester.takeException(), isNull);
      final Finder items = find.byType(AppNavItem);
      expect(items, findsNWidgets(_destinations.length));
      for (int index = 0; index < _destinations.length; index += 1) {
        expect(
          tester.getSize(items.at(index)).width,
          greaterThanOrEqualTo(44),
          reason: 'destino $index',
        );
      }
    });

    testWidgets('fonte do sistema 2.0 não estoura a barra', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBottomBar(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (_) {},
          ),
        ),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      // A barra cresce para caber o rótulo ampliado em vez de cortá-lo.
      expect(
        tester.getSize(find.byType(AppNavBottomBar)).height,
        greaterThan(AppSpacing.navBarHeight),
      );
    });
  });

  group('AppNavRail / AppNavSidebar', () {
    testWidgets('rail mostra rótulos e aciona o índice tocado', (
      WidgetTester tester,
    ) async {
      int? selected;
      await _pump(
        tester,
        SizedBox(
          height: 800,
          child: AppNavRail(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (int index) => selected = index,
            onSearch: () {},
            searchLabel: 'Buscar',
          ),
        ),
      );

      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Buscar'), findsOneWidget);

      await tester.tap(find.text('Notícias'));
      await tester.pump();
      expect(selected, 2);
    });

    testWidgets('busca é ação, não aba: fora do grupo mutuamente exclusivo', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 800,
          child: AppNavRail(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (_) {},
            onSearch: () {},
            searchLabel: 'Buscar',
          ),
        ),
      );

      final Semantics search = tester.widget<Semantics>(
        _semanticsWithLabel('Buscar'),
      );
      // Não anuncia "não selecionado": busca não é um destino de aba.
      expect(search.properties.selected, isNull);
      expect(search.properties.inMutuallyExclusiveGroup, isNot(true));
      expect(search.properties.button, isTrue);

      // Os destinos, sim, seguem no grupo de abas — com um único selecionado.
      expect(_selectedSemantics, findsOneWidget);
    });

    testWidgets('sidebar recolhe mantendo o rótulo acessível', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 800,
          child: AppNavSidebar(
            destinations: _destinations,
            currentIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('Início'), findsOneWidget);

      // Recolhe pelo botão com tooltip localizado.
      await tester.tap(find.byTooltip('Recolher navegação'));
      await tester.pumpAndSettle();

      // O rótulo some do visual, mas continua disponível para o leitor de tela
      // e para o mouse (tooltip).
      expect(find.text('Início'), findsNothing);
      expect(_semanticsWithLabel('Início'), findsOneWidget);
      expect(find.byTooltip('Início'), findsOneWidget);
    });
  });

  group('AppHeader', () {
    testWidgets('raiz: título, subtítulo e ação permanecem visíveis ao rolar', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        CustomScrollView(
          slivers: <Widget>[
            AppHeaderSliver(
              title: 'Início',
              subtitle: 'Seus consoles. No seu bolso.',
              actions: <AppHeaderAction>[
                AppHeaderAction(
                  icon: Icons.search_rounded,
                  tooltip: 'Buscar',
                  onTap: () {},
                ),
              ],
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) =>
                    const SizedBox(height: 120),
                childCount: 20,
              ),
            ),
          ],
        ),
      );

      expect(find.text('Seus consoles. No seu bolso.'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Pinned: o cabeçalho encolhe para a faixa compacta e as ações seguem
      // alcançáveis (nunca somem com o scroll).
      final double actionTop = tester
          .getTopLeft(find.byIcon(Icons.search_rounded))
          .dy;
      expect(actionTop, lessThan(AppHeaderMetrics.compact));
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('interna: voltar + título + subtítulo + ação', (
      WidgetTester tester,
    ) async {
      bool back = false;
      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: AppHeaderBar(
            title: 'Relatos da comunidade',
            subtitle: 'Super Mario 64',
            showBack: true,
            onBack: () => back = true,
            actions: <AppHeaderAction>[
              AppHeaderAction(
                icon: Icons.share_rounded,
                tooltip: 'Compartilhar',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('Relatos da comunidade'), findsOneWidget);
      expect(find.text('Super Mario 64'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump();
      expect(back, isTrue);
    });

    testWidgets('busca: voltar + campo inline + ação', (
      WidgetTester tester,
    ) async {
      bool filtered = false;
      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: AppHeaderSearchBar(
            onBack: () {},
            field: const TextField(
              decoration: InputDecoration(hintText: 'Buscar jogos'),
            ),
            actions: <AppHeaderAction>[
              AppHeaderAction(
                icon: Icons.tune_rounded,
                tooltip: 'Filtros',
                onTap: () => filtered = true,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pump();
      expect(filtered, isTrue);
    });

    testWidgets('ações: no máximo 2 visíveis e o resto no menu', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: AppHeaderBar(
            title: 'Notícias',
            actions: <AppHeaderAction>[
              AppHeaderAction(
                icon: Icons.share_rounded,
                tooltip: 'Compartilhar',
                onTap: () {},
              ),
              AppHeaderAction(
                icon: Icons.bookmark_rounded,
                tooltip: 'Salvar',
                onTap: () {},
              ),
              AppHeaderAction(
                icon: Icons.download_rounded,
                tooltip: 'Baixar',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('título longo trunca em vez de estourar a faixa', (
      WidgetTester tester,
    ) async {
      // Montado sem literal gigante: 3.14.0 e 3.14.1 quebram uma string
      // longa em colunas diferentes (o portão de formato roda no CI).
      final String longTitle = <String>[
        for (int index = 0; index < 6; index += 1) 'Título muito longo ',
      ].join();

      await _pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: AppHeaderBar(title: longTitle),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppHeaderBar)).height,
        lessThanOrEqualTo(AppSpacing.xxxl * 3),
      );
    });
  });

  group('Chrome e estado por aba', () {
    testWidgets('a casca decide o inset do fim do scroll', (
      WidgetTester tester,
    ) async {
      late double padding;
      await _pump(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppChromeScope(
              navMode: AppNavMode.rail,
              bottomPadding: 96,
              child: Builder(
                builder: (BuildContext context) {
                  padding = context.bottomChromePadding;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      );

      expect(padding, 96);
    });

    test('um controlador estável por aba (estado preservado)', () {
      final TabScrollRegistry registry = TabScrollRegistry();
      addTearDown(registry.dispose);

      expect(
        identical(
          registry.controllerFor(AppTab.home),
          registry.controllerFor(AppTab.home),
        ),
        isTrue,
      );
      expect(
        identical(
          registry.controllerFor(AppTab.home),
          registry.controllerFor(AppTab.news),
        ),
        isFalse,
      );
    });

    testWidgets('re-toque na aba ativa volta ao topo', (
      WidgetTester tester,
    ) async {
      final TabScrollRegistry registry = TabScrollRegistry();
      addTearDown(registry.dispose);
      final ScrollController controller = registry.controllerFor(AppTab.home);

      await _pump(
        tester,
        ListView.builder(
          controller: controller,
          itemBuilder: (BuildContext context, int index) =>
              SizedBox(height: 100, child: Text('item $index')),
          itemCount: 40,
        ),
      );

      controller.jumpTo(600);
      await tester.pump();
      expect(controller.offset, 600);

      registry.toTop(AppTab.home);
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });
  });
}
