import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/chrome.dart';
import '../../core/theme/tokens.dart';
import 'app_mark.dart';
import 'primitives.dart';

// ============================================================================
// Navegação principal adaptativa — um único conjunto de destinos desenhado de
// três formas conforme a largura:
//
//   <768           AppNavBottomBar   barra de vidro flutuante (polegar)
//   768–1199       AppNavRail        rail vertical com rótulo ao lado
//   ≥1200          AppNavSidebar     sidebar recolhível (marca + conta)
//
// Os destinos são dados ([AppNavDestination]) e nunca duplicados: a casca monta
// a lista uma vez e cada variante só muda a apresentação. O estado da aba vive
// no StatefulShellRoute (indexedStack), então trocar de modo não perde nada.
// ============================================================================

/// Um destino da navegação principal (máximo [AppNav.maxDestinations]).
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  /// Ícone de contorno (inativo) e preenchido (ativo) — padrão M3.
  final IconData icon;
  final IconData activeIcon;

  /// Rótulo sempre visível (e rótulo acessível quando o modo é só ícone).
  final String label;

  /// Contador do badge (0 = sem badge); o visual limita em "99+".
  final int badgeCount;
}

/// Como os destinos são desenhados.
enum AppNavItemLayout {
  /// Ícone sobre o rótulo (barra inferior e rail).
  stacked,

  /// Ícone ao lado do rótulo (sidebar).
  inline,
}

/// Regras da navegação compartilhadas pelas variantes.
class AppNav {
  const AppNav._();

  /// Teto de destinos principais: acima disso a navegação deixa de ser legível.
  static const int maxDestinations = 5;

  /// Modo correspondente à largura da janela.
  static AppNavMode modeFor(double width) {
    if (width >= AppBreakpoints.navSidebar) {
      return AppNavMode.sidebar;
    }
    if (width >= AppBreakpoints.navRail) {
      return AppNavMode.rail;
    }
    return AppNavMode.bottom;
  }

  /// Margem lateral da chrome. Em telefone estreito ela encolhe — é o primeiro
  /// recurso antes de sacrificar o alvo de toque: a 320dp, com a busca ao lado
  /// e o respiro interno da barra, 16dp de margem deixariam 40dp por destino.
  static double edgeInset(double width) =>
      width < AppBreakpoints.narrow ? AppSpacing.sm : AppSpacing.screen;

  /// Respiro entre a barra e a busca. Em telefone estreito ele encolhe junto
  /// com a margem: o alvo de toque vem antes do respiro.
  static double barActionGap(double width) =>
      width < AppBreakpoints.narrow ? AppSpacing.xs : AppSpacing.sm;

  /// Respiro interno da barra antes dos destinos: `padding` de 4dp + borda de
  /// 1dp em cada lado. Entra na conta do alvo porque encolhe a faixa útil.
  static const double barInnerInset = 2 * AppSpacing.xs + 2;

  /// Largura útil de cada destino da barra inferior — margem da chrome,
  /// respiro até a busca, busca e respiro interno da barra descontados.
  /// Invariante: nunca abaixo de 44dp em nenhuma largura de telefone.
  static double bottomBarSlot(double width) {
    final double gutters = 2 * edgeInset(width) + barActionGap(width);
    final double chrome = AppSpacing.searchFab + barInnerInset;
    return (width - gutters - chrome) / maxDestinations;
  }
}

/// Contador de badge da navegação, com limite visual.
class AppNavBadge extends StatelessWidget {
  const AppNavBadge({super.key, required this.count, this.limit = 99});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final String label = count > limit ? '$limit+' : '$count';
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: AppSpacing.lg),
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
    );
  }
}

/// Um destino: ícone (contorno/preenchido), rótulo, badge, foco visível e
/// alvo de toque de 48dp. Público para os testes medirem estado selecionado.
class AppNavItem extends StatefulWidget {
  const AppNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    this.layout = AppNavItemLayout.stacked,
    this.showLabel = true,
    this.isTab = true,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final AppNavItemLayout layout;

  /// No modo recolhido o rótulo some do visual, mas continua no rótulo
  /// acessível (leitor de tela e alvo de toque rotulado).
  final bool showLabel;

  /// `false` para ações que moram na mesma faixa (ex.: busca): elas não são
  /// abas, então não entram no grupo mutuamente exclusivo nem anunciam
  /// "não selecionado".
  final bool isTab;

  @override
  State<AppNavItem> createState() => _AppNavItemState();
}

class _AppNavItemState extends State<AppNavItem> {
  bool _focused = false;
  bool _hovered = false;

  void _setFocused(bool value) {
    if (_focused != value && mounted) {
      setState(() => _focused = value);
    }
  }

