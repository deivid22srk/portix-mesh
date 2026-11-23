import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import 'primitives.dart';

// Medidas da miniatura — constantes locais para não vazar números mágicos
// nas chamadas (o gate de UI exige grid 4/8 via tokens ou constantes nomeadas).
const double _cardWidth = 152;
const double _previewHeight = 88;
const double _barHeight = 16;
const double _barMarkWidth = 20;
const double _barMarkHeight = 4;
const double _lineHeight = 8;
const double _halfLineFactor = 0.6;
const double _buttonHeight = 12;
const double _checkSize = 18;

/// Opção apresentada no seletor: id persistido + paleta para a prévia.
class ThemeOption {
  const ThemeOption({
    required this.id,
    required this.name,
    required this.hint,
    required this.colors,
    this.split = false,
  });

  final String id;
  final String name;
  final String hint;
  final AppColorsTheme colors;

  /// true para "Sistema": a prévia mostra claro e escuro lado a lado.
  final bool split;
}

/// Seletor de temas: cards com miniatura real de cada paleta, troca
/// instantânea e animada de forma sutil (MaterialApp anima a transição).
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key, this.onChanged});

  /// Callback opcional além da persistência (testes).
  final ValueChanged<String>? onChanged;

  List<ThemeOption> _options(
    L10n l10n,
    Brightness systemBrightness,
  ) => <ThemeOption>[
    ThemeOption(
      id: kThemeSystem,
      name: l10n.themeSystem,
      hint: l10n.themeSystemHint,
      colors: systemBrightness == Brightness.light ? auroraLight : auroraDark,
      split: true,
    ),
    ThemeOption(
      id: kThemeLight,
      name: l10n.themeLight,
      hint: '',
      colors: auroraLight,
    ),
    ThemeOption(
      id: kThemeDark,
      name: l10n.themeDark,
      hint: '',
      colors: auroraDark,
    ),
    ThemeOption(
      id: kThemeMidnight,
      name: l10n.themeMidnight,
      hint: l10n.themeMidnightHint,
      colors: midnight,
    ),
    ThemeOption(
      id: kThemeOcean,
      name: l10n.themeOcean,
      hint: '',
      colors: oceano,
    ),
    ThemeOption(
      id: kThemeForest,
      name: l10n.themeForest,
      hint: '',
      colors: floresta,
    ),
    ThemeOption(
      id: kThemeVice,
      name: l10n.themeVice,
      hint: l10n.themeViceHint,
      colors: vice,
    ),
    ThemeOption(
      id: kThemeCitrus,
      name: l10n.themeCitrus,
      hint: '',
      colors: citrico,
    ),
    ThemeOption(
      id: kThemeGold,
      name: l10n.themeGold,
      hint: '',
      colors: dourado,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final String current = ref.watch(
      settingsProvider.select((AppSettings s) => s.themeId),
    );
    final Brightness systemBrightness = MediaQuery.platformBrightnessOf(
      context,
    );
    // Reduced motion: transição de seleção sem animação.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration duration = reduceMotion ? Duration.zero : AppMotion.base;
    final List<ThemeOption> options = _options(l10n, systemBrightness);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        for (final ThemeOption option in options)
          _ThemeCard(
            option: option,
            selected: current == option.id,
            duration: duration,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeId(option.id);
              onChanged?.call(option.id);
            },
          ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.option,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final ThemeOption option;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final AppColorsTheme preview = option.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.themeOptionSemantic(option.name),
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.emphasized,
          width: _cardWidth,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.colors.glassStrong,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected
                  ? context.colors.accent
                  : context.colors.glassBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ThemePreview(colors: preview, split: option.split),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? context.colors.accent
                            : context.colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _checkSize,
                    height: _checkSize,
                    child: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            size: _checkSize,
                            color: context.colors.accent,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              if (option.hint.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  option.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura real: usa a paleta do tema (bg, barra elevada, linhas de vidro
/// e botão com o gradiente de destaque) — o usuário vê o tema de verdade.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.colors, required this.split});

  final AppColorsTheme colors;
  final bool split;

  @override
  Widget build(BuildContext context) {
    // A miniatura é imagem sem texto: rotula para leitores de tela.
    return Semantics(
      label: context.l10n.themePreviewLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: SizedBox(
          height: _previewHeight,
          child: split
              ? Row(
                  children: <Widget>[
                    Expanded(child: _paint(auroraLight)),
                    Expanded(child: _paint(auroraDark)),
                  ],
                )
              : _paint(colors),
        ),
      ),
    );
  }

  Widget _paint(AppColorsTheme c) {
    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Barra de título fake.
          Container(
            height: _barHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.centerLeft,
            color: c.bgElevated,
            child: Container(
              width: _barMarkWidth,
              height: _barMarkHeight,
              decoration: BoxDecoration(
                color: c.textTertiary,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Duas "linhas" de conteúdo em vidro.
                  Container(
                    height: _lineHeight,
                    decoration: BoxDecoration(
                      color: c.glassStrong,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FractionallySizedBox(
                    widthFactor: _halfLineFactor,
                    child: Container(
                      height: _lineHeight,
                      decoration: BoxDecoration(
                        color: c.glass,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Botão principal com o gradiente do tema.
                  Container(
                    height: _buttonHeight,
                    decoration: BoxDecoration(
                      gradient: c.accentGradient,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
