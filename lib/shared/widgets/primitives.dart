import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';

// ============================================================================
// Componentes de vidro reutilizáveis (design system do PORTIX).
// Blur (BackdropFilter) só é usado na barra de navegação, no botão de busca e
// em elementos fixos; dentro de listas/grades usamos apenas preenchimento
// translúcido, por performance.
// ============================================================================

/// Fundo com brilho ambiente da cor de destaque, esmaecendo para `bg`.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.bg,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -200,
            right: -140,
            child: IgnorePointer(
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      context.colors.accent.withValues(alpha: 0.13),
                      context.colors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -160,
            child: IgnorePointer(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      context.colors.accentAlt.withValues(alpha: 0.07),
                      context.colors.accentAlt.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Painel de vidro: preenchimento translúcido + borda fina + raio.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.lg,
    this.color,
    this.borderColor,
    this.blur = false,
    this.blurSigma = 20,
    this.shadow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool blur;
  final double blurSigma;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color ?? context.colors.glass,
        border: Border.all(color: borderColor ?? context.colors.glassBorder),
        boxShadow: shadow,
      ),
      child: child,
    );
    final Widget surface = blur
        ? ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: panel,
            ),
          )
        : panel;
    if (onTap == null) {
      return surface;
    }
    return Pressable(onTap: onTap, child: surface);
  }
}

/// Feedback de toque: escala suave + haptic opcional.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptics;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (TapDownDetails _) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled ? (TapUpDetails _) => _setPressed(false) : null,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics) {
                HapticFeedback.selectionClick();
              }
              widget.onTap?.call();
            },
      child: Semantics(
        // GestureDetector puro é invisível para o TalkBack: marcar como
        // botão expõe o gesto (o rótulo vem do texto filho mesclado).
        button: enabled,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          // Reduced motion: sem animação de press (transição instantânea).
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.fast,
          curve: AppMotion.out,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Botão circular de vidro (voltar, filtro, compartilhar, controles).
/// O `tooltip` é OBRIGATÓRIO: um ícone sem rótulo é invisível para leitores
/// de tela (TalkBack) — nunca chame este componente sem um rótulo l10n.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.size = AppSpacing.circleButton,
    this.iconSize,
    this.badge,
    this.color,
    this.blur = false,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final double? iconSize;
  final Widget? badge;
  final Color? color;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final Color tone =
        color ?? (active ? context.colors.accent : context.colors.textPrimary);
    final Widget button = Pressable(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: GlassContainer(
          radius: AppRadii.pill,
          blur: blur,
          color: active
              ? context.colors.accent.withValues(alpha: 0.18)
              : context.colors.glassStrong,
          borderColor: active
              ? context.colors.accent.withValues(alpha: 0.5)
              : context.colors.glassBorder,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, size: iconSize ?? size * 0.44, color: tone),
              if (badge != null)
                Positioned(top: size * 0.14, right: size * 0.14, child: badge!),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Botão principal (gradiente de destaque), pílula.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = AppSpacing.primaryButtonHeight,
    this.expand = true,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final Widget content = AnimatedContainer(
      duration: AppMotion.base,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        gradient: enabled ? context.colors.accentGradient : null,
        color: enabled ? null : context.colors.glassStrong,
        border: enabled ? null : Border.all(color: context.colors.glassBorder),
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: context.colors.accent.withValues(alpha: 0.30),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.onAccent,
                ),
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 20,
              color: enabled
                  ? context.colors.onAccent
                  : context.colors.textTertiary,
            ),
          if (isLoading || icon != null)
            const SizedBox(width: AppSpacing.compact),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleSmall?.copyWith(
                color: enabled
                    ? context.colors.onAccent
                    : context.colors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.compact),
            trailing!,
          ],
        ],
      ),
    );
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: expand
          ? SizedBox(width: double.infinity, child: content)
          : content,
    );
  }
}

