import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../app/settings.dart';
import '../../../app/theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/primitives.dart';

/// Categoria "Notificações": toggle de avisos de novos ports.
class NotificationsSettingsBody extends ConsumerWidget {
  const NotificationsSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    return GlassContainer(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.notifications,
                  style: context.texts.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.notificationsHint,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppToggle(
            value: settings.notifications,
            semanticLabel: l10n.notifications,
            onChanged: (bool value) =>
                ref.read(settingsProvider.notifier).setNotifications(value),
          ),
        ],
      ),
    );
  }
}
