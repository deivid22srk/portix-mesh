import 'dart:ui' show Tristate;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/theme/tokens.dart';
import 'package:portix/shared/widgets/primitives.dart';

import 'ui_test_helpers.dart';

// ============================================================================
// Evidências da iteração 1: responsividade de grades (411/800/1440) e
// acessibilidade semântica (AppToggle, StarPicker, GlassCircleButton).
// ============================================================================

/// Infla um MaterialApp real com `CustomScrollView` no corpo (as grades são
/// slivers — não podem ficar dentro do SingleChildScrollView do pumpUi).
Future<void> pumpScroll(
  WidgetTester tester, {
  required Size size,
  required List<Widget> slivers,
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
      builder: (BuildContext context, Widget? inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: inner!,
      ),
      home: Scaffold(
        backgroundColor: auroraDark.bg,
        body: CustomScrollView(slivers: slivers),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('AppBreakpoints.coverColumns', () {
    test('celular 375px → 2 colunas', () {
      expect(AppBreakpoints.coverColumns(375), 2);
    });
    test('tablet 800px → 3 colunas', () {
      expect(AppBreakpoints.coverColumns(800), 3);
    });
    test('desktop 1024px → 5 colunas', () {
      expect(AppBreakpoints.coverColumns(1024), 5);
    });
    test('telas largas 1440px → 6 colunas', () {
      expect(AppBreakpoints.coverColumns(1440), 6);
    });
  });

  group('ResponsiveCoverGrid', () {
    Future<void> pumpGrid(WidgetTester tester, Size size) => pumpScroll(
      tester,
      size: size,
      slivers: <Widget>[
        ResponsiveCoverGrid(
          itemCount: 12,
          itemBuilder: (BuildContext context, int index) =>
              SizedBox.expand(key: ValueKey<int>(index)),
        ),
      ],
    );

    testWidgets('celular 411px: 2 colunas — item 2 cai para a 2ª linha', (
      WidgetTester tester,
    ) async {
      await pumpGrid(tester, const Size(411, 891));
      final Offset row0 = tester.getTopLeft(find.byKey(const ValueKey<int>(0)));
      expect(tester.getTopLeft(find.byKey(const ValueKey<int>(1))).dy, row0.dy);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(2))).dy,
        greaterThan(row0.dy),
      );
    });

    testWidgets('tablet 800px: 3 colunas — item 3 cai para a 2ª linha', (
      WidgetTester tester,
    ) async {
      await pumpGrid(tester, const Size(800, 1280));
      final Offset row0 = tester.getTopLeft(find.byKey(const ValueKey<int>(0)));
      expect(tester.getTopLeft(find.byKey(const ValueKey<int>(2))).dy, row0.dy);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(3))).dy,
        greaterThan(row0.dy),
      );
    });

    testWidgets('telas largas 1440px: 6 colunas e conteúdo centralizado', (
      WidgetTester tester,
    ) async {
      await pumpGrid(tester, const Size(1440, 900));
      final Offset row0 = tester.getTopLeft(find.byKey(const ValueKey<int>(0)));
      expect(tester.getTopLeft(find.byKey(const ValueKey<int>(5))).dy, row0.dy);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(6))).dy,
        greaterThan(row0.dy),
      );
      // Teto de 1200px: (1440-1200)/2 = 120px de margem extra + 16 padrão.
      expect(row0.dx, greaterThanOrEqualTo(120));
    });

    testWidgets('escala de texto 2.0: grade de tiles sem exceção de layout', (
      WidgetTester tester,
    ) async {
      await pumpScroll(
        tester,
        size: const Size(375, 800),
        textScale: 2.0,
        slivers: <Widget>[
          ResponsiveCoverGrid(
            mainAxisExtent: 62,
            itemCount: 4,
            itemBuilder: (BuildContext context, int index) => const SectionTile(
              icon: Icons.sports_esports_rounded,
              label: 'Port de Nintendo 64 com controles táteis',
            ),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Acessibilidade semântica', () {
    testWidgets('AppToggle: rótulo + estado toggled + alvo de 48px', (
      WidgetTester tester,
    ) async {
      bool? changed;
      await pumpUi(
        tester,
        child: AppToggle(
          value: true,
          semanticLabel: 'Notificações',
          onChanged: (bool value) => changed = value,
        ),
      );
      final SemanticsFlags flags = tester
          .getSemantics(find.bySemanticsLabel('Notificações'))
          .flagsCollection;
      expect(flags.isToggled, Tristate.isTrue);
      expect(
        tester.getSize(find.byType(AppToggle)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(AppToggle));
      expect(changed, false);
    });

    testWidgets('StarPicker: rótulo por estrela e resumo do valor', (
      WidgetTester tester,
    ) async {
      int? picked;
      await pumpUi(
        tester,
        child: StarPicker(value: 3, onChanged: (int value) => picked = value),
      );
      expect(find.bySemanticsLabel('1 de 5 estrelas'), findsOneWidget);
      expect(find.bySemanticsLabel('3 de 5 estrelas'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Avaliação: 3 de 5 estrelas'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('5 de 5 estrelas'));
      expect(picked, 5);
    });

    testWidgets('GlassCircleButton exige tooltip e o expõe via Tooltip', (
      WidgetTester tester,
    ) async {
      await pumpUi(
        tester,
        child: const GlassCircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Voltar',
        ),
      );
      final Tooltip tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Voltar');
    });
  });
}
