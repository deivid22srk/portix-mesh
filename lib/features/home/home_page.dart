import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import '../../models/home_feed.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/hero_carousel.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/user_avatar_action.dart';
import '../search/search_controller.dart';
import '../shell/tab_scroll_registry.dart';
import 'feed_impressions.dart';
import 'feed_sections.dart';
import 'home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// Distância (px) do fim em que a próxima página de `discover` é pedida.
  static const double _loadMoreThreshold = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeFeed> async = ref.watch(homeFeedProvider);
    final HomeFeed? feed = async.value;
    final HomeDiscoverState more = ref.watch(homeDiscoverProvider);
    final FeedImpressionTracker tracker = ref.watch(feedImpressionsProvider);

    final HomeFeedSection? discover = feed?.sectionByKey('discover');
    final Map<String, dynamic>? discoverCursor =
        more.cursor ?? discover?.cursor;
    final bool hasMoreDiscover =
        discover != null && !more.ended && discoverCursor != null;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: context.colors.accent,
        backgroundColor: context.colors.glassStrong,
        onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (feed != null) {
              // Reavalia os cards que entraram no viewport durante a rolagem.
              tracker.scan();
            }
            final ScrollMetrics metrics = notification.metrics;
            if (hasMoreDiscover &&
                metrics.axis == Axis.vertical &&
                metrics.maxScrollExtent > 0 &&
                metrics.pixels >=
                    metrics.maxScrollExtent - _loadMoreThreshold) {
              // `loadMore` se protege contra reentrância e fim de lista.
              ref.read(homeFeedProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            // Controlador da aba: re-toque no destino ativo volta ao topo.
            controller: TabScrollScope.controllerOf(context, AppTab.home),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              const _HomeHeader(),
              ..._bodySlivers(
                context,
                ref,
                async,
                feed,
                more,
                tracker,
                hasMoreDiscover,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Corpo da Início, com estados exclusivos: feed > erro > skeleton. A
  /// precedência do erro garante que ele apareça mesmo se o provider reportar
  /// "loading" junto do erro (p.ex. durante um retry).
  List<Widget> _bodySlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<HomeFeed> async,
    HomeFeed? feed,
    HomeDiscoverState more,
    FeedImpressionTracker tracker,
    bool hasMoreDiscover,
  ) {
    if (feed != null) {
      return _feedSlivers(context, ref, feed, more, tracker, hasMoreDiscover);
    }
    if (async.hasError) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: FeedErrorState(
            error: async.error,
            onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
          ),
        ),
      ];
    }
    return const <Widget>[SliverToBoxAdapter(child: HomeSkeleton())];
  }

  List<Widget> _feedSlivers(
    BuildContext context,
    WidgetRef ref,
    HomeFeed feed,
    HomeDiscoverState more,
    FeedImpressionTracker tracker,
    bool hasMoreDiscover,
  ) {
    final L10n l10n = context.l10n;
    final String sessionId = feed.seed;
    final List<Widget> slivers = <Widget>[];

    if (feed.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.explore_rounded,
            title: l10n.feedEmptyTitle,
            body: l10n.feedEmptyBody,
            actionLabel: l10n.tryAgain,
            actionIcon: Icons.refresh_rounded,
            onAction: () => ref.read(homeFeedProvider.notifier).refresh(),
          ),
        ),
      );
      return slivers;
    }

    // 1) Destaques (hero).
    final HomeFeedSection? hero = feed.sectionByKey('featured');
    if (hero != null && hero.items.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: HeroCarousel(
              games: hero.items,
              tagPrefix: 'home',
              showMeta: true,
            ),
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: _Gap(AppSpacing.xxl)));
    }

    // 2) Chips de categoria (gêneros + plataformas).
    final List<GenreInfo> genres = feed.genres.take(12).toList(growable: false);
    final List<PlatformInfo> platforms = <PlatformInfo>[];
    for (final PlatformInfo platform in feed.platforms) {
      if (platform.isSecondary || platforms.length >= 8) {
        continue;
      }
      platforms.add(platform);
    }
    if (genres.isNotEmpty || platforms.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SectionHeader(title: l10n.sectionByCategory),
              FeedCategoryChips(
                genres: genres,
                platforms: platforms,
                onGenre: (String name) => _browse(context, ref, genre: name),
                onPlatform: (String slug) =>
                    _browse(context, ref, platform: slug),
              ),
            ],
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: _Gap(AppSpacing.xxl)));
    }

    // 3) Seções em carrossel horizontal (ordem do servidor).
    for (final HomeFeedSection section in feed.sections) {
      if (!section.isRow || section.items.isEmpty) {
        continue;
      }
      slivers.add(
        SliverToBoxAdapter(
          child: FeedSectionRow(
            section: section,
            tracker: tracker,
            sessionId: sessionId,
            actionLabel: l10n.seeAll,
            onAction: () => _seeAll(context, ref, section),
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: _Gap(AppSpacing.xxl)));
    }

    // 4) Descoberta (grade com scroll infinito por cursor).
    final HomeFeedSection? discover = feed.sectionByKey('discover');
    if (discover != null) {
      slivers.add(
        SliverToBoxAdapter(child: SectionHeader(title: l10n.sectionDiscover)),
      );
      slivers.add(
        FeedGrid(
          items: _mergeDiscover(discover, more.extra),
          tracker: tracker,
          sectionKey: 'discover',
          sessionId: sessionId,
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: _DiscoverFooter(
            loading: more.loading,
            error: more.error,
            hasMore: hasMoreDiscover,
            onRetry: () => ref.read(homeFeedProvider.notifier).loadMore(),
          ),
        ),
      );
    }

    slivers.add(
      SliverToBoxAdapter(child: SizedBox(height: context.bottomChromePadding)),
    );
    return slivers;
  }

  List<Game> _mergeDiscover(HomeFeedSection section, List<Game> extra) {
    final Set<String> seen = <String>{
      for (final Game game in section.items) game.id,
    };
    final List<Game> merged = List<Game>.of(section.items);
    for (final Game game in extra) {
      if (seen.add(game.id)) {
        merged.add(game);
      }
    }
    return merged;
  }

  /// "Ver tudo" de uma seção: resolve os filtros da seção e navega para a
  /// Explorar. MÉTODO VOID que executa — a versão anterior devolvia um
  /// closure que o call site descartava (`onAction: () => _seeAll(...)`), e o
  /// toque não navegava.
  void _seeAll(BuildContext context, WidgetRef ref, HomeFeedSection section) {
    switch (section.key) {
      case 'new_releases':
      case 'recently_updated':
        _browse(context, ref, sort: 'recent');
        return;
      case 'trending':
      case 'top_rated':
        _browse(context, ref, sort: 'trending');
        return;
      case 'free':
        _browse(context, ref, freeOnly: true);
        return;
      case 'classics':
        _browse(context, ref, sort: 'year');
        return;
    }
    if (section.isCategory) {
      final String genre =
          section.title ?? section.key.substring('category:'.length);
      _browse(context, ref, genre: genre);
      return;
    }
    final FeedSectionReason? reason = section.reason;
    if (section.key == 'for_you' && reason != null && reason.kind == 'genre') {
      _browse(context, ref, genre: reason.value);
      return;
    }
    _browse(context, ref);
  }

  void _browse(
    BuildContext context,
    WidgetRef ref, {
    String? platform,
    String? genre,
    bool freeOnly = false,
    String sort = 'trending',
  }) {
    ref
        .read(searchControllerProvider.notifier)
        .browse(
          platform: platform,
          genre: genre,
          freeOnly: freeOnly,
          sort: sort,
        );
    context.go('/explore');
  }
}

/// Espaçador entre blocos (token de espaçamento, sem número mágico).
class _Gap extends StatelessWidget {
  const _Gap(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

/// Rodapé da grade de descoberta: spinner ao paginar, retry em erro e um
/// respiro quando a lista acabou.
class _DiscoverFooter extends StatelessWidget {
  const _DiscoverFooter({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SecondaryButton(
            label: context.l10n.tryAgain,
            icon: Icons.refresh_rounded,
            expand: false,
            onPressed: onRetry,
          ),
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox(height: hasMore ? AppSpacing.xxxl : AppSpacing.xl);
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return AppHeaderSliver(
      title: l10n.navHome,
      subtitle: l10n.tagline,
      trailing: const UserAvatarAction(),
    );
  }
}
