import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import 'game_media.dart';
import 'primitives.dart';

/// Carrossel de destaques 16:9 com parallax leve, indicadores animados e
/// controles de vidro. Autoplay pausável; pré-carrega o próximo banner.
///
/// A arte vem de `game.bannerUrl` (banner horizontal real, mantido no
/// Supabase para os jogos destacados); sem banner, cai para a capa do jogo.
/// O card é inteiro clicável — não há botão de download sobre a arte: o
/// destino (ficha do jogo) já está a um toque de distância.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.games,
    this.tagPrefix = 'carousel',
    this.showMeta = false,
  });

  final List<Game> games;
  final String tagPrefix;

  /// Mostra desenvolvedor e nota sobre o banner (usado na Início redesenhada).
  final bool showMeta;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _index = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _precache(1));
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O feed pode chegar depois (cache → rede) ou ser girado pelo
    // pull-to-refresh: clampa o índice para não apontar além da nova lista.
    if (widget.games.isNotEmpty && _index >= widget.games.length) {
      _index = widget.games.length - 1;
      if (_controller.hasClients) {
        _controller.jumpToPage(_index);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Arte horizontal do card: banner real quando existe, capa como fallback.
  String? _imageOf(Game game) => game.bannerUrl ?? game.coverUrl;

  void _startAutoplay() {
    _timer?.cancel();
    if (widget.games.length < 2 || _paused) {
      return;
    }
    _timer = Timer.periodic(AppMotion.autoplay, (Timer timer) {
      if (!mounted || _paused || !_controller.hasClients) {
        return;
      }
      _controller.animateToPage(
        (_index + 1) % widget.games.length,
        duration: const Duration(milliseconds: 520),
        curve: AppMotion.emphasized,
      );
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _resume() {
    if (!_paused) {
      _startAutoplay();
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _pause();
    } else {
      _startAutoplay();
    }
  }

  void _go(int delta) {
    if (!_controller.hasClients || widget.games.isEmpty) {
      return;
    }
    final int count = widget.games.length;
    // `page` é a verdade durante as animações; `_index` só atualiza no fim —
    // usar só ele encadeava animações em toques rápidos nos vizinhos.
    final int current = _controller.page?.round() ?? _index;
    _controller.animateToPage(
      ((current + delta) % count + count) % count,
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
    );
  }

  void _precache(int index) {
    if (!mounted || index < 0 || index >= widget.games.length) {
      return;
    }
    final String? url = _imageOf(widget.games[index]);
    if (url == null) {
      return;
    }
    precacheImage(CachedNetworkImageProvider(url), context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  _pause();
                } else if (notification is ScrollEndNotification) {
                  _resume();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.games.length,
                onPageChanged: (int index) {
                  setState(() => _index = index);
                  _precache(index + 1);
                },
                itemBuilder: (BuildContext context, int index) {
                  final Game game = widget.games[index];
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      double delta = 0;
                      if (_controller.hasClients &&
                          _controller.position.hasContentDimensions) {
                        delta = (_controller.page ?? _index.toDouble()) - index;
                      }
                      final double scale = (1 - delta.abs() * 0.05).clamp(
                        0.94,
                        1.0,
                      );
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: _CarouselCard(
                        game: game,
                        heroTag: '${widget.tagPrefix}-${game.id}',
                        showMeta: widget.showMeta,
                        onTap: () => context.push<Object?>(
                          '/game/${game.slug}',
                          extra: '${widget.tagPrefix}-${game.id}',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    // Alvo de toque 32x40 (dot em si continua fino): pular
                    // para uma página direto pelos indicadores é preciso
                    // SEM zoom — e sem colidir com os botões de vidro.
                    for (int i = 0; i < widget.games.length; i += 1)
                      Pressable(
                        haptics: false,
                        onTap: () {
                          if (_controller.hasClients) {
                            _controller.animateToPage(
                              i,
                              duration: AppMotion.slow,
                              curve: AppMotion.emphasized,
                            );
                          }
                        },
                        child: SizedBox(
                          width: 32,
                          height: 40,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AppMotion.indicator,
                              curve: AppMotion.emphasized,
                              width: i == _index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                color: i == _index
                                    ? context.colors.textPrimary
                                    : context.colors.textPrimary.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GlassCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: context.l10n.tooltipPrevious,
                onTap: () => _go(-1),
              ),
              const SizedBox(width: AppSpacing.sm),
              GlassCircleButton(
                icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                tooltip: _paused
                    ? context.l10n.tooltipPlayCarousel
                    : context.l10n.tooltipPauseCarousel,
                onTap: _togglePause,
              ),
              const SizedBox(width: AppSpacing.sm),
              GlassCircleButton(
                icon: Icons.chevron_right_rounded,
                tooltip: context.l10n.tooltipNext,
                onTap: () => _go(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({
    required this.game,
    required this.heroTag,
    required this.onTap,
    this.showMeta = false,
  });

  final Game game;
  final String heroTag;
  final VoidCallback onTap;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Hero(
              tag: heroTag,
              child: GameCover(
                imageUrl: game.bannerUrl ?? game.coverUrl,
                title: game.title,
                memWidth: 1200,
                borderRadius: 0,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppContentColors.scrim.withValues(alpha: 0.24),
                    AppContentColors.transparent,
                    AppContentColors.scrim.withValues(alpha: 0.78),
                  ],
                  stops: <double>[0, 0.45, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (game.primaryPlatform.isNotEmpty)
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppContentColors.scrim.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: context.colors.glassBorder),
                  ),
                  child: Text(
                    game.primaryPlatform,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Legenda limitada à caixa do card (Positioned, não OverflowBox):
            // cresce para cima SÓ até o limite e nunca colide com o selo de
            // plataforma — em fontes grandes o título quebra para 1 linha.
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: _CarouselCaption(game: game, showMeta: showMeta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legenda do card do carrossel: desenvolvedor/nota (quando cabe) e título.
class _CarouselCaption extends StatelessWidget {
  const _CarouselCaption({required this.game, required this.showMeta});

  final Game game;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    // Em fontes grandes o título (1 linha) tem prioridade; metadados são
    // omitidos para a legenda caber sem invadir o selo de plataforma.
    final bool roomy = MediaQuery.textScalerOf(context).scale(1) < 1.4;
    final String developer = game.developer ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showMeta && roomy && developer.isNotEmpty) ...<Widget>[
          Text(
            developer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              color: AppContentColors.onMedia.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (showMeta && roomy && game.hasRating) ...<Widget>[
          RatingLine(rating: game.rating, compact: true),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Text(
          game.title,
          maxLines: roomy ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: context.texts.headlineSmall?.copyWith(
            color: AppContentColors.onMedia,
            fontWeight: FontWeight.w700,
            height: 1.06,
          ),
        ),
      ],
    );
  }
}
