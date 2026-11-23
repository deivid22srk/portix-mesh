import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import '../../models/home_feed.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/states.dart';
import 'feed_impressions.dart';

/// Métricas das linhas horizontais (grid 4/8: 150×200 é 3:4 do card).
class FeedMetrics {
  const FeedMetrics._();

  static const double rowCardWidth = 150;

  /// Altura da faixa: a capa (150·4/3 = 200) mais folga para a animação de
  /// entrada (`RevealOnMount` desliza de baixo para cima) sem recortar.
  static const double rowHeight = 216;

  /// Raio/altura do chip de categoria — alvo de toque confortável (≥48).
  static const double chipMinHeight = AppSpacing.circleButton;
}

/// Título localizado de uma seção do feed novo (e dos legados do fallback).
String feedSectionTitle(L10n l10n, HomeFeedSection section) {
  switch (section.key) {
    case 'featured':
      return l10n.sectionFeatured;
    case 'for_you':
      return l10n.sectionForYou;
    case 'trending':
      return l10n.sectionTrending;
    case 'new_releases':
      return l10n.sectionNewReleases;
    case 'recently_updated':
      return l10n.sectionRecentlyUpdated;
    case 'discover':
      return l10n.sectionDiscover;
    case 'top_rated':
      return l10n.sectionTopRated;
    case 'free':
      return l10n.sectionFree;
    case 'classics':
      return l10n.sectionClassics;
  }
  // Categorias usam o próprio título (nome do gênero).
  return section.title ?? l10n.sectionByCategory;
}

/// Microcopy secundária: "Porque você curte o gênero" nas seções
/// personalizadas.
String? feedSectionSubtitle(L10n l10n, HomeFeedSection section) {
  final FeedSectionReason? reason = section.reason;
  if (section.key == 'for_you' && reason != null && reason.kind == 'genre') {
    return l10n.sectionForYouReason(reason.value);
  }
  return null;
}

/// Selo do card ("NOVO"/"ATUALIZADO"); `null` quando não se aplica.
Widget? feedCardBadge(BuildContext context, Game game) {
  final L10n l10n = context.l10n;
  if (game.isNew) {
    return BadgeChip(
      label: l10n.badgeNew,
      color: context.colors.accentAlt,
      icon: Icons.auto_awesome_rounded,
    );
  }
  if (game.isUpdated) {
    return BadgeChip(
      label: l10n.badgeUpdated,
      color: context.colors.accent,
      icon: Icons.update_rounded,
    );
  }
  return null;
}

/// Chip de categoria (gênero/plataforma) com alvo de toque ≥48dp.
class FeedChip extends StatelessWidget {
  const FeedChip({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: FeedMetrics.chipMinHeight),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: context.colors.glass,
            border: Border.all(color: context.colors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: context.colors.accent),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: context.texts.labelLarge?.copyWith(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa horizontal de cards com cabeçalho de seção ("Ver tudo").
class FeedSectionRow extends StatelessWidget {
  const FeedSectionRow({
    super.key,
    required this.section,
    required this.tracker,
    this.sessionId,
    this.heroPrefix = 'home',
    this.actionLabel,
    this.onAction,
  });

  final HomeFeedSection section;
  final FeedImpressionTracker tracker;
  final String? sessionId;
  final String heroPrefix;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHeader(
          title: feedSectionTitle(l10n, section),
          subtitle: feedSectionSubtitle(l10n, section),
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        SizedBox(
          height: FeedMetrics.rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            itemCount: section.items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final Game game = section.items[index];
              return FeedImpressionProbe(
                key: ValueKey<String>('probe-${section.key}-${game.id}'),
                tracker: tracker,
                gameId: game.id,
                section: section.key,
                sessionId: sessionId,
                // Align solta a altura para o card manter 3:4 exato dentro da
                // faixa (que é mais alta para caber a animação de entrada).
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RevealOnMount(
                    index: index,
                    child: GameCard(
                      game: game,
                      width: FeedMetrics.rowCardWidth,
                      heroTag: '$heroPrefix-${section.key}-${game.id}',
                      badge: feedCardBadge(context, game),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Grade de descoberta (sliver) com cards, selos e impressões.
class FeedGrid extends StatelessWidget {
  const FeedGrid({
    super.key,
    required this.items,
    required this.tracker,
    required this.sectionKey,
    this.sessionId,
    this.heroPrefix = 'home',
  });

  final List<Game> items;
  final FeedImpressionTracker tracker;
  final String sectionKey;
  final String? sessionId;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCoverGrid(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final Game game = items[index];
        return FeedImpressionProbe(
          key: ValueKey<String>('probe-$sectionKey-${game.id}'),
          tracker: tracker,
          gameId: game.id,
          section: sectionKey,
          sessionId: sessionId,
          child: RevealOnMount(
            index: index,
            child: GameCard(
              game: game,
              heroTag: '$heroPrefix-grid-${game.id}',
              badge: feedCardBadge(context, game),
            ),
          ),
        );
      },
    );
  }
}

/// Faixa de chips (gêneros primeiro, depois plataformas) com rolagem lateral.
class FeedCategoryChips extends StatelessWidget {
  const FeedCategoryChips({
    super.key,
    required this.genres,
    required this.platforms,
    required this.onGenre,
    required this.onPlatform,
  });

  final List<GenreInfo> genres;
  final List<PlatformInfo> platforms;
  final ValueChanged<String> onGenre;
  final ValueChanged<String> onPlatform;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      for (final GenreInfo genre in genres)
        FeedChip(label: genre.name, onTap: () => onGenre(genre.name)),
      for (final PlatformInfo platform in platforms)
        FeedChip(
          label: platform.name,
          icon: Icons.sports_esports_rounded,
          onTap: () => onPlatform(platform.slug),
        ),
    ];
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: FeedMetrics.chipMinHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: chips.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => chips[index],
      ),
    );
  }
}

/// Estado de erro do feed: offline, limite de requisições ou genérico —
/// sempre com ação "Tentar novamente".
class FeedErrorState extends StatelessWidget {
  const FeedErrorState({super.key, required this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final FailureKind? kind = error is AppFailure
        ? (error as AppFailure).kind
        : null;
    switch (kind) {
      case FailureKind.network:
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.feedOfflineTitle,
          body: l10n.errorNetwork,
          actionLabel: l10n.tryAgain,
          actionIcon: Icons.refresh_rounded,
          onAction: onRetry,
        );
      case FailureKind.rateLimited:
        return EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: l10n.feedRateLimitTitle,
          body: l10n.feedRateLimitBody,
          actionLabel: l10n.tryAgain,
          actionIcon: Icons.refresh_rounded,
          onAction: onRetry,
        );
      default:
        return ErrorStateView(
          message: context.failureText(error),
          retryLabel: l10n.tryAgain,
          onRetry: onRetry,
        );
    }
  }
}
