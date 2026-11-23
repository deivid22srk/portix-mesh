import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../app/theme.dart';
import '../../../core/mesh/mesh_config.dart';
import '../../../core/mesh/mesh_node.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/mesh_status.dart';
import '../../../shared/widgets/primitives.dart';

/// Categoria "Rede e Malha": dispositivos conectados, ligar/desligar a malha
/// e gerenciar os relays.
class NetworkSettingsBody extends ConsumerStatefulWidget {
  const NetworkSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  @override
  ConsumerState<NetworkSettingsBody> createState() =>
      _NetworkSettingsBodyState();
}

class _NetworkSettingsBodyState extends ConsumerState<NetworkSettingsBody> {
  final TextEditingController _relay = TextEditingController();

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  Future<void> _addRelay() async {
    final L10n l10n = widget.l10n;
    final String? normalized = normalizeRelayUrl(_relay.text);
    if (normalized == null) {
      showAppSnackBar(context, message: l10n.meshRelayInvalid);
      return;
    }
    final MeshConfig config = ref.read(meshConfigProvider);
    final List<String> next = <String>[...config.relayUrls(), normalized];
    await config.setRelayUrls(next);
    _relay.clear();
    await ref.read(meshNodeProvider).reloadRelays();
    ref.invalidate(meshConfigProvider);
    if (mounted) {
      showAppSnackBar(context, message: l10n.meshRelayAdded);
    }
  }

  Future<void> _removeRelay(String url) async {
    final MeshConfig config = ref.read(meshConfigProvider);
    final List<String> next = config
        .relayUrls()
        .where((String item) => item != url)
        .toList();
    await config.setRelayUrls(next);
    await ref.read(meshNodeProvider).reloadRelays();
    ref.invalidate(meshConfigProvider);
    if (mounted) {
      showAppSnackBar(context, message: widget.l10n.meshRelayRemoved);
    }
  }

  Future<void> _toggleMesh() async {
    final MeshConfig config = ref.read(meshConfigProvider);
    final bool next = !config.enabled;
    await config.setEnabled(next);
    final MeshNode node = ref.read(meshNodeProvider);
    if (next) {
      await node.start();
    } else {
      await node.stop();
    }
    ref.invalidate(meshConfigProvider);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = widget.l10n;
    final MeshConfig config = ref.watch(meshConfigProvider);
    final MeshNode node = ref.watch(meshNodeProvider);
    final bool enabled = config.enabled;
    final List<String> relays = config.relayUrls();
    final Map<String, bool> online = <String, bool>{
      for (final MeshRelayStatus status in node.relays) status.url: status.online,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const MeshStatusCard(),
        const SizedBox(height: AppSpacing.lg),
        SectionTile(
          icon: enabled
              ? Icons.wifi_tethering_rounded
              : Icons.wifi_tethering_off_rounded,
          label: enabled ? l10n.meshEnabledLabel : l10n.meshDisabledLabel,
          onTap: () => _toggleMesh(),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: l10n.meshRelaysTitle,
          subtitle: l10n.meshRelaysBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (relays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.meshRelaysEmpty,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          )
        else
          for (final String url in relays) ...<Widget>[
            _RelayRow(
              url: url,
              online: online[url] ?? false,
              onRemove: () => _removeRelay(url),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.md),
        GlassContainer(
          radius: AppRadii.md,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.dns_rounded,
                size: 18,
                color: context.colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _relay,
                  style: context.texts.bodyLarge,
                  cursorColor: context.colors.accent,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.meshRelayHint,
                    hintStyle: context.texts.bodyMedium?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.fieldVertical,
                    ),
                  ),
                  onSubmitted: (_) => _addRelay(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SecondaryButton(
                label: l10n.meshRelayAdd,
                icon: Icons.add_rounded,
                expand: false,
                onPressed: _addRelay,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _DeviceIdChip(id: ref.watch(meshIdentityProvider).deviceId),
      ],
    );
  }
}

class _RelayRow extends StatelessWidget {
  const _RelayRow({
    required this.url,
    required this.online,
    required this.onRemove,
  });

  final String url;
  final bool online;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              color: online ? context.colors.success : context.colors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: context.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceIdChip extends StatelessWidget {
  const _DeviceIdChip({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          context.l10n.meshYourId,
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
