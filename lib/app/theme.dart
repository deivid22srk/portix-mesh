import 'package:material_ui/material_ui.dart';

import '../core/theme/chrome.dart';
import '../core/theme/tokens.dart';

// ============================================================================
// Tema do PORTIX — ThemeData montado a partir de uma `AppColorsTheme`
// (paleta do tema ativo, ver core/theme/themes.dart). Nada de cor solta nas
// telas: elas resolvem por `context.colors`.
// ============================================================================
class AppTheme {
  const AppTheme._();

  /// Tema escuro padrão (compatibilidade com testes).
  static ThemeData dark() => build(auroraDark);

  static ThemeData build(AppColorsTheme c) {
    // Poppins embutida em assets/fonts (OFL) — funciona offline, renderiza
    // igual no primeiro boot e deixa os testes de golden determinísticos.
    final TextTheme base =
        (c.isDark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(fontFamily: 'Poppins');
    final TextTheme textTheme = base.copyWith(
      // Títulos de tela grandes (~34–40).
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.06,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.08,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
      ),
      // Título grande do jogo nos detalhes.
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: c.brightness,
        ).copyWith(
          primary: c.accent,
          secondary: c.accentAlt,
          surface: c.bg,
          onSurface: c.textPrimary,
          error: c.danger,
          outline: c.glassBorder,
        );

    return ThemeData(
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<Object?>>[c],
    );
  }
}

// ---- acesso conveniente ao tema pelo BuildContext --------------------------
extension AppThemeContext on BuildContext {
  TextTheme get texts => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

// Áreas seguras do sistema (edge-to-edge). `viewPadding` reflete a barra de
// navegação real do aparelho (gestos/3 botões), que varia por modelo.
extension SystemInsets on BuildContext {
  double get systemBottomInset => MediaQuery.viewPaddingOf(this).bottom;

  /// Espaço extra para o conteúdo não ficar sob a navegação. A casca publica o
  /// valor exato via [AppChromeScope] (barra inferior ou navegação lateral);
  /// fora da casca vale a reserva da barra flutuante.
  double get bottomChromePadding =>
      AppChromeScope.maybeOf(this)?.bottomPadding ??
      systemBottomInset + AppSpacing.navContentReserve;
}
