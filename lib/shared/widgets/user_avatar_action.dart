import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../core/auth.dart';
import '../../core/theme/tokens.dart';
import '../../features/profile/profile_controller.dart';
import '../../models/profile.dart';
import 'primitives.dart';
import 'profile_avatar.dart';

/// Avatar do usuário como ação de cabeçalho.
///
/// Fonte única da foto de perfil: [ProfileAvatar] (CachedNetworkImage) com
/// fallback de iniciais — trocar de aba não recarrega a imagem nem pisca o
/// fallback. O alvo de toque é o padrão do app (48dp) e o rótulo vem do l10n.
class UserAvatarAction extends ConsumerWidget {
  const UserAvatarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AccountState account = ref.watch(accountProvider);
    final UserProfile profile =
        ref.watch(profileProvider).value ??
        UserProfile(id: account.id ?? '', displayName: account.displayName);
    final String? adminLevel = ref.watch(adminLevelProvider).value;
    final String name = profile.displayName.isEmpty
        ? l10n.player
        : profile.displayName;

    return Semantics(
      // Ação de cabeçalho: o leitor de tela anuncia o papel de botão e o
      // destino (o Tooltip sozinho não dá papel nem rótulo).
      button: true,
      label: l10n.accountSection,
      onTap: () => context.go('/menu/conta'),
      child: ExcludeSemantics(
        child: Tooltip(
          message: l10n.accountSection,
          child: Pressable(
            onTap: () => context.go('/menu/conta'),
            scale: 0.94,
            child: SizedBox(
              width: AppSpacing.circleButton,
              height: AppSpacing.circleButton,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.glassBorder),
                  ),
                  child: ClipOval(
                    child: ProfileAvatar(
                      name: name,
                      imageUrl: profile.coverUrl,
                      size: AppSpacing.xxl + AppSpacing.xs,
                      level: adminLevel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
