import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import 'primitives.dart';

// ============================================================================
// AppHeader — o único cabeçalho do app.
//
// Variantes:
//  • [AppHeaderSliver]    raiz: título grande que recolhe em título compacto ao
//                         rolar; as ações ficam sempre visíveis (48dp).
//  • [AppHeaderBar]       interna: voltar + título + ações numa faixa de vidro.
//  • [AppHeaderSearchBar] busca: voltar + campo inline + ações.
//
// Contrato do componente: nenhuma cor/sombra solta (tudo vem do tema), nenhuma
// string literal (L10n), alvo de toque ≥48dp, animação curta e desligada
// quando o sistema pede menos movimento, e nenhum salto de layout — o título
// só muda de escala dentro da própria área que já está reservada.
// ============================================================================

/// Métricas do cabeçalho, no grid de 4/8 do design system.
class AppHeaderMetrics {
  const AppHeaderMetrics._();

  /// Faixa fixa do topo: título compacto + ações (cabe o alvo de 48dp).
  static const double compact = 64;

  /// Corpo do título grande abaixo da faixa compacta (título + subtítulo),
  /// antes da escala de texto do sistema.
  static const double expandedBody = 96;

  /// Ações visíveis na faixa antes de agrupar o resto no menu de overflow.
  /// Com mais ações que isso, cabem [maxActions] botões + o menu (3 alvos de
  /// 48dp) — o título nunca perde a linha para uma fila de ícones.
  static const int maxActions = 2;
}

/// Ação do cabeçalho (ícone + rótulo acessível + contador opcional).
@immutable
class AppHeaderAction {
  const AppHeaderAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badgeCount = 0,
    this.active = false,
  });

  final IconData icon;

  /// Rótulo acessível e tooltip (já localizado).
  final String tooltip;
  final VoidCallback? onTap;

  /// Contador do badge (0 = sem badge). O visual limita em "99+".
  final int badgeCount;
  final bool active;
}

/// Contador compacto de badge, com limite visual.
class AppHeaderBadge extends StatelessWidget {
  const AppHeaderBadge({super.key, required this.count, this.limit = 99});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final String label = count > limit ? '$limit+' : '$count';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: AppSpacing.xl),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.hairline,
          ),
          decoration: BoxDecoration(
            color: context.colors.accent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: context.texts.labelSmall?.copyWith(
              color: context.colors.onAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de ação do cabeçalho: reusa [GlassCircleButton] para herdar o alvo de
/// 48dp, o feedback de toque e o tooltip acessível de todo o app.
class AppHeaderActionButton extends StatelessWidget {
  const AppHeaderActionButton({
    super.key,
    required this.action,
    this.blur = false,
  });

  final AppHeaderAction action;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return GlassCircleButton(
      icon: action.icon,
      tooltip: action.tooltip,
      onTap: action.onTap,
      active: action.active,
      blur: blur,
      badge: action.badgeCount > 0
          ? AppHeaderBadge(count: action.badgeCount)
          : null,
    );
  }
}

/// Ações à direita: no máximo [maxVisible] ficam visíveis, o resto desce para
/// um menu — o cabeçalho nunca "vira uma fila de ícones".
class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({
    super.key,
    required this.actions,
    this.maxVisible = AppHeaderMetrics.maxActions,
    this.blur = false,
  });

  final List<AppHeaderAction> actions;
  final int maxVisible;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool overflow = actions.length > maxVisible;
    final int visible = overflow ? maxVisible : actions.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < visible; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          AppHeaderActionButton(action: actions[index], blur: blur),
        ],
        if (overflow) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          _HeaderOverflowMenu(actions: actions.sublist(visible)),
        ],
      ],
    );
  }
}

class _HeaderOverflowMenu extends StatelessWidget {
  const _HeaderOverflowMenu({required this.actions});

