import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/primitives.dart';
import '../../collections/collections_controller.dart';
import '../../home/home_controller.dart';
import '../../profile/profile_controller.dart';

/// Categoria "Dados e Armazenamento": recarregar catálogo e limpar cache.
/// Limpar cache apaga dados locais → confirmação antes.
class DataSettingsBody extends ConsumerStatefulWidget {
  const DataSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  @override
  ConsumerState<DataSettingsBody> createState() => _DataSettingsBodyState();
}

class _DataSettingsBodyState extends ConsumerState<DataSettingsBody> {
  /// Recarregar catálogo em andamento: a tile mostra spinner e o tap fica
  /// desabilitado (feedback real durante o await — rede lenta inclusa).
  bool _reloading = false;

  Future<void> _reload() async {
    if (_reloading) {
      return;
    }
    setState(() => _reloading = true);
    try {
      final L10n l10n = context.l10n;
      ref.invalidate(homeFeedProvider);
      ref.invalidate(catalogFacetsProvider);
      ref.invalidate(collectionsProvider);
      await ref.read(homeFeedProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      // Sucesso honesto: o refresh com AsyncValue.guard não lança — o estado
      // pós-refresh é quem diz se a revalidação funcionou.
      final bool ok = ref.read(homeFeedProvider).hasValue;
      showAppSnackBar(
        context,
        message: ok ? l10n.catalogReloaded : l10n.catalogReloadFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _reloading = false);
      }
    }
  }

  Future<void> _clearCache() async {
    final L10n l10n = context.l10n;
    // Destrutivo: confirmação antes de apagar o cache local.
    final bool ok = await showAppConfirm(
      context,
      title: l10n.clearCache,
      message: l10n.settingsClearCacheConfirm,
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    // O aviso promete catálogo, perfil e imagens: limpa os caches de verdade.
    await ref.read(cacheStoreProvider).clearAll();
    await DefaultCacheManager().emptyCache();
    clearInMemoryImageCache();
    ref.invalidate(homeFeedProvider);
    ref.invalidate(catalogFacetsProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(profileProvider);
    if (!mounted) {
      return;
    }
    showAppSnackBar(context, message: l10n.cacheCleared);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Column(
      children: <Widget>[
        SectionTile(
          icon: Icons.sync_rounded,
          label: l10n.reloadCatalog,
          onTap: _reloading ? null : () => _reload(),
          trailing: _reloading
              ? SizedBox(
                  width: AppSpacing.inlineSpinner,
                  height: AppSpacing.inlineSpinner,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.settingsReloading,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionTile(
          icon: Icons.cleaning_services_rounded,
          label: l10n.clearCache,
          onTap: () => _clearCache(),
        ),
      ],
    );
  }
}
