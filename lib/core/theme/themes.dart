import 'package:material_ui/material_ui.dart';

// ============================================================================
// PORTIX — sistema de temas
// Um tema = uma `AppColorsTheme` (ThemeExtension): todos os tokens semânticos
// do app. Nenhuma tela declara cor solta — resolve por `context.colors`.
// Paletas: Aurora (escuro padrão e claro), Midnight (AMOLED), Oceano,
// Floresta, Vice (GTA VI), Cítrico (claro) e Dourado. Contraste AA (4,5:1)
// verificado por test/ui/theme_contrast_test.
// ============================================================================

@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  const AppColorsTheme({
    required this.bg,
    required this.bgElevated,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.glassFloating,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentAlt,
    required this.onAccent,
    required this.favorite,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.shadowStrong,
    required this.brightness,
  });

  /// Fundo base das telas.
  final Color bg;

  /// Fundo de sheets e áreas elevadas.
  final Color bgElevated;

  /// Preenchimento de vidro padrão.
  final Color glass;

  /// Vidro reforçado: item selecionado, pressionado, botões circulares.
  final Color glassStrong;

  /// Borda fina de todo elemento de vidro.
  final Color glassBorder;

  /// Vidro de elementos flutuantes (FAB de busca) — mais opaco para ler sobre
  /// qualquer conteúdo rolando por baixo.
  final Color glassFloating;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Destaque principal.
  final Color accent;

  /// Segundo tom do gradiente de destaque.
  final Color accentAlt;

  /// Texto/ícone sobre o gradiente de destaque.
  final Color onAccent;

  final Color favorite;
  final Color success;
  final Color warning;
  final Color danger;

  /// Sombra de vidro (cai sobre o fundo).
  final Color shadow;

  /// Sombra de elementos flutuantes (FAB, navbar).
  final Color shadowStrong;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // ---- gradientes derivados (nada de cor solta nas telas) ----

  LinearGradient get accentGradient => LinearGradient(
    colors: <Color>[accent, accentAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get brandSoft => LinearGradient(
    colors: <Color>[
      accent.withValues(alpha: 0.22),
      accentAlt.withValues(alpha: 0.08),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get cardGradient => LinearGradient(
    colors: <Color>[glassStrong, glass],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Escurecimento sobre capas para legibilidade de texto — idêntico em todos
  /// os temas: a capa é conteúdo, não superfície do tema.
  LinearGradient get coverScrim => const LinearGradient(
    colors: <Color>[
      Color(0x00000000),
      Color(0x00000000),
      Color(0xA6000000),
      Color(0xD9000000),
    ],
    stops: <double>[0, 0.5, 0.82, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Transição do topo da tela de detalhes para o fundo.
  LinearGradient get scrim => LinearGradient(
    colors: <Color>[
      Colors.transparent,
      bg.withValues(alpha: 0.55),
      bg.withValues(alpha: 0.94),
      bg,
    ],
    stops: const <double>[0, 0.42, 0.78, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  List<BoxShadow> get glassShadow => <BoxShadow>[
    BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 12)),
  ];

  List<BoxShadow> get floatingShadow => <BoxShadow>[
    BoxShadow(color: shadowStrong, blurRadius: 32, offset: const Offset(0, 16)),
  ];

  @override
  AppColorsTheme copyWith({
    Color? bg,
    Color? bgElevated,
    Color? glass,
    Color? glassStrong,
    Color? glassBorder,
    Color? glassFloating,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentAlt,
    Color? onAccent,
    Color? favorite,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
    Color? shadowStrong,
    Brightness? brightness,
  }) {
    return AppColorsTheme(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassFloating: glassFloating ?? this.glassFloating,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentAlt: accentAlt ?? this.accentAlt,
      onAccent: onAccent ?? this.onAccent,
      favorite: favorite ?? this.favorite,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  AppColorsTheme lerp(AppColorsTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColorsTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassFloating: Color.lerp(glassFloating, other.glassFloating, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }

  @override
  int get hashCode => Object.hash(
    bg,
    bgElevated,
    glass,
    glassStrong,
    glassBorder,
    glassFloating,
    textPrimary,
    textSecondary,
    textTertiary,
    accent,
    accentAlt,
    onAccent,
    favorite,
    success,
    warning,
    danger,
    shadow,
    shadowStrong,
    brightness,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppColorsTheme &&
        other.bg == bg &&
        other.bgElevated == bgElevated &&
        other.glass == glass &&
        other.glassStrong == glassStrong &&
        other.glassBorder == glassBorder &&
        other.glassFloating == glassFloating &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textTertiary == textTertiary &&
        other.accent == accent &&
        other.accentAlt == accentAlt &&
        other.onAccent == onAccent &&
        other.favorite == favorite &&
        other.success == success &&
        other.warning == warning &&
        other.danger == danger &&
        other.shadow == shadow &&
        other.shadowStrong == shadowStrong &&
        other.brightness == brightness;
  }
}

// ----------------------------------------------------------------------------
// Paletas ("Sistema/Claro/Escuro" + Midnight, Oceano, Floresta, Vice,
// Cítrico, Dourado).
// ----------------------------------------------------------------------------
const AppColorsTheme auroraDark = AppColorsTheme(
  bg: Color(0xFF07090E),
  bgElevated: Color(0xFF0D1017),
  glass: Color(0x0FFFFFFF),
  glassStrong: Color(0x1AFFFFFF),
  glassBorder: Color(0x1FFFFFFF),
  glassFloating: Color(0x66090B12),
  textPrimary: Color(0xFFF4F6FA),
  textSecondary: Color(0x9EFFFFFF),
  textTertiary: Color(0x8CFFFFFF),
  accent: Color(0xFF22D3EE),
  accentAlt: Color(0xFF34D399),
  onAccent: Color(0xFF031317),
  favorite: Color(0xFFFB7185),
  success: Color(0xFF34D399),
  warning: Color(0xFFFBBF24),
  danger: Color(0xFFF87171),
  shadow: Color(0x59000000),
  shadowStrong: Color(0x8C000000),
  brightness: Brightness.dark,
);

const AppColorsTheme auroraLight = AppColorsTheme(
  bg: Color(0xFFF6F7FB),
  bgElevated: Color(0xFFFFFFFF),
  glass: Color(0x0F111827),
  glassStrong: Color(0x1F111827),
  glassBorder: Color(0x2E111827),
  glassFloating: Color(0xB3FFFFFF),
  textPrimary: Color(0xFF0B1220),
  textSecondary: Color(0x9E111827),
  textTertiary: Color(0xB01F2A44),
  accent: Color(0xFF0E7490),
  accentAlt: Color(0xFF047857),
  onAccent: Color(0xFFFFFFFF),
  favorite: Color(0xFFBE123C),
  success: Color(0xFF047857),
  warning: Color(0xFFB45309),
  danger: Color(0xFFB91C1C),
  shadow: Color(0x1E0F172A),
  shadowStrong: Color(0x290F172A),
  brightness: Brightness.light,
);

/// AMOLED: preto puro, brilho menor nos destakes para não estourar no OLED.
const AppColorsTheme midnight = AppColorsTheme(
  bg: Color(0xFF000000),
  bgElevated: Color(0xFF0A0A0C),
  glass: Color(0x14FFFFFF),
  glassStrong: Color(0x22FFFFFF),
  glassBorder: Color(0x29FFFFFF),
  glassFloating: Color(0x66000000),
  textPrimary: Color(0xFFF2F4F8),
  textSecondary: Color(0x9EFFFFFF),
  textTertiary: Color(0x8CFFFFFF),
  accent: Color(0xFF67E8F9),
  accentAlt: Color(0xFF6EE7B7),
  onAccent: Color(0xFF031317),
  favorite: Color(0xFFFDA4AF),
  success: Color(0xFF6EE7B7),
  warning: Color(0xFFFCD34D),
  danger: Color(0xFFFCA5A5),
  shadow: Color(0x4D000000),
  shadowStrong: Color(0x66000000),
  brightness: Brightness.dark,
);

/// Oceano: azul profundo com destaque céu.
const AppColorsTheme oceano = AppColorsTheme(
  bg: Color(0xFF061B2B),
  bgElevated: Color(0xFF0A2438),
  glass: Color(0x0FE0F2FE),
  glassStrong: Color(0x1AE0F2FE),
  glassBorder: Color(0x1FE0F2FE),
  glassFloating: Color(0x66061F2E),
  textPrimary: Color(0xFFEFF8FF),
  textSecondary: Color(0x9EDDF3FF),
  textTertiary: Color(0x96D0E9FA),
  accent: Color(0xFF38BDF8),
  accentAlt: Color(0xFF2DD4BF),
  onAccent: Color(0xFF05202E),
  favorite: Color(0xFFFDA4AF),
  success: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),
  danger: Color(0xFFF87171),
  shadow: Color(0x59001527),
  shadowStrong: Color(0x8C001527),
  brightness: Brightness.dark,
);

/// Floresta: verde musgo com destaque lima.
const AppColorsTheme floresta = AppColorsTheme(
  bg: Color(0xFF0A1410),
  bgElevated: Color(0xFF10201A),
  glass: Color(0x0FD1FAE0),
  glassStrong: Color(0x1AD1FAE0),
  glassBorder: Color(0x1FD1FAE0),
  glassFloating: Color(0x660C1A12),
  textPrimary: Color(0xFFEFF9F3),
  textSecondary: Color(0x9ED7EFE2),
  textTertiary: Color(0x96C7E6D5),
  accent: Color(0xFFA3E635),
  accentAlt: Color(0xFF84CC16),
  onAccent: Color(0xFF0C1204),
  favorite: Color(0xFFF9A8D4),
  success: Color(0xFF86EFAC),
  warning: Color(0xFFFDE047),
  danger: Color(0xFFFCA5A5),
  shadow: Color(0x59051209),
  shadowStrong: Color(0x8C051209),
  brightness: Brightness.dark,
);

/// Vice: noite de Vice City segundo o GTA VI — ameixa quase preta com neon
/// magenta e coral do logo oficial (gradiente #F143A2 → #FF726A sobre a noite
/// #1C0A12/#2A2058 da arte de lançamento).
const AppColorsTheme vice = AppColorsTheme(
  bg: Color(0xFF180A16),
  bgElevated: Color(0xFF221329),
  glass: Color(0x0FFBD3EF),
  glassStrong: Color(0x24FBD3EF),
  glassBorder: Color(0x2EFBD3EF),
  glassFloating: Color(0x661D0E22),
  textPrimary: Color(0xFFFFF1F8),
  textSecondary: Color(0x9EFBD9EE),
  textTertiary: Color(0x92F6DBEC),
  accent: Color(0xFFF143A2),
  accentAlt: Color(0xFFFF726A),
  onAccent: Color(0xFF2A0A24),
  favorite: Color(0xFFA6ACF5),
  success: Color(0xFF4AE3BC),
  warning: Color(0xFFFFC94D),
  danger: Color(0xFFFF6B7E),
  shadow: Color(0x59100A18),
  shadowStrong: Color(0x8C100A18),
  brightness: Brightness.dark,
);

/// Cítrico: segunda opção clara — creme quente com laranja profundo e
/// lima oliva, para quem quer claro fora do azul do Aurora.
const AppColorsTheme citrico = AppColorsTheme(
  bg: Color(0xFFFFF8EA),
  bgElevated: Color(0xFFFFFFFF),
  glass: Color(0x0F3D2B0E),
  glassStrong: Color(0x1F3D2B0E),
  glassBorder: Color(0x2E3D2B0E),
  glassFloating: Color(0xB3FFFDF2),
  textPrimary: Color(0xFF231A08),
  textSecondary: Color(0x9E2A1E06),
  textTertiary: Color(0xB0322B0C),
  accent: Color(0xFFC2410C),
  accentAlt: Color(0xFF4D7C0F),
  onAccent: Color(0xFFFFFFFF),
  favorite: Color(0xFFBE185D),
  success: Color(0xFF15803D),
  warning: Color(0xFFA16207),
  danger: Color(0xFFB91C1C),
  shadow: Color(0x1E3D2B0E),
  shadowStrong: Color(0x293D2B0E),
  brightness: Brightness.light,
);

/// Dourado: obsidiana com ouro — fundo quase preto quente e destaque dourado
/// duplo para um visual premium de launcher.
const AppColorsTheme dourado = AppColorsTheme(
  bg: Color(0xFF0B0A05),
  bgElevated: Color(0xFF161307),
  glass: Color(0x0FFFF3D0),
  glassStrong: Color(0x1AFFF3D0),
  glassBorder: Color(0x1FFFF3D0),
  glassFloating: Color(0x66131107),
  textPrimary: Color(0xFFFBF6E6),
  textSecondary: Color(0x9EF5E9C8),
  textTertiary: Color(0x8CEBDFBA),
  accent: Color(0xFFE6AE3F),
  accentAlt: Color(0xFFC8952B),
  onAccent: Color(0xFF1F1403),
  favorite: Color(0xFFF9A8D4),
  success: Color(0xFF86EFAC),
  warning: Color(0xFFFDE047),
  danger: Color(0xFFFCA5A5),
  shadow: Color(0x59060400),
  shadowStrong: Color(0x8C060400),
  brightness: Brightness.dark,
);

/// Ids do seletor de tema (persistidos em settings.themeId).
const String kThemeSystem = 'system';
const String kThemeLight = 'light';
const String kThemeDark = 'dark';
const String kThemeMidnight = 'midnight';
const String kThemeOcean = 'oceano';
const String kThemeForest = 'floresta';
const String kThemeVice = 'vice';
const String kThemeCitrus = 'citrico';
const String kThemeGold = 'dourado';

/// Par de paletas que o MaterialApp usa para um id escolhido.
class AppThemePair {
  const AppThemePair({required this.light, required this.dark});

  final AppColorsTheme light;
  final AppColorsTheme dark;
}

AppThemePair appThemePairFor(String id) => switch (id) {
  kThemeSystem => const AppThemePair(light: auroraLight, dark: auroraDark),
  kThemeLight => const AppThemePair(light: auroraLight, dark: auroraLight),
  kThemeDark => const AppThemePair(light: auroraDark, dark: auroraDark),
  kThemeMidnight => const AppThemePair(light: midnight, dark: midnight),
  kThemeOcean => const AppThemePair(light: oceano, dark: oceano),
  kThemeForest => const AppThemePair(light: floresta, dark: floresta),
  kThemeVice => const AppThemePair(light: vice, dark: vice),
  kThemeCitrus => const AppThemePair(light: citrico, dark: citrico),
  kThemeGold => const AppThemePair(light: dourado, dark: dourado),
  _ => const AppThemePair(light: auroraDark, dark: auroraDark),
};

/// Como o MaterialApp resolve o tema para cada id.
ThemeMode themeModeFor(String id) => switch (id) {
  kThemeSystem => ThemeMode.system,
  kThemeLight => ThemeMode.light,
  _ => ThemeMode.dark,
};

/// Resolução dos tokens de qualquer ponto da árvore — tema sempre atual,
/// nunca constante global.
extension AppColorsContext on BuildContext {
  AppColorsTheme get colors =>
      Theme.of(this).extension<AppColorsTheme>() ?? auroraDark;
}
