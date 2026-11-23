import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import 'primitives.dart';

/// Placeholder procedural para capas ausentes/falhas: gradiente + iniciais.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({
    super.key,
    required this.title,
    this.showInitials = true,
  });

  final String title;
  final bool showInitials;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = coverColorsFor(title);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -36,
            right: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    context.colors.accent.withValues(alpha: 0.22),
                    context.colors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          if (showInitials)
            Center(
              child: Text(
                initialsOf(title),
                style: context.texts.displaySmall?.copyWith(
                  color: AppContentColors.onMedia.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Capa de jogo com cache e placeholder.
class GameCover extends StatelessWidget {
  const GameCover({
    super.key,
    required this.title,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.memWidth = 480,
    this.borderRadius = AppRadii.md,
  });

  final String title;
  final String? imageUrl;
  final BoxFit fit;
  final int memWidth;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: url == null
          ? CoverPlaceholder(title: title)
          : CachedNetworkImage(
              imageUrl: url,
              fit: fit,
              memCacheWidth: memWidth,
              fadeInDuration: AppMotion.base,
              fadeOutDuration: AppMotion.fast,
              filterQuality: FilterQuality.medium,
              placeholder: (BuildContext context, String value) =>
                  CoverPlaceholder(title: title),
              errorWidget: (BuildContext context, String value, Object error) =>
                  CoverPlaceholder(title: title),
            ),
    );
  }
}

/// Card de capa 3:4: título na base sobre gradiente + badge no topo.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.width,
    this.heroTag,
    this.onTap,
    this.showStats = true,
    this.aspectRatio = 3 / 4,
    this.badge,
  });

  final Game game;
  final double? width;
  final String? heroTag;
  final VoidCallback? onTap;
  final bool showStats;
  final double aspectRatio;

  /// Selo opcional no canto superior direito (ex.: "NOVO"/"ATUALIZADO").
  final Widget? badge;

  void _open(BuildContext context) {
    context.push<Object?>('/game/${game.slug}', extra: heroTag);
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = RepaintBoundary(
      child: Pressable(
        onTap: onTap ?? () => _open(context),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Hero(
                  tag: heroTag ?? 'card-${game.id}',
                  child: GameCover(
                    imageUrl: game.coverUrl,
                    title: game.title,
                    memWidth: 480,
                    borderRadius: 0,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        AppContentColors.transparent,
                        AppContentColors.scrimSoft,
                        AppContentColors.scrimStrong,
                      ],
                      stops: <double>[0.45, 0.68, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (showStats)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: StatBadge(
                      rating: game.rating,
                      downloads: game.downloadCount,
                    ),
                  ),
                if (badge != null)
                  Positioned(top: 10, right: 10, child: badge!),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    game.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      color: AppContentColors.onMedia,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (width == null) {
      return card;
    }
    return SizedBox(width: width, child: card);
  }
}

/// Linha compacta de jogo (usada em listas de downloads/relatórios).
class GameRow extends StatelessWidget {
  const GameRow({
    super.key,
    required this.game,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  final Game game;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final String meta =
        subtitle ??
        <String>[
          if (game.year != null) game.year.toString(),
          if (game.primaryPlatform.isNotEmpty) game.primaryPlatform,
        ].join(' · ');
    return GlassContainer(
      radius: AppRadii.md,
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 58,
            height: 78,
            child: GameCover(
              imageUrl: game.coverUrl,
              title: game.title,
              memWidth: 180,
              borderRadius: AppRadii.sm,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    if (game.hasRating)
                      RatingLine(rating: game.rating, compact: true)
                    else
                      Text(
                        context.l10n.newGame,
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