  void _setHovered(bool value) {
    if (_hovered != value && mounted) {
      setState(() => _hovered = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tone = widget.selected
        ? context.colors.textPrimary
        : context.colors.textTertiary;
    final String badgeSuffix = widget.destination.badgeCount > 0
        ? ', ${context.l10n.navBadgeCount(widget.destination.badgeCount)}'
        : '';
    final String accessibleLabel = '${widget.destination.label}$badgeSuffix';

    final Widget icon = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(
          widget.selected
              ? widget.destination.activeIcon
              : widget.destination.icon,
          size: AppSpacing.navIconSize,
          color: tone,
        ),
        if (widget.destination.badgeCount > 0)
          Positioned(
            top: -AppSpacing.xs,
            right: -AppSpacing.sm,
            child: AppNavBadge(count: widget.destination.badgeCount),
          ),
      ],
    );

    final Widget label = Text(
      widget.destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.layout == AppNavItemLayout.inline
          ? TextAlign.start
          : TextAlign.center,
      style: context.texts.labelSmall?.copyWith(
        color: tone,
        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    final Widget stackedVisuals = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        icon,
        const SizedBox(height: AppSpacing.hairline),
        if (widget.showLabel)
          // Elástico no texto 2.0: o rótulo encolhe em vez de estourar a
          // altura (que já cresce) da barra.
          FittedBox(fit: BoxFit.scaleDown, child: label),
      ],
    );
    final Widget visuals = widget.layout == AppNavItemLayout.inline
        ? Row(
            children: <Widget>[
              icon,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: label),
            ],
          )
        : stackedVisuals;