  final List<AppHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: context.l10n.moreActions,
      onSelected: (int index) => actions[index].onTap?.call(),
      icon: Icon(Icons.more_horiz_rounded, color: context.colors.textPrimary),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        for (int index = 0; index < actions.length; index += 1)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: <Widget>[
                Icon(
                  actions[index].icon,
                  size: AppSpacing.xl,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: Text(actions[index].tooltip)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cabeçalho de raiz como sliver: título grande que encolhe para o título
/// compacto enquanto o conteúdo passa por baixo, com o vidro aparecendo só
/// depois que a rolagem começa (nenhum estado intermediário "pisca").
class AppHeaderSliver extends StatelessWidget {
  const AppHeaderSliver({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <AppHeaderAction>[],
    this.trailing,
    this.expandedBody = AppHeaderMetrics.expandedBody,
  });

  final String title;
  final String? subtitle;
  final List<AppHeaderAction> actions;

  /// Slot livre à direita das ações (ex.: avatar do usuário em cache).
  final Widget? trailing;

  /// Espaço do título grande; escala junto com a fonte do sistema.
  final double expandedBody;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _AppHeaderDelegate(
        title: title,
        subtitle: subtitle,
        actions: actions,
        trailing: trailing,
        collapsedHeight: AppHeaderMetrics.compact,
        expandedHeight: AppHeaderMetrics.compact + scaler.scale(expandedBody),
        scaler: scaler,
      ),
    );
  }
}

class _AppHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AppHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.trailing,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.scaler,
  });

  final String title;
  final String? subtitle;
  final List<AppHeaderAction> actions;
  final Widget? trailing;
  final double collapsedHeight;
  final double expandedHeight;
  final TextScaler scaler;

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double range = expandedHeight - collapsedHeight;
    final double collapsed = range <= 0
        ? 1
        : (shrinkOffset / range).clamp(0.0, 1.0);
    final TextTheme texts = context.texts;
    final Color glass = context.colors.glassFloating;
    final Color border = context.colors.glassBorder;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        // Vidro: existe só a partir do primeiro pixel de rolagem.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: collapsed,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppSpacing.glassBlur,
                    sigmaY: AppSpacing.glassBlur,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: glass,
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Faixa compacta: título pequeno (revelado ao recolher) + ações fixas.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: collapsedHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Opacity(
                    opacity: collapsed,
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  AppHeaderActions(actions: actions),
                ],
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
        // Título grande: sobe junto com o conteúdo e desaparece sob a faixa.
        Positioned(
          top: collapsedHeight,
          left: 0,
          right: 0,
          height: range,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1 - collapsed,
              child: Transform.translate(
                offset: Offset(0, -shrinkOffset * 0.5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        // Heading: leitores de tela navegam por título.
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: texts.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: texts.bodyMedium?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _AppHeaderDelegate oldDelegate) =>
      oldDelegate.title != title ||
      oldDelegate.subtitle != subtitle ||
      oldDelegate.collapsedHeight != collapsedHeight ||
      oldDelegate.expandedHeight != expandedHeight ||
      oldDelegate.scaler != scaler ||
      oldDelegate.actions != actions ||
      oldDelegate.trailing != trailing;
}

/// Faixa de vidro do cabeçalho (fundo + borda inferior + desfoque opcional).
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.child, required this.blur});

  final Widget child;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final Widget band = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.glassFloating,
        border: Border(bottom: BorderSide(color: context.colors.glassBorder)),
      ),
      child: child,
    );
    if (!blur) {
      return band;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSpacing.glassBlur,
          sigmaY: AppSpacing.glassBlur,
        ),
        child: band,
      ),
    );
  }
}

/// Cabeçalho interno: voltar + título (e subtítulo) + ações.
class AppHeaderBar extends StatelessWidget {
  const AppHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions = const <AppHeaderAction>[],
    this.trailing,
    this.blur = true,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<AppHeaderAction> actions;

  /// Slot livre à direita das ações (ex.: avatar do usuário em cache).
  final Widget? trailing;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return _HeaderBand(
      blur: blur,
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            GlassCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: context.l10n.tooltipBack,
              onTap:
                  onBack ?? () => unawaited(Navigator.of(context).maybePop()),
              blur: blur,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            AppHeaderActions(actions: actions, blur: blur),
          ],
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Cabeçalho de busca: voltar + campo inline + ações.
class AppHeaderSearchBar extends StatelessWidget {
  const AppHeaderSearchBar({
    super.key,
    required this.field,
    this.onBack,
    this.actions = const <AppHeaderAction>[],
  });

  final Widget field;
  final VoidCallback? onBack;
  final List<AppHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return _HeaderBand(
      blur: true,
      child: Row(
        children: <Widget>[
          GlassCircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: context.l10n.tooltipBack,
            onTap: onBack ?? () => unawaited(Navigator.of(context).maybePop()),
            blur: true,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: field),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            AppHeaderActions(actions: actions, blur: true),
          ],
        ],
      ),
    );
  }
}
