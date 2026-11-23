import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../app/theme.dart';
import '../../../core/auth.dart';
import '../../../core/theme/tokens.dart';
import '../../../models/collections.dart';
import '../../../models/download_task.dart';
import '../../../models/profile.dart';
import '../../../shared/widgets/admin_crown.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../collections/collections_controller.dart';
import '../../downloads/downloads_controller.dart';
import '../../profile/profile_controller.dart';

/// Categoria "Conta e Perfil": identidade (foto/nome/e-mail), estatísticas,
/// edição, entrar/sair. Ação destrutiva (sair) isolada com confirmação.
class AccountSettingsBody extends ConsumerWidget {
  const AccountSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool ok = await showAppConfirm(
      context,
      title: l10n.signOut,
      message: l10n.signOutConfirm,
      destructive: true,
    );
    if (ok && context.mounted) {
      await ref.read(accountProvider.notifier).signOut();
    }
  }

  /// Rótulo combinado — variável para o gate de literais (l10n obrigatório).
  String get _signInUpLabel => '${l10n.signIn} / ${l10n.signUp}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AccountState account = ref.watch(accountProvider);
    final UserProfile profile =
        ref.watch(profileProvider).value ??
        UserProfile(id: account.id ?? '', displayName: account.displayName);
    final String name = profile.displayName.isEmpty
        ? l10n.player
        : profile.displayName;
    final String? adminLevel = ref.watch(adminLevelProvider).value;
    final Collections collections =
        ref.watch(collectionsProvider).value ?? Collections.empty;
    final int downloads = ref
        .watch(downloadsProvider)
        .where((DownloadTask task) => task.isDone)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GlassContainer(
          radius: AppRadii.lg,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              ProfileAvatar(
                name: profile.displayName,
                imageUrl: profile.coverUrl,
                size: 84,
                level: adminLevel,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.email != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        account.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ] else if (profile.handle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '@${profile.handle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    if (adminLevel != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      AdminBadge(level: adminLevel),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassContainer(
          radius: AppRadii.lg,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _AccountStat(
                  value: collections.favorites.length.toString(),
                  label: l10n.hubFavorites,
                ),
              ),
              const _AccountStatDivider(),
              Expanded(
                child: _AccountStat(
                  value: collections.library.length.toString(),
                  label: l10n.hubInstalled,
                ),
              ),
              const _AccountStatDivider(),
              Expanded(
                child: _AccountStat(
                  value: downloads.toString(),
                  label: l10n.hubDownloads,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (account.isSignedIn) ...<Widget>[
          PrimaryButton(
            label: l10n.editProfile,
            icon: Icons.edit_rounded,
            onPressed: () => context.push<Object?>('/profile/edit'),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.signOut,
            icon: Icons.logout_rounded,
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ] else
          PrimaryButton(
            label: _signInUpLabel,
            icon: Icons.login_rounded,
            onPressed: () => context.push<Object?>('/auth'),
          ),
      ],
    );
  }
}

class _AccountStat extends StatelessWidget {
  const _AccountStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: context.texts.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AccountStatDivider extends StatelessWidget {
  const _AccountStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: context.colors.glassBorder);
  }
}
