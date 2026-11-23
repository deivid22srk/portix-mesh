import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../models/news.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/news_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/user_avatar_action.dart';
import '../news/news_controller.dart';
import '../shell/tab_scroll_registry.dart';

class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});

  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage> {
  // Controlador da aba (ver tab_scroll_registry): preserva a posição e permite
  // o re-toque voltar ao topo.
  late final ScrollController _scroll = ref
      .read(tabScrollRegistryProvider)
      .controllerFor(AppTab.news);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        ref.read(newsControllerProvider.notifier).ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(newsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final NewsState state = ref.watch(newsControllerProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: context.colors.accent,
        backgroundColor: context.colors.glassStrong,
        onRefresh: () => ref.read(newsControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            AppHeaderSliver(
              title: l10n.newsTitle,
              subtitle: l10n.newsSubtitle,
              trailing: const UserAvatarAction(),
            ),
            if (state.isInitialLoading)
              const SliverToBoxAdapter(child: _NewsSkeleton()),
            if (state.status == NewsStatus.error && state.items.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 380,
                  child: ErrorStateView(
                    message: context.failureText(state.error),
                    retryLabel: l10n.tryAgain,
                    onRetry: () =>
                        ref.read(newsControllerProvider.notifier).refresh(),
                  ),
                ),
              ),
            if (state.status == NewsStatus.empty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 380,
                  child: EmptyState(
                    icon: Icons.article_outlined,
                    title: l10n.newsEmpty,
                    body: l10n.newsEmptyBody,
                  ),
                ),
              ),
            if (state.items.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  context.bottomChromePadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    final NewsItem item = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _NewsCard(
                        // O primeiro card é o destaque do feed: capa maior.
                        item: item,
                        featured: index == 0,
                      ),
                    );
                  }, childCount: state.items.length),
                ),
              ),
            if (state.isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: context.bottomChromePadding),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto do feed: dois cards grandes pulsando enquanto carrega.
class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: Column(
          children: <Widget>[
            for (int index = 0; index < 2; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.colors.bgElevated,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: context.colors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ColoredBox(color: context.colors.glassStrong),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _bar(context, width: 64, height: 10),
                            const SizedBox(height: AppSpacing.md),
                            _bar(context, width: double.infinity, height: 16),
                            const SizedBox(height: AppSpacing.xxs),
                            _bar(context, width: 180, height: 16),
                            const SizedBox(height: AppSpacing.md),
                            _bar(context, width: 90, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.glassStrong,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

/// Card de notícia: capa retangular no topo e área escura com categoria,
/// título e tempo de publicação.
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, this.featured = false});

  final NewsItem item;

  /// O primeiro card do feed ganha capa um pouco mais alta e título maior.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final TextStyle? titleStyle =
        (featured ? context.texts.titleLarge : context.texts.titleMedium)
            ?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            );

    return Pressable(
      onTap: () => context.push<Object?>('/news/${item.slug}', extra: item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: context.colors.glassBorder),
          boxShadow: context.colors.glassShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: featured ? 16 / 10 : 16 / 9,
              child: NewsCover(item: item),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.category.toUpperCase(),
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        relativeDay(item.publishedAt, en: l10n.isEn),
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
