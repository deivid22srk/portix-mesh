import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';

/// Cor da coroa conforme o nível de ADM.
Color adminLevelColor(String level, AppColorsTheme colors) {
  switch (level) {
    case 'root':
      return colors.warning;
    case 'admin':
      return colors.accent;
    case 'moderator':
      return colors.accentAlt;
    default:
      return colors.textSecondary;
  }
}

/// Ícone de coroa/título conforme o nível.
IconData adminLevelIcon(String level) {
  switch (level) {
    case 'root':
      return Icons.workspace_premium_rounded;
    case 'admin':
      return Icons.military_tech_rounded;
    case 'moderator':
      return Icons.verified_rounded;
    default:
      return Icons.person_rounded;
  }
}

String adminLevelLabel(L10n l10n, String level) {
  switch (level) {
    case 'root':
      return l10n.admRootLabel;
    case 'admin':
      return l10n.admAdminLabel;
    case 'moderator':
      return l10n.admModLabel;
    default:
      return '';
  }
}

/// Coroa do nível (só o ícone).
class AdminCrown extends StatelessWidget {
  const AdminCrown({super.key, required this.level, this.size = 16});

  final String level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      adminLevelIcon(level),
      size: size,
      color: adminLevelColor(level, context.colors),
    );
  }
}

/// Selo com coroa + rótulo do nível.
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key, required this.level, this.compact = false});

  final String level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = adminLevelColor(level, context.colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xxs : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(adminLevelIcon(level), size: 12, color: color),
          if (!compact) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                adminLevelLabel(context.l10n, level),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
