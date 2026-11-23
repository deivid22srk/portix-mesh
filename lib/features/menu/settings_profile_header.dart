import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/theme/tokens.dart';
import '../../models/profile.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/primitives.dart';
import '../profile/profile_controller.dart';
import 'settings_categories.dart';

/// Cabeçalho resumido do perfil no hub de configurações: foto, nome,
/// e-mail (ou @handle) e estado da conta.
class SettingsProfileHeader extends ConsumerWidget {
  const SettingsProfileHeader({super.key, this.selectedId});

  /// Id da categoria selecionada (master-detail); null no hub mobile.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AccountState account = ref.watch(accountProvider);
    final UserProfile profile =
        ref.watch(profileProvider).value ??
        UserProfile(id: account.id ?? '', displayName: account.displayName);
    final String? adminLevel = ref.watch(adminLevelProvider).value;
    final String? email = account.email;
    // Linha secundária só existe com dado real (e-mail ou @handle) — mostrar
    // "Convidado" aqui E na linha de status duplicava a informação.
    final String? secondary =
        email ??
        (profile.handle != null && profile.handle!.isNotEmpty
            ? '@${profile.handle}'
            : null);
    final String name = profile.displayName.isEmpty
        ? l10n.player
        : profile.displayName;

    return GlassContainer(
      radius: AppRadii.lg,
      onTap: selectedId == null
          ? () => context.go('/menu/$kSettingsAccount')
          : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          ProfileAvatar(
            name: name,
            imageUrl: profile.coverUrl,
            size: 56,
            level: adminLevel,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (secondary != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  account.isSignedIn ? l10n.accountSection : l10n.guestLabel,
                  style: context.texts.labelSmall?.copyWith(
                    // Logado usa o destaque; convidado é estado neutro.
                    color: account.isSignedIn
                        ? context.colors.accent
                        : context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: context.colors.textTertiary,
          ),
        ],
      ),
    );
  }
}