    return Semantics(
      // Nó próprio: o leitor de tela anuncia "aba, 3 de 5, selecionada" em vez
      // de fundir o destino com os vizinhos.
      container: true,
      selected: widget.isTab ? widget.selected : null,
      inMutuallyExclusiveGroup: widget.isTab,
      button: true,
      label: accessibleLabel,
      // A ação fica no nó externo: o visual interno é excluído da árvore
      // semântica (o rótulo já é anunciado aqui), então sem este `onTap` o
      // TalkBack não conseguiria ativar o destino.
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          onShowFocusHighlight: _setFocused,
          onShowHoverHighlight: _setHovered,
          mouseCursor: SystemMouseCursors.click,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: Pressable(
            onTap: widget.onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                // Mouse no desktop: realce sutil no hover, sem competir com a
                // pílula do destino ativo.
                color: _hovered && !widget.selected
                    ? context.colors.glassStrong.withValues(alpha: 0.45)
                    : AppContentColors.transparent,
                border: Border.all(
                  color: _focused
                      ? context.colors.accent
                      : AppContentColors.transparent,
                  width: AppSpacing.hairline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Center(
                  child: widget.showLabel
                      ? visuals
                      // Sidebar recolhida: sem rótulo no pixel, o mouse ganha
                      // o nome no tooltip (o leitor de tela já tem o Semantics).
                      : Tooltip(
                          message: widget.destination.label,
                          child: visuals,
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

/// Fundo do item selecionado no rail/sidebar (pílula que anima ao trocar).
class AppNavPill extends StatelessWidget {
  const AppNavPill({super.key, required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.indicator),
      curve: AppMotion.emphasized,
      decoration: BoxDecoration(
        color: selected
            ? context.colors.glassStrong
            : AppContentColors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: selected
              ? context.colors.glassBorder
              : AppContentColors.transparent,
        ),
      ),
      child: child,
    );
  }
}

/// Barra inferior de vidro (telefone): indicador deslizante + 5 destinos.
class AppNavBottomBar extends StatelessWidget {
  // Não é `const`: o teto de 5 destinos é verificado por `assert` sobre
  // `length`, que não é avaliável em expressão constante — assim o contrato
  // vale em runtime e ninguém tropeça numa invocação `const` que não compila.
  AppNavBottomBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  }) : assert(destinations.length <= AppNav.maxDestinations);

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // A fonte do sistema não espreme o rótulo: a barra cresce.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double requested = scaler.scale(1.0);
    final double scale = requested.clamp(1.0, 2.0);
    final double height = AppSpacing.navBarHeight + (scale - 1) * AppSpacing.xl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSpacing.glassBlur,
          sigmaY: AppSpacing.glassBlur,
        ),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: context.colors.glassFloating,
            border: Border.all(color: context.colors.glassBorder),
            boxShadow: context.colors.floatingShadow,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double slot = constraints.maxWidth / destinations.length;
              return Stack(
                // Expand: os destinos herdam a altura toda da barra (alvo de
                // toque de 60dp) em vez de encolher para o tamanho do ícone.
                fit: StackFit.expand,
                children: <Widget>[
                  AnimatedPositioned(
                    duration: AppMotion.of(context, AppMotion.indicator),
                    curve: AppMotion.emphasized,
                    left: currentIndex * slot,
                    top: 0,
                    bottom: 0,
                    width: slot,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          color: context.colors.glassStrong,
                          border: Border.all(color: context.colors.glassBorder),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < destinations.length;
                        index += 1
                      )
                        Expanded(
                          child: AppNavItem(
                            destination: destinations[index],
                            selected: currentIndex == index,
                            onTap: () => onSelect(index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Rail vertical (tablet): marca no topo, destinos com rótulo, busca no pé.
class AppNavRail extends StatelessWidget {
  // Não é `const` (mesmo motivo de [AppNavBottomBar]).
  AppNavRail({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    this.onSearch,
    this.searchLabel,
  }) : assert(destinations.length <= AppNav.maxDestinations);

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Ação de busca (não é destino): substitui o botão flutuante do telefone.
  final VoidCallback? onSearch;
  final String? searchLabel;

  @override
  Widget build(BuildContext context) {
    final String? search = searchLabel;
    return Container(
      width: AppSpacing.navRailWidth,
      decoration: BoxDecoration(
        color: context.colors.glass,
        border: Border(right: BorderSide(color: context.colors.glassBorder)),
      ),
      // right: false — a borda direita encosta no conteúdo, não na tela.
      // O inset inferior fica: em paisagem/3 botões a busca e a conta não
      // podem cair sob a barra do sistema.
      child: SafeArea(
        right: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.lg),
            const PortixMark(size: AppSpacing.xxxl),
            const SizedBox(height: AppSpacing.sm),
            // Rolável: em paisagem (ou janela baixa) os destinos continuam
            // alcançáveis em vez de estourar a coluna.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                children: <Widget>[
                  for (int index = 0; index < destinations.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      child: AppNavPill(
                        selected: currentIndex == index,
                        child: SizedBox(
                          height: AppSpacing.navItemHeight,
                          child: AppNavItem(
                            destination: destinations[index],
                            selected: currentIndex == index,
                            onTap: () => onSelect(index),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onSearch != null && search != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                child: AppNavPill(
                  selected: false,
                  child: SizedBox(
                    height: AppSpacing.navItemHeight,
                    child: AppNavItem(
                      destination: AppNavDestination(
                        icon: Icons.search_rounded,
                        activeIcon: Icons.search_rounded,
                        label: search,
                      ),
                      selected: false,
                      isTab: false,
                      onTap: onSearch!,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Sidebar recolhível (desktop): marca, destinos com rótulo, busca e a conta
/// no pé (o widget de conta vem da casca, que conhece os providers).
class AppNavSidebar extends StatefulWidget {
  // Não é `const` (mesmo motivo de [AppNavBottomBar]).
  AppNavSidebar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    this.onSearch,
    this.searchLabel,
    this.footer,
    this.initiallyCollapsed = false,
  }) : assert(destinations.length <= AppNav.maxDestinations);

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSearch;
  final String? searchLabel;

  /// Rodapé livre (ex.: cartão de conta com o avatar em cache).
  final Widget? footer;
  final bool initiallyCollapsed;

  @override
  State<AppNavSidebar> createState() => _AppNavSidebarState();
}

class _AppNavSidebarState extends State<AppNavSidebar> {
  late bool _collapsed = widget.initiallyCollapsed;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String? search = widget.searchLabel;
    final double width = _collapsed
        ? AppSpacing.navSidebarCollapsedWidth
        : AppSpacing.navSidebarWidth;

    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.base),
      curve: AppMotion.out,
      width: width,
      decoration: BoxDecoration(
        color: context.colors.glass,
        border: Border(right: BorderSide(color: context.colors.glassBorder)),
      ),
      // Mesmo critério do rail: o inset inferior protege o cartão de conta.
      child: SafeArea(
        right: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  if (!_collapsed) ...<Widget>[
                    const PortixMark(size: AppSpacing.xxxl),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  GlassCircleButton(
                    icon: _collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    tooltip: _collapsed ? l10n.navExpand : l10n.navCollapse,
                    onTap: _toggle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                children: <Widget>[
                  for (
                    int index = 0;
                    index < widget.destinations.length;
                    index += 1
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      child: AppNavPill(
                        selected: widget.currentIndex == index,
                        child: SizedBox(
                          height: AppSpacing.navItemHeight,
                          child: AppNavItem(
                            destination: widget.destinations[index],
                            selected: widget.currentIndex == index,
                            layout: _collapsed
                                ? AppNavItemLayout.stacked
                                : AppNavItemLayout.inline,
                            showLabel: !_collapsed,
                            onTap: () => widget.onSelect(index),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.onSearch != null && search != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                child: AppNavPill(
                  selected: false,
                  child: SizedBox(
                    height: AppSpacing.navItemHeight,
                    child: AppNavItem(
                      destination: AppNavDestination(
                        icon: Icons.search_rounded,
                        activeIcon: Icons.search_rounded,
                        label: search,
                      ),
                      selected: false,
                      isTab: false,
                      layout: _collapsed
                          ? AppNavItemLayout.stacked
                          : AppNavItemLayout.inline,
                      showLabel: !_collapsed,
                      onTap: widget.onSearch!,
                    ),
                  ),
                ),
              ),
            if (widget.footer != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: widget.footer,
              ),
          ],
        ),
      ),
    );
  }
}
