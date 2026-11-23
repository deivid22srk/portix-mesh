import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/collections.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/user_avatar_action.dart';
import '../collections/collections_controller.dart';
import '../downloads/download_filter.dart';
import '../downloads/downloads_controller.dart';
import '../downloads/downloads_tile.dart';
import '../shell/tab_scroll_registry.dart';

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

enum _HubSegment { favorites, installed, downloads }

class _HubPageState extends ConsumerState<HubPage> {
  _HubSegment _segment = _HubSegment.favorites;
  DownloadFilter _downloadFilter = DownloadFilter.all;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final AsyncValue<Collections> async = ref.watch(collectionsProvider);
    final Collections collections = async.value ?? Collections.empty;
    final List<DownloadTask> tasks = ref.watch(downloadsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: context.colors.accent,
        backgroundColor: context.colors.glassStrong,
        onRefresh: () => ref.read(collectionsProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: TabScrollScope.controllerOf(context, AppTab.hub),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            AppHeaderSliver(
              title: l10n.hubTitle,
              subtitle: l10n.anonymousHint,
              trailing: const UserAvatarAction(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedControl<_HubSegment>(
                      items: <SegmentItem<_HubSegment>>[
                        SegmentItem<_HubSegment>(
                          value: _HubSegment.favorites,
                          label: l10n.segmentCount(
                            l10n.hubFavorites,
                            collections.favorites.length,
                          ),
                          icon: Icons.favorite_rounded,
                        ),
                        SegmentItem<_HubSegment>(
                          value: _HubSegment.installed,
                          label: l10n.segmentCount(
                            l10n.hubInstalled,
                            collections.library.length,
                          ),
                          icon: Icons.download_done_rounded,
                        ),
                        SegmentItem<_HubSegment>(
                          value: _HubSegment.downloads,
                          label: l10n.segmentCount(
                            l10n.hubDownloads,
                            tasks.length,
                          ),
                          icon: Icons.download_rounded,
                        ),
                      ],
                      value: _segment,
                      onChanged: (_HubSegment value) =>
                          setState(() => _segment = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            ..._segmentSlivers(context, l10n, collections, tasks),
          ],
        ),
      ),
    );
  }

  List<Widget> _segmentSlivers(
    BuildContext context,
    L10n l10n,
    Collections collections,
    List<DownloadTask> tasks,
  ) {
    switch (_segment) {
      case _HubSegment.favorites:
        return _gameSlivers(
          context,
          games: collections.favorites,
          prefix: 'hub-fav',
          emptyIcon: Icons.favorite_border_rounded,
          emptyTitle: l10n.wishlistEmpty,
          emptyBody: l10n.wishlistEmptyBody,
        );
      case _HubSegment.installed:
        return _gameSlivers(
          context,
          games: collections.library,
          prefix: 'hub-inst',
          emptyIcon: Icons.download_done_rounded,
          emptyTitle: l10n.libraryEmpty,
          emptyBody: l10n.libraryEmptyBody,
        );
      case _HubSegment.downloads:
        if (tasks.isEmpty) {
          return <Widget>[
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppSpacing.emptyStateViewport,
                child: EmptyState(
                  icon: Icons.download_rounded,
                  title: l10n.downloadEmpty,
                  body: l10n.downloadEmptyBody,
                ),
              ),
            ),
          ];
        }
        return _downloadSlivers(context, l10n, tasks);
    }
  }

  /// Fila de downloads: filtros (ativos/concluídos/falhos), ação de limpar
  /// concluídos e a lista filtrada — a peça central do app.
  List<Widget> _downloadSlivers(
    BuildContext context,
    L10n l10n,
    List<DownloadTask> tasks,
  ) {
    final DownloadsController controller = ref.read(downloadsProvider.notifier);
    final List<DownloadTask> filtered = filterDownloadTasks(
      tasks,
      _downloadFilter,
    );
    final bool hasCompleted = tasks.any((DownloadTask t) => t.isDone);
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.md,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final DownloadFilter filter in DownloadFilter.values)
                AppPill(
                  label: filter.label(l10n),
                  selected: _downloadFilter == filter,
                  dense: true,
                  onTap: () => setState(() => _downloadFilter = filter),
                ),
              if (hasCompleted)
                AppPill(
                  label: l10n.clearCompleted,
                  dense: true,
                  leading: Icon(
                    Icons.delete_sweep_rounded,
                    size: 16,
                    color: context.colors.textSecondary,
                  ),
                  onTap: () => controller.clearCompleted(),
                ),
            ],
          ),
        ),
      ),
      if (filtered.isEmpty)
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.emptyStateViewport,
            child: EmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: l10n.filterEmptyTitle,
              body: l10n.filterEmptyBody,
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            context.bottomChromePadding,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DownloadTile(task: filtered[index]),
              ),
              childCount: filtered.length,
            ),
          ),
        ),
    ];
  }

  List<Widget> _gameSlivers(
    BuildContext context, {
    required List<Game> games,
    required String prefix,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyBody,
  }) {
    if (games.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.emptyStateViewport,
            child: EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              body: emptyBody,
              actionLabel: context.l10n.explore,
              onAction: () => context.go('/explore'),
            ),
          ),
        ),
      ];
    }
    return <Widget>[
      ResponsiveCoverGrid(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          context.bottomChromePadding,
        ),
        itemBuilder: (BuildContext context, int index) {
          final Game game = games[index];
          return RevealOnMount(
            index: index,
            child: GameCard(game: game, heroTag: '$prefix-${game.id}'),
          );
        },
        itemCount: games.length,
      ),
    ];
  }
}