/// Botão secundário (vidro), pílula.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = AppSpacing.secondaryButtonHeight,
    this.expand = true,
    this.active = false,
    this.iconColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool active;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: active
              ? context.colors.accent.withValues(alpha: 0.16)
              : context.colors.glass,
          border: Border.all(
            color: active
                ? context.colors.accent.withValues(alpha: 0.5)
                : context.colors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 19,
                color:
                    iconColor ??
                    (active
                        ? context.colors.accent
                        : context.colors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelLarge?.copyWith(
                  color: active
                      ? context.colors.accent
                      : context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pílula de vidro com ícone + texto (chips de informação).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? context.colors.accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.md : AppSpacing.lg,
        vertical: dense ? 7 : 9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: context.colors.glass,
        border: Border.all(color: context.colors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: context.texts.labelMedium?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pílula escura sobre a capa com nota (%) e popularidade.
class StatBadge extends StatelessWidget {
  const StatBadge({super.key, this.rating = 0, this.downloads = 0});

  final double rating;
  final int downloads;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0 && downloads <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: AppContentColors.scrim.withValues(alpha: 0.54),
        border: Border.all(color: context.colors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (rating > 0) ...<Widget>[
            Icon(Icons.star_rounded, size: 13, color: context.colors.warning),
            const SizedBox(width: AppSpacing.hairline),
            Text(
              formatPercent(rating / 5),
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (rating > 0 && downloads > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: SizedBox(
                width: 1,
                height: 11,
                child: ColoredBox(color: context.colors.glassBorder),
              ),
            ),
          if (downloads > 0) ...<Widget>[
            Icon(
              Icons.download_rounded,
              size: 13,
              color: context.colors.accentAlt,
            ),
            const SizedBox(width: AppSpacing.hairline),
            Text(
              compactNumber(downloads),
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip/badge simples com tonalidade opcional.
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? context.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pílula selecionável (filtros, categorias).
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        // Alvo de toque: denso ≥ 44dp, padrão ≥ 48dp (WCAG 2.2 AA 2.5.8).
        constraints: BoxConstraints(
          minHeight: dense
              ? AppSpacing.compact + AppSpacing.compact + AppSpacing.xxl
              : AppSpacing.circleButton,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.md : AppSpacing.lg,
          vertical: dense ? AppSpacing.compact : AppSpacing.fieldVertical,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: selected
              ? context.colors.accent.withValues(alpha: 0.18)
              : context.colors.glass,
          border: Border.all(
            color: selected
                ? context.colors.accent.withValues(alpha: 0.55)
                : context.colors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppSpacing.xxs),
            ],
            Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                color: selected
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xxs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho de seção com ação opcional (chevron).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,

    /// Sobrescreve o inset padrão (screen à esquerda) — use quando o caller
    /// já aplica a margem lateral (ex.: seções centralizadas > contentMax).
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      actionLabel!,
                      style: context.texts.labelMedium?.copyWith(
                        color: context.colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.colors.accent,
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

/// Tile de seção: ícone + rótulo + chevron (usado na home e no menu).
class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: context.colors.accent),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.colors.textTertiary,
              ),
        ],
      ),
    );
  }
}

/// Botão de busca circular, flutuante, ao lado da barra de navegação.
class SearchFab extends StatelessWidget {
  SearchFab({super.key, required this.tooltip, this.onTap});

  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: SizedBox(
          width: AppSpacing.searchFab,
          height: AppSpacing.searchFab,
          child: GlassContainer(
            radius: AppRadii.pill,
            blur: true,
            color: context.colors.glassFloating,
            shadow: context.colors.floatingShadow,
            child: Center(
              child: Icon(
                Icons.search_rounded,
                size: 30,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de nota com estrela e contagem.
class RatingLine extends StatelessWidget {
  const RatingLine({
    super.key,
    required this.rating,
    this.count = 0,
    this.compact = false,
  });

  final double rating;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        '—',
        style: context.texts.labelMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.star_rounded,
          size: compact ? 14 : 16,
          color: context.colors.warning,
        ),
        const SizedBox(width: AppSpacing.hairline),
        Text(
          formatRating(rating),
          style: context.texts.labelMedium?.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count > 0 && !compact) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '($count)',
            style: context.texts.labelSmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Seletor de estrelas para avaliação. Cada estrela expõe papel de botão
/// e rótulo "N de 5 estrelas"; o contêiner resume o estado atual — sem isso
/// o fluxo de avaliação é inacessível para leitores de tela.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 34,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.starPickerSummary(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 1; index <= 5; index += 1)
            Pressable(
              onTap: () => onChanged(index),
              child: Semantics(
                label: l10n.starSemantic(index),
                selected: index <= value,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.08),
                  child: Icon(
                    index <= value
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: size,
                    color: index <= value
                        ? context.colors.warning
                        : context.colors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Interruptor customizado (não usa `Switch` do Material).
/// Expõe papel de botão + estado `toggled` para o TalkBack e garante alvo
/// de toque de pelo menos 48px de altura (WCAG 2.2 AA, 2.5.8).
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Nome do ajuste controlado (ex.: "Notificações"). Sem ele o TalkBack
  /// anuncia "ativado/desativado" sem dizer o que o interruptor faz.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Papel de botão + estado `toggled`: o TalkBack anuncia
      // "<rótulo>, ativado/desativado". `switch` não é nome válido de
      // parâmetro no Dart 3 (palavra reservada).
      button: true,
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: SizedBox(
          // Trilho visual 52×30 dentro de alvo 52×48 (toque confortável).
          width: 52,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.out,
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                color: value
                    ? context.colors.accent
                    : context.colors.glassStrong,
                border: Border.all(
                  color: value
                      ? context.colors.accent
                      : context.colors.glassBorder,
                ),
              ),
              child: AnimatedAlign(
                duration: AppMotion.base,
                curve: AppMotion.out,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? context.colors.onAccent
                        : context.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progresso com gradiente de destaque.
class GradientProgress extends StatelessWidget {
  GradientProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.semanticLabel,
  });

  final double value;
  final double height;

  /// Rótulo para leitores de tela (ex.: “32%” ou “Pausado”). Sem ele a barra
  /// é invisível para o TalkBack — progresso nunca deve ser só visual.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget bar = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
      duration: AppMotion.slow,
      curve: AppMotion.out,
      builder: (BuildContext context, double animated, Widget? child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: context.colors.glassStrong),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: context.colors.accentGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (semanticLabel == null) {
      return bar;
    }
    // container: true — nó próprio no TalkBack; sem isso o rótulo é
    // absorvido pelo ancestral mesclado (botão do tile) e o progresso
    // volta a ser invisível para leitores de tela.
    return Semantics(container: true, label: semanticLabel, child: bar);
  }
}

/// Item de um controle segmentado.
class SegmentItem<T> {
  const SegmentItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Controle segmentado de vidro.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          for (final SegmentItem<T> item in items)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(item.value),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    color: item.value == value
                        ? context.colors.glassStrong
                        : AppContentColors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (item.icon != null) ...<Widget>[
                        Icon(
                          item.icon,
                          size: 15,
                          color: item.value == value
                              ? context.colors.accent
                              : context.colors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                      ],
                      Flexible(
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelMedium?.copyWith(
                            color: item.value == value
                                ? context.colors.textPrimary
                                : context.colors.textTertiary,
                            fontWeight: item.value == value
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grade de capas 3:4 responsiva (padrão de todas as telas de catálogo).
///
/// Substitui `SliverGrid` com `crossAxisCount` fixo: 2 colunas no celular,
/// 3 no tablet (≥600px), 5 no desktop (≥1024px) e 6 em telas largas
/// (≥1440px). Acima de `AppBreakpoints.contentMax` o conteúdo é centralizado
/// com padding extra em vez de esticar capas por um monitor inteiro.
class ResponsiveCoverGrid extends StatelessWidget {
  const ResponsiveCoverGrid({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.padding,
    this.aspectRatio = 3 / 4,
    this.mainAxisExtent,
  });

  /// Construtor do card: (context, index).
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;

  /// Padding externo da grade. Se nulo, usa a margem lateral padrão.
  final EdgeInsets? padding;
  final double aspectRatio;

  /// Altura fixa dos itens (grades de tiles de seção, não capas).
  final double? mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) {
        final double width = constraints.crossAxisExtent;
        // Teto de largura de conteúdo: em telas largas, distribui o excesso
        // nas margens para centralizar a grade (sem tocar no shell).
        final double extra = width > AppBreakpoints.contentMax
            ? (width - AppBreakpoints.contentMax) / 2
            : 0;
        final EdgeInsets base =
            padding ?? EdgeInsets.symmetric(horizontal: AppSpacing.screen);
        return SliverPadding(
          padding: base + EdgeInsets.symmetric(horizontal: extra),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppBreakpoints.coverColumns(width),
              mainAxisSpacing: AppSpacing.gridGap,
              crossAxisSpacing: AppSpacing.gridGap,
              childAspectRatio: aspectRatio,
              mainAxisExtent: mainAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: itemCount,
            ),
          ),
        );
      },
    );
  }
}

/// Teto de largura de conteúdo para páginas não-grade (detalhe, menu, busca,
/// autenticação): em telas largas centraliza o corpo em 1200px, igual às
/// grades de capas — nada estica por um monitor inteiro.
class AppContentMax extends StatelessWidget {
  const AppContentMax({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMax),
        child: child,
      ),
    );
  }
}

/// Diálogo de confirmação do sistema de vidro — substitui `AlertDialog` cru:
/// superfície elevada do tema, raio do sheet, textos e botões do design
/// system. Retorno: true só se o usuário confirmar.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,

  /// Ação destrutiva (sair da conta, apagar cache): o botão de confirmar
  /// ganha a cor de perigo para sinalizar consequência.
  bool destructive = false,
}) async {
  final L10n l10n = context.l10n;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      backgroundColor: context.colors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      title: Text(
        title,
        style: context.texts.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: context.texts.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(
            cancelLabel ?? l10n.cancel,
            style: context.texts.labelLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            confirmLabel ?? l10n.confirm,
            style: context.texts.labelLarge?.copyWith(
              color: destructive
                  ? context.colors.danger
                  : context.colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}
