import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/env.dart';
import '../core/providers.dart';
import '../core/theme/tokens.dart';
import '../features/splash/splash_page.dart';
import 'router.dart';
import 'settings.dart';
import 'theme.dart';

// Raiz do app. O bootstrap (aquecer o catálogo local + ligar a malha) acontece
// antes de qualquer rota ser construída: assim nenhuma tela abre sem os dados
// locais prontos.
class PortixApp extends ConsumerWidget {
  const PortixApp({super.key});

  // `GlobalMaterialLocalizations.delegates` reúne Material, Widgets e Cupertino.
  static const List<LocalizationsDelegate<dynamic>> _delegates =
      GlobalMaterialLocalizations.delegates;

  static const List<Locale> _locales = <Locale>[
    Locale('pt', 'BR'),
    Locale('en'),
  ];

  /// Escala de texto do sistema: piso 1.0 (nunca rebaixa o pedido do usuário)
  /// e teto 2.0 — WCAG 1.4.4 exige redimensionamento de 200%. O layout deve
  /// sobreviver ao teto (as grades/limites de largura já são elásticas).
  Widget _withTextScale(Widget? child) => MediaQuery.withClampedTextScaling(
    minScaleFactor: 1.0,
    maxScaleFactor: 2.0,
    child: child ?? const SizedBox.shrink(),
  );

  /// Monte o MaterialApp uma única vez — as variantes com router e as de
  /// boot/erro (home) compartilham a mesma configuração de tema/localização.
  /// O SystemChrome (cor dos ícones das barras) é declarativo via
  /// AnnotatedRegion: reage a tema, modo Sistema e troca de brilho do SO sem
  /// nenhum efeito colateral imperativo no build.
  Widget _app({
    required ThemeData theme,
    required ThemeData darkTheme,
    required ThemeMode mode,
    required AppSettings settings,
    required AppColorsTheme colors,
    required bool disableAnimations,
    Widget? home,
    GoRouter? router,
  }) {
    final SystemUiOverlayStyle overlay = _overlayStyleFor(colors);
    final Duration themeAnimation = disableAnimations
        ? Duration.zero
        : AppMotion.base;
    if (router != null) {
      return MaterialApp.router(
        title: 'PORTIX',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // Troca de tema animada e sutil (respeita reduced motion).
        themeAnimationDuration: themeAnimation,
        themeAnimationCurve: AppMotion.emphasized,
        locale: settings.locale,
        supportedLocales: _locales,
        localizationsDelegates: _delegates,
        builder: (BuildContext context, Widget? child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: _withTextScale(child),
            ),
        routerConfig: router,
      );
    }
    return MaterialApp(
      title: 'PORTIX',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationDuration: themeAnimation,
      themeAnimationCurve: AppMotion.emphasized,
      locale: settings.locale,
      supportedLocales: _locales,
      localizationsDelegates: _delegates,
      builder: (BuildContext context, Widget? child) =>
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: _withTextScale(child),
          ),
      home: home,
    );
  }

  /// Estilo declarativo das barras do sistema para a paleta resolvida.
  SystemUiOverlayStyle _overlayStyleFor(AppColorsTheme colors) {
    return SystemUiOverlayStyle(
      statusBarColor: AppContentColors.transparent,
      statusBarIconBrightness: colors.isDark
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: colors.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: AppContentColors.transparent,
      systemNavigationBarIconBrightness: colors.isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final AsyncValue<void> bootstrap = ref.watch(meshBootstrapProvider);
    final AppThemePair pair = appThemePairFor(settings.themeId);
    final ThemeMode mode = themeModeFor(settings.themeId);
    final ThemeData lightTheme = AppTheme.build(pair.light);
    final ThemeData darkTheme = AppTheme.build(pair.dark);
    final Brightness platformBrightness = MediaQuery.platformBrightnessOf(
      context,
    );
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final Brightness resolved = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    final AppColorsTheme colors = resolved == Brightness.light
        ? pair.light
        : pair.dark;

    if (bootstrap.isLoading) {
      return _app(
        theme: lightTheme,
        darkTheme: darkTheme,
        mode: mode,
        settings: settings,
        colors: colors,
        disableAnimations: disableAnimations,
        home: const SplashPage(),
      );
    }

    if (bootstrap.hasError) {
      return _app(
        theme: lightTheme,
        darkTheme: darkTheme,
        mode: mode,
        settings: settings,
        colors: colors,
        disableAnimations: disableAnimations,
        home: BootstrapErrorPage(
          error: bootstrap.error ?? const AppFailure(FailureKind.unknown),
        ),
      );
    }

    return _app(
      theme: lightTheme,
      darkTheme: darkTheme,
      mode: mode,
      settings: settings,
      colors: colors,
      disableAnimations: disableAnimations,
      router: ref.watch(routerProvider),
    );
  }
}
