import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_header.dart';
import '../../models/game.dart';
import '../../models/home_feed.dart';
import '../../models/search.dart';
import '../../models/user_result.dart';
import '../../shared/widgets/filter_sheet.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/search_widgets.dart';
import '../../shared/widgets/states.dart';
import '../home/home_controller.dart';
import '../profile/profile_controller.dart';
import '../search/search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final ScrollController _scroll = ScrollController();

  int _mode = 0;
  String _usersQuery = '';
  Timer? _usersTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      ref.read(searchControllerProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _usersTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/explore');
    }
  }

  void _runQuery(String term) {
    // O campo (SearchField) recebe o texto pelo ECO do estado — a fonte da
    // verdade é o controller, nunca uma cópia local.
    ref.read(searchControllerProvider.notifier).submitQuery(term);
  }

  Future<void> _openFilters(SearchState state, CatalogFacets facets) async {
    final SearchFilters? result = await showFilterSheet(
      context,
      initial: state.filters,
      facets: facets,
    );
    if (result == null || !mounted) {
      return;
    }
    ref.read(searchControllerProvider.notifier).applyFilters(result);
  }

  /// Destrutivo nunca é sem volta: confirmação + undo (mesmo padrão do Hub).
  Future<void> _confirmClearHistory(WidgetRef ref) async {
    final L10n l10n = context.l10n;
    final List<String> removed = ref.read(recentSearchesProvider);
    if (removed.isEmpty) {
      ref.read(recentSearchesProvider.notifier).clear();
      return;
    }
    final bool ok = await showAppConfirm(
      context,
      title: l10n.clearHistory,
      message: l10n.clearHistoryConfirm,
    );
    if (!ok) {
      return;
    }
    if (!mounted) {
      return;
    }
    ref.read(recentSearchesProvider.notifier).clear();
    showAppSnackBar(
      context,
      message: l10n.historyCleared,
      actionLabel: l10n.undo,
      onAction: () =>
          ref.read(recentSearchesProvider.notifier).restoreAll(removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final SearchState state = ref.watch(searchControllerProvider);
    final List<String> recent = ref.watch(recentSearchesProvider);
    final CatalogFacets facets =
        ref.watch(catalogFacetsProvider).value ?? const CatalogFacets();

    ref.listen<SearchState>(searchControllerProvider, (
      SearchState? previous,
      SearchState next,
    ) {
      // Aba "Usuários" acompanha a query com debounce próprio. O ECO do texto
      // no campo vive no SearchField (dono do campo).
      if (next.query != _usersQuery) {
        _usersTimer?.cancel();
        _usersTimer = Timer(const Duration(milliseconds: 320), () {
          if (mounted) {
            setState(() => _usersQuery = next.query);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: AppContentMax(
            child: Column(
              children: <Widget>[
                AppHeaderSearchBar(
                  onBack: _close,
                  field: Semantics(
                    header: true,
                    child: Text(
                      l10n.searchTitle,
                      style: context.texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  actions: <AppHeaderAction>[
                    AppHeaderAction(
                      icon: Icons.tune_rounded,
                      active: state.filters.activeCount > 0,
                      tooltip: l10n.filters,
                      onTap: () => _openFilters(state, facets),
                    ),
                  ],
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: <Widget>[
                      // O campo COMPLETO (sugestões instantâneas, Esc, x com
                      // alvo 48dp) mora aqui, no corpo — era da Explorar,
                      // onde não deveria existir; a busca é dona dele agora.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            AppSpacing.md,
                            AppSpacing.screen,
                            0,
                          ),
                          child: SearchField(autofocus: true),
                        ),
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
                              SegmentedControl<int>(
                                items: <SegmentItem<int>>[
                                  SegmentItem<int>(
                                    value: 0,
                                    label: l10n.searchTabGames,
                                  ),
                                  SegmentItem<int>(
                                    value: 1,
                                    label: l10n.searchTabUsers,
                                  ),
                                ],
                                value: _mode,
                                onChanged: (int value) =>
                                    setState(() => _mode = value),
                              ),
                              if (state.filters.activeCount > 0) ...<Widget>[
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: _activeFilters(
                                    context,
                                    state,
                                    facets,
                                  ),
                                ),
                              ],
                              if (state.query.isEmpty &&
                                  recent.isNotEmpty) ...<Widget>[
                                const SizedBox(height: AppSpacing.xl),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.history_rounded,
                                      size: 15,
                                      color: context.colors.textTertiary,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        l10n.recentSearches,
                                        style: context.texts.labelMedium
                                            ?.copyWith(
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                      ),
                                    ),
                                    Pressable(
                                      onTap: () => _confirmClearHistory(ref),
                                      child: Text(
                                        l10n.clearHistory,
                                        style: context.texts.labelSmall
                                            ?.copyWith(
                                              color: context.colors.accent,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: <Widget>[
                                    for (final String term in recent)
                                      AppPill(
                                        label: term,
                                        dense: true,
                                        onTap: () => _runQuery(term),
                                      ),
                                  ],
                                ),
                              ],
                              if (state.query.isEmpty &&
                                  facets.genres.isNotEmpty) ...<Widget>[
                                const SizedBox(height: AppSpacing.xl),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 15,
                                      color: context.colors.accent,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        l10n.sectionGenres,
                                        style: context.texts.labelMedium
                                            ?.copyWith(
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: <Widget>[
                                    for (final GenreInfo genre
                                        in facets.genres.take(8))
                                      AppPill(
                                        label: genre.name,
                                        dense: true,
                                        onTap: () => ref
                                            .read(
                                              searchControllerProvider.notifier,
                                            )
                                            .applyFilters(
                                              state.filters.copyWith(
                                                genre: genre.name,
                                              ),
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ),
                      if (_mode == 0 && state.isInitialLoading)
                        const SliverToBoxAdapter(child: SearchSkeleton()),
                      if (_mode == 0 &&
                          state.status == SearchStatus.error &&
                          state.items.isEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 380,
                            child: ErrorStateView(
                              message: context.failureText(state.error),
                              retryLabel: l10n.tryAgain,
                              onRetry: () => ref
                                  .read(searchControllerProvider.notifier)
                                  .refresh(),
                            ),
                          ),
                        ),
                      if (_mode == 0 && state.status == SearchStatus.empty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 380,
                            child: EmptyState(
                              icon: Icons.search_off_rounded,
                              title: l10n.noResultsTitle,
                              body: l10n.noResultsBody,
                              actionLabel: state.filters.isDefault
                                  ? null
                                  : l10n.reset,
                              actionIcon: Icons.filter_alt_off_rounded,
                              onAction: state.filters.isDefault
                                  ? null
                                  : () => ref
                                        .read(searchControllerProvider.notifier)
                                        .resetFilters(),
                            ),
                          ),
                        ),
                      if (_mode == 0 && state.items.isNotEmpty) ...<Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.screen + 2,
                              0,
                              AppSpacing.screen,
                              AppSpacing.md,
                            ),
                            child: Text(
                              l10n.resultsCount(state.total),
                              style: context.texts.labelMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        ResponsiveCoverGrid(
                          itemBuilder: (BuildContext context, int index) {
                            final Game game = state.items[index];
                            return RevealOnMount(
                              index: index,
                              child: GameCard(
                                game: game,
                                heroTag: 'search-${game.id}',
                              ),
                            );
                          },
                          itemCount: state.items.length,
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.screen,
                              AppSpacing.xl,
                              AppSpacing.screen,
                              context.systemBottomInset + AppSpacing.xxl,
                            ),
                            child: Center(
                              child: state.isLoadingMore
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.colors.accent,
                                      ),
                                    )
                                  : state.hasMore
                                  ? SecondaryButton(
                                      label: l10n.seeAll,
                                      icon: Icons.expand_more_rounded,
                                      expand: false,
                                      onPressed: () => ref
                                          .read(
                                            searchControllerProvider.notifier,
                                          )
                                          .loadMore(),
                                    )
                                  : Text(
                                      '— PORTIX —',
                                      style: context.texts.labelSmall?.copyWith(
                                        color: context.colors.textTertiary,
                                        letterSpacing: 3,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                      if (_mode == 1) _UsersResults(query: _usersQuery),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _activeFilters(
    BuildContext context,
    SearchState state,
    CatalogFacets facets,
  ) {
    final L10n l10n = context.l10n;
    final List<Widget> chips = <Widget>[];
    final String? platform = state.filters.platform;
    if (platform != null) {
      String name = platform;
      for (final PlatformInfo item in facets.platforms) {
        if (item.slug == platform) {
          name = item.name;
        }
      }
      chips.add(
        _ActiveChip(
          label: name,
          onTap: () => ref
              .read(searchControllerProvider.notifier)
              .applyFilters(state.filters.copyWith(clearPlatform: true)),
        ),
      );
    }
    final String? genre = state.filters.genre;
    if (genre != null) {
      chips.add(
        _ActiveChip(
          label: genre,
          onTap: () => ref
              .read(searchControllerProvider.notifier)
              .applyFilters(state.filters.copyWith(clearGenre: true)),
        ),
      );
    }
    if (state.filters.freeOnly) {
      chips.add(
        _ActiveChip(
          label: l10n.filterFree,
          onTap: () => ref
              .read(searchControllerProvider.notifier)
              .applyFilters(state.filters.copyWith(freeOnly: false)),
        ),
      );
    }
    if (state.filters.needsRom) {
      chips.add(
        _ActiveChip(
          label: l10n.filterRom,
          onTap: () => ref
              .read(searchControllerProvider.notifier)
              .applyFilters(state.filters.copyWith(needsRom: false)),
        ),
      );
    }
    if (state.filters.sort != 'trending') {
      chips.add(
        _ActiveChip(
          label: filterSortLabel(l10n, state.filters.sort),
          onTap: () => ref
              .read(searchControllerProvider.notifier)
              .applyFilters(state.filters.copyWith(sort: 'trending')),
        ),
      );
    }
    return chips;
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: context.colors.accent.withValues(alpha: 0.14),
          border: Border.all(
            color: context.colors.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.close_rounded,
              size: 13,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultados da busca por usuários (por @ ou nome).
class _UsersResults extends ConsumerWidget {
  _UsersResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<List<UserResult>> async = ref.watch(
      userSearchProvider(query),
    );
    final List<UserResult> users = async.value ?? const <UserResult>[];

    if (async.isLoading && users.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.accent,
              ),
            ),
          ),
        ),
      );
    }
    if (users.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 340,
          child: EmptyState(
            icon: Icons.person_search_rounded,
            title: l10n.usersEmpty,
            body: l10n.searchUsersHint,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.xxxl,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _UserTile(user: users[index]),
          ),
          childCount: users.length,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final UserResult user;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push<Object?>('/u/${user.id}'),
      child: Row(
        children: <Widget>[
          ProfileAvatar(
            name: user.displayName,
            imageUrl: user.coverUrl,
            size: 44,
            level: user.level,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.hairline),
                Text(
                  user.handle == null ? l10n.noHandle : '@${user.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
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
