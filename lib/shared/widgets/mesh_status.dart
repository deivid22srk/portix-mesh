import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/mesh/mesh_node.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import 'primitives.dart';

/// Presença atual da malha, caindo para o último valor conhecido do nó.
MeshPresence presenceOf(WidgetRef ref) {
  final MeshPresence? latest = ref.watch(meshPresenceProvider).value;
  return latest ?? ref.watch(meshNodeProvider).current;
}

/// Pílula compacta com a contagem de dispositivos (cabeçalhos).
class MeshStatusPill extends ConsumerWidget {
  const MeshStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MeshPresence presence = presenceOf(ref);
    final bool online = presence.devices > 0;
    final Color dot = online
        ? context.colors.success
        : context.colors.textTertiary;
    return GlassContainer(
      radius: AppRadii.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.meshCountShort(presence.devices),
            style: context.texts.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de status da malha: contagem de dispositivos, relays e ID local.
class MeshStatusCard extends ConsumerWidget {
  const MeshStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final MeshPresence presence = presenceOf(ref);
    final MeshNode node = ref.watch(meshNodeProvider);
    final List<MeshRelayStatus> relays = node.relays;
    final int relaysOnline = relays
        .where((MeshRelayStatus r) => r.online)
        .length;
    final String relaysLabel = '$relaysOnline/${relays.length}';
    final bool online = presence.devices > 0;

    return GlassContainer(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                online
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_tethering_off_rounded,
                color: online
                    ? context.colors.success
                    : context.colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.meshStatusTitle,
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              BadgeChip(
                label: l10n.meshDevicesOnline(presence.devices),
                color: online
                    ? context.colors.success
                    : context.colors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.meshStatusBody,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              InfoChip(icon: Icons.cloud_rounded, label: relaysLabel),
              if (presence.lanDevices > 0)
                InfoChip(icon: Icons.lan_rounded, label: l10n.meshLanBadge),
            ],
          ),
        ],
      ),
    );
  }
}
