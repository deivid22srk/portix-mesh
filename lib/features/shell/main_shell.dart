import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/theme/chrome.dart';
import '../../core/theme/tokens.dart';
import '../../models/download_task.dart';
import '../../models/profile.dart';
import '../../shared/widgets/app_nav.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../downloads/downloads_controller.dart';
import '../home/update_dialog.dart';
import '../menu/settings_categories.dart';
import '../profile/profile_controller.dart';
import 'tab_scroll_registry.dart';

// ============================================================================
// Casca principal.
//
// Responsabilidade única: manter as cinco abas vivas (StatefulShellRoute.
// indexedStack) e colocar a navegação principal na forma certa para a largura
// atual — barra inferior no telefone, rail no tablet, sidebar recolhível no
// desktop. A casca é a dona do inset da chrome: publica via AppChromeScope
// quanto cada tela deve reservar no fim do scroll, então nenhuma tela cobre
// conteúdo nem sobra espaço morto quando a navegação está na lateral.
// ============================================================================
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final double width = MediaQuery.sizeOf(context).width;
    final AppNavMode mode = AppNav.modeFor(width);
    // Telefone estreito: a margem lateral encolhe antes do alvo de toque —
    // a 320dp cada destino ainda fica com 45dp (ver AppNav.bottomBarSlot).
    final double edge = AppNav.edgeInset(width);
    // Teclado aberto: a barra inferior sai de cena em vez de subir e cobrir o
    // campo em foco.
    final bool keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int current = navigationShell.currentIndex;
    // `select` evita reconstruir a casca a cada tick de progresso: só o
    // CONTADOR de downloads ativos interessa ao badge.
    final int activeDownloads = ref.watch(
      downloadsProvider.select(
        (List<DownloadTask> tasks) =>
            tasks.where((DownloadTask task) => task.isActive).length,
      ),
    );

    final List<AppNavDestination> destinations = <AppNavDestination>[
      AppNavDestination(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l10n.navHome,
      ),
      AppNavDestination(
        icon: Icons.sports_esports_outlined,
        activeIcon: Icons.sports_esports_rounded,
        label: l10n.navExplore,
      ),
      AppNavDestination(
        icon: Icons.article_outlined,
        activeIcon: Icons.article_rounded,
        label: l10n.navNews,
      ),
      AppNavDestination(
        icon: Icons.layers_outlined,
        activeIcon: Icons.layers_rounded,
        label: l10n.navHub,
        badgeCount: activeDownloads,
      ),
      AppNavDestination(
        icon: Icons.menu_rounded,
        activeIcon: Icons.menu_rounded,
        label: l10n.navMenu,
      ),
    ];

    void select(int index) {
      if (index == current) {
        // Re-toque na aba ativa: volta ao topo e à raiz da pilha daquela aba.
        ref
            .read(tabScrollRegistryProvider)
            .toTop(
              AppTab.values[index],
              duration: AppMotion.of(context, AppMotion.base),
            );
      }
      navigationShell.goBranch(index, initialLocation: index == current);
    }

    void openSearch() => context.push<Object?>('/search');

    final Widget pages = AppChromeScope(
      navMode: mode,
      bottomPadding: mode == AppNavMode.bottom
          ? context.systemBottomInset + AppSpacing.navContentReserve
          : context.systemBottomInset + AppSpacing.snackbarBottomGap,
      child: TabScrollScope(
        registry: ref.read(tabScrollRegistryProvider),
        child: Stack(children: <Widget>[navigationShell, const UpdateGate()]),
      ),
    );

    if (mode == AppNavMode.bottom) {
      return Scaffold(
        extendBody: true,
        backgroundColor: AppContentColors.transparent,
        body: AppBackdrop(child: pages),
        // Teclado aberto: a barra sai de cena de vez (não apenas desliza) para
        // o Scaffold devolver a altura ao corpo — deslizar deixaria 68dp
        // reservados acima do teclado, espremendo o campo em foco.
        bottomNavigationBar: keyboardVisible
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  edge,
                  0,
                  edge,
                  context.systemBottomInset + AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AppNavBottomBar(
                        destinations: destinations,
                        currentIndex: current,
                        onSelect: select,
                      ),
                    ),
                    SizedBox(width: AppNav.barActionGap(width)),
                    SearchFab(tooltip: l10n.tooltipSearch, onTap: openSearch),
                  ],
                ),
              ),
      );
    }

    final Widget navigation = mode == AppNavMode.rail
        ? AppNavRail(
            destinations: destinations,
            currentIndex: current,
            onSelect: select,
            onSearch: openSearch,
            searchLabel: l10n.tooltipSearch,
          )
        : AppNavSidebar(
            destinations: destinations,
            currentIndex: current,
            onSelect: select,
            onSearch: openSearch,
            searchLabel: l10n.tooltipSearch,
            footer: const AccountTile(),
          );

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: Row(
          children: <Widget>[
            navigation,
            Expanded(child: pages),
          ],
        ),
      ),
    );
  }
}

/// Cartão de conta no pé da sidebar: reaproveita o avatar em cache
/// ([ProfileAvatar] → CachedNetworkImage) e abre as configurações de conta.
class AccountTile extends ConsumerWidget {
  const AccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AccountState account = ref.watch(accountProvider);
    final UserProfile profile =
        ref.watch(profileProvider).value ??
        UserProfile(id: account.id ?? '', displayName: account.displayName);
    final String? adminLevel = ref.watch(adminLevelProvider).value;
    final String name = profile.displayName.isEmpty
        ? l10n.player
        : profile.displayName;
    final String? handle = profile.handle;
    final String secondary =
        account.email ?? (handle == null || handle.isEmpty ? '' : '@$handle');

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Sidebar recolhida: só o avatar cabe — nada de texto espremido.
        final bool compact =
            constraints.maxWidth < AppSpacing.navSidebarCollapsedWidth;
        return Semantics(
          container: true,
          // Abre as configurações de conta: papel de botão para o leitor de
          // tela (o nome/e-mail interno já são lidos).
          button: true,
          child: GlassContainer(
            radius: AppRadii.lg,
            padding: const EdgeInsets.all(AppSpacing.sm),
            onTap: () => context.go('/menu/$kSettingsAccount'),
            child: ConstrainedBox(
              // Alvo mínimo de toque: com só o avatar (sem e-mail/@handle na
              // conta) o cartão ficava com 40dp de altura.
              constraints: const BoxConstraints(
                minHeight: AppSpacing.circleButton,
              ),
              child: Row(
                children: <Widget>[
                  ProfileAvatar(
                    name: name,
                    imageUrl: profile.coverUrl,
                    size: AppSpacing.xxl,
                    level: adminLevel,
                  ),
                  // O nome aparece sempre que há espaço; e-mail/@handle só
                  // quando a conta tem um (convidado não fica com linha vazia).
                  if (!compact)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.labelLarge,
                            ),
                            if (secondary.isNotEmpty)
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.labelSmall?.copyWith(
                                  color: context.colors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
