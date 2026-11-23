import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import 'admin_crown.dart';

/// Avatar do usuário: usa a capa/URL se houver, senão as iniciais do nome.
/// Mostra a coroa do nível de ADM quando aplicável.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 32,
    this.level,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final String? level;

  Widget _initials(BuildContext context) {
    return ColoredBox(
      color: context.colors.glassStrong,
      child: Center(
        child: Text(
          initialsOf(name),
          style: context.texts.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.accent,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    final Widget image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _initials(context)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                fadeInDuration: AppMotion.fast,
                placeholder: (BuildContext context, String value) =>
                    _initials(context),
                errorWidget:
                    (BuildContext context, String value, Object error) =>
                        _initials(context),
              ),
      ),
    );

    if (level == null) {
      return image;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          image,
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.colors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: AdminCrown(level: level!, size: size * 0.42),
            ),
          ),
        ],
      ),
    );
  }
}
