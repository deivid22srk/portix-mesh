import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/theme/themes.dart';

// ============================================================================
// Contraste WCAG 2.2 AA para TODAS as paletas do app. Cada par que aparece
// na UI é verificado: texto sobre fundos (4,5:1) e destaque/onAccent (4,5:1).
// Falha em qualquer paleta = tema ilegível = bloqueio de release.
// ============================================================================

int _ch(double c) => (c * 255).round().clamp(0, 255);

double _linearChannel(int v) {
  final double c = v / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color c) =>
    0.2126 * _linearChannel(_ch(c.r)) +
    0.7152 * _linearChannel(_ch(c.g)) +
    0.0722 * _linearChannel(_ch(c.b));

double _contrast(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color fg, Color bg) {
  final double alpha = fg.a;
  int mix(double f, double b) =>
      ((f * alpha + b * (1 - alpha)) * 255).round().clamp(0, 255);
  return Color.fromARGB(255, mix(fg.r, bg.r), mix(fg.g, bg.g), mix(fg.b, bg.b));
}

const List<AppColorsTheme> _palettes = <AppColorsTheme>[
  auroraDark,
  auroraLight,
  midnight,
  oceano,
  floresta,
  vice,
  citrico,
  dourado,
];

void main() {
  for (final AppColorsTheme c in _palettes) {
    group('paleta ${c.brightness.name} bg ${c.bg}', () {
      void expectAA(String what, Color fg, Color bg) {
        final double ratio = _contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$what tem contraste $ratio (precisa ≥ 4,5)',
        );
      }

      test('texto primário sobre fundos', () {
        expectAA('textPrimary/bg', c.textPrimary, c.bg);
        expectAA('textPrimary/bgElevated', c.textPrimary, c.bgElevated);
        expectAA(
          'textPrimary/vidro forte',
          c.textPrimary,
          _over(c.glassStrong, c.bg),
        );
        // Vidro do FAB flutuante (mais opaco): ícones de ação por cima.
        expectAA(
          'textPrimary/vidro flutuante',
          c.textPrimary,
          _over(c.glassFloating, c.bg),
        );
        expectAA(
          'accent/vidro flutuante',
          c.accent,
          _over(c.glassFloating, c.bg),
        );
      });

      test('texto secundário e terciário', () {
        expectAA('textSecondary/bg', _over(c.textSecondary, c.bg), c.bg);
        expectAA(
          'textSecondary/bgElevated',
          _over(c.textSecondary, c.bgElevated),
          c.bgElevated,
        );
        expectAA('textTertiary/bg', _over(c.textTertiary, c.bg), c.bg);
        expectAA(
          'textTertiary/vidro forte',
          _over(c.textTertiary, _over(c.glassStrong, c.bg)),
          _over(c.glassStrong, c.bg),
        );
      });

      test('destaque e botão principal', () {
        expectAA('accent/bg', c.accent, c.bg);
        expectAA('accentAlt/bg', c.accentAlt, c.bg);
        expectAA('onAccent/accent', c.onAccent, c.accent);
        expectAA('onAccent/accentAlt', c.onAccent, c.accentAlt);
      });

      test('cores de estado usadas como texto', () {
        expectAA('danger/bg', c.danger, c.bg);
        expectAA('danger/bgElevated', c.danger, c.bgElevated);
        expectAA('success/bg', c.success, c.bg);
        expectAA('warning/bg', c.warning, c.bg);
        expectAA('favorite/bg', c.favorite, c.bg);
      });
    });
  }
}
