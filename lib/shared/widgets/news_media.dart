import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../models/news.dart';

/// Capa retangular de uma notícia, com placeholder determinístico.
class NewsCover extends StatelessWidget {
  const NewsCover({super.key, required this.item, this.memWidth = 1000});

  final NewsItem item;
  final int memWidth;

  @override
  Widget build(BuildContext context) {
    final String? url = item.coverUrl;
    if (url == null || url.isEmpty) {
      return NewsCoverFallback(item: item);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: memWidth,
      fadeInDuration: AppMotion.base,
      fadeOutDuration: AppMotion.fast,
      filterQuality: FilterQuality.medium,
      placeholder: (BuildContext context, String value) =>
          NewsCoverFallback(item: item),
      errorWidget: (BuildContext context, String value, Object error) =>
          NewsCoverFallback(item: item),
    );
  }
}

/// Fundo de reserva quando a notícia não tem capa (ou a imagem falha).
class NewsCoverFallback extends StatelessWidget {
  const NewsCoverFallback({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = coverColorsFor('${item.slug}-${item.category}');
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          size: 42,
          color: AppContentColors.onMedia.withValues(alpha: 0.32),
        ),
      ),
    );
  }
}
