import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/app/app.dart';
import 'package:portix/app/settings.dart';
import 'package:portix/app/theme.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/core/theme/tokens.dart';
import 'package:portix/core/theme/themes.dart';
import 'package:portix/shared/widgets/theme_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Sistema de temas: persistência, aplicação no primeiro frame (sem flash) e
// troca instantânea pelo seletor.
// ============================================================================

/// MaterialApp que resolve o tema pelos settings — mesmo caminho do PortixApp.
class _ThemeHost extends ConsumerWidget {
  const _ThemeHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String themeId = ref.watch(
      settingsProvider.select((AppSettings s) => s.themeId),
    );
    final AppThemePair pair = appThemePairFor(themeId);
    return MaterialApp(
      theme: AppTheme.build(pair.light),
      darkTheme: AppTheme.build(pair.dark),
      themeMode: themeModeFor(themeId),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Scaffold(body: ThemeSelector()),
    );
  }
}

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('persistência do tema', () {
    test(
      'setThemeId grava no SharedPreferences e sobrevive ao reinício',
      () async {
        final ProviderContainer container = await _container();
        addTearDown(container.dispose);

        expect(container.read(settingsProvider).themeId, kThemeDark);
        container.read(settingsProvider.notifier).setThemeId(kThemeOcean);

        final SharedPreferences prefs = container.read(
          sharedPreferencesProvider,
        );
        expect(prefs.getString('settings.themeId'), kThemeOcean);

        // Reinício: o armazenamento persiste e um novo boot lê o valor salvo.
        final ProviderContainer restarted = await _container(
          prefs: <String, Object>{
            'settings.themeId': prefs.getString('settings.themeId')!,
          },
        );
        addTearDown(restarted.dispose);
        expect(restarted.read(settingsProvider).themeId, kThemeOcean);
      },
    );

    test('tema Vice (GTA VI) persiste e sobrevive ao reinício', () async {
      final ProviderContainer container = await _container();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setThemeId(kThemeVice);

      final SharedPreferences prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings.themeId'), kThemeVice);

      final ProviderContainer restarted = await _container(
        prefs: <String, Object>{'settings.themeId': kThemeVice},
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(settingsProvider).themeId, kThemeVice);
      expect(appThemePairFor(kThemeVice).dark, vice);
    });

    test('id inválido cai no tema padrão (escuro Aurora)', () async {
      final ProviderContainer container = await _container(
        prefs: <String, Object>{'settings.themeId': 'hack'},
      );
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).themeId, kThemeDark);
      expect(appThemePairFor('hack').dark, auroraDark);
    });
  });

  group('aplicação sem flash', () {
    testWidgets('primeiro frame já usa a paleta persistida', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container(
        prefs: <String, Object>{'settings.themeId': kThemeOcean},
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _ThemeHost(),
        ),
      );
      await tester.pump();

      final BuildContext ctx = tester.element(find.byType(Scaffold));
      final AppColorsTheme colors = Theme.of(ctx).extension<AppColorsTheme>()!;
      expect(colors.bg, oceano.bg);
      expect(Theme.of(ctx).scaffoldBackgroundColor, oceano.bg);
    });
  });

  group('seletor de temas', () {
    testWidgets('toque em Oceano troca o ThemeData imediatamente', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _ThemeHost(),
        ),
      );
      await tester.pump();

      final BuildContext ctx = tester.element(find.byType(Scaffold));
      expect(Theme.of(ctx).extension<AppColorsTheme>()!.bg, auroraDark.bg);

      await tester.tap(find.text('Oceano'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).themeId, kThemeOcean);
      final BuildContext after = tester.element(find.byType(Scaffold));
      expect(Theme.of(after).extension<AppColorsTheme>()!.bg, oceano.bg);
    });

    testWidgets('toque em Vice troca o ThemeData imediatamente', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _ThemeHost(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Vice'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).themeId, kThemeVice);
      final BuildContext after = tester.element(find.byType(Scaffold));
      expect(Theme.of(after).extension<AppColorsTheme>()!.bg, vice.bg);
    });

    testWidgets(
      'card selecionado expõe Semantics selected e todos os temas têm botão',
      (WidgetTester tester) async {
        final ProviderContainer container = await _container();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _ThemeHost(),
          ),
        );
        await tester.pumpAndSettle();

        // 9 opções: Sistema, Claro, Escuro, Midnight, Oceano, Floresta,
        // Vice, Cítrico e Dourado.
        final List<String> names = <String>[
          'Sistema',
          'Claro',
          'Escuro',
          'Midnight',
          'Oceano',
          'Floresta',
          'Vice',
          'Cítrico',
          'Dourado',
        ];
        for (final String name in names) {
          expect(find.text(name), findsOneWidget, reason: 'tema $name visível');
        }
        // Botões semânticos com estado selecionado.
        final Finder options = find.ancestor(
          of: find.text('Escuro'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.selected != null,
          ),
        );
        expect(options, findsWidgets);
      },
    );
  });

  // ========================================================================
  // App REAL (PortixApp): modo Sistema resolve o brilho do SO no 1º frame e
  // reage à troca de brilho; o estilo das barras do sistema é declarativo
  // (AnnotatedRegion) e condizente com a paleta resolvida.
  // ========================================================================
  group('PortixApp: modo Sistema e SystemChrome declarativo', () {
    testWidgets(
      '1º frame usa o brilho REAL do dispositivo e a troca do SO reage',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'settings.themeId': kThemeSystem,
        });
        final SharedPreferences instance =
            await SharedPreferences.getInstance();
        // Bootstrap pendente: o app fica no splash (nenhuma rede necessária).
        final Completer<void> boot = Completer<void>();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(instance),
            meshBootstrapProvider.overrideWith((Ref ref) => boot.future),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(boot.complete);

        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(
          () => tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PortixApp(),
          ),
        );
        await tester.pump();

        // Dispositivo ESCURO + modo Sistema → paleta Aurora escuro no 1º frame.
        final BuildContext splashCtx = tester.element(
          find.byType(Scaffold).first,
        );
        expect(Theme.of(splashCtx).brightness, Brightness.dark);
        expect(
          Theme.of(splashCtx).extension<AppColorsTheme>()!.bg,
          auroraDark.bg,
        );
        // Estilo declarativo condizente: ícones CLAROS sobre fundo escuro.
        final AnnotatedRegion<SystemUiOverlayStyle> overlay = tester.widget(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(overlay.value.statusBarIconBrightness, Brightness.light);

        // Usuário troca claro/escuro no SO com o app aberto: o tema e o
        // chrome acompanham (MediaQuery reativo, sem recriar o app).
        // NB: pumps com duração em vez de pumpAndSettle — o splash tem um
        // indicador infinito (CircularProgressIndicator) que nunca assenta.
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        final BuildContext after = tester.element(find.byType(Scaffold).first);
        expect(Theme.of(after).brightness, Brightness.light);
        expect(Theme.of(after).extension<AppColorsTheme>()!.bg, auroraLight.bg);
        final AnnotatedRegion<SystemUiOverlayStyle> overlayAfter = tester
            .widget(find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
        expect(overlayAfter.value.statusBarIconBrightness, Brightness.dark);
      },
    );
  });
}
