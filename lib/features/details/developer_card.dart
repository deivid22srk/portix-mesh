import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/github_releases.dart';
import '../../core/github_service.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';

/// Seção "Desenvolvedor": dados do dono do repo no GitHub (foto em cache,
/// nome com fallback para @login, bio curta e link para o perfil).
/// Estados: skeleton → carregado / fallback (erro ou owner inexistente).
class DeveloperCard extends ConsumerWidget {
  const DeveloperCard({super.key, required this.owner});

  /// Login do dono do repositório (ex.: "VinTeRuS").
  final String owner;

  Future<void> _openProfile(String? htmlUrl) async {
    final String url = htmlUrl ?? 'https://github.com/$owner';
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Sem navegador disponível: ignora silenciosamente.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<GithubUser?> async = ref.watch(githubUserProvider(owner));

    if (async.isLoading && !async.hasValue) {
      return GlassContainer(
        radius: AppRadii.lg,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SkeletonPulse(
          child: Row(
            children: <Widget>[
              const SkeletonBox(width: 56, height: 56, radius: AppRadii.pill),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SkeletonBox(width: 140, height: 16),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(width: 90, height: 12),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final GithubUser? user = async.value;
    // Sem URL de avatar (ou falha de rede): fallback com iniciais.
    final String? photoUrl = (user?.avatarUrl ?? '').trim().isEmpty
        ? null
        : user!.avatarUrlFor(112);
    return GlassContainer(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                label: l10n.developerSection,
                image: photoUrl != null,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipOval(
                    child: photoUrl == null
                        ? _FallbackAvatar(name: owner)
                        : CachedNetworkImage(
                            // URL estável (?s=112): o cache de memória/disco
                            // bate na 2ª abertura — zero novos downloads.
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 168,
                            fadeInDuration: AppMotion.fast,
                            placeholder: (BuildContext context, String value) =>
                                _FallbackAvatar(name: owner),
                            errorWidget:
                                (
                                  BuildContext context,
                                  String value,
                                  Object error,
                                ) => _FallbackAvatar(name: owner),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user?.displayName ?? owner,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      '@${user?.login ?? owner}',
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.accent,
                      ),
                    ),
                    if (user?.bio != null &&
                        user!.bio!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        user.bio!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (user != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                BadgeChip(
                  label: user.isOrganization
                      ? l10n.organizationLabel
                      : l10n.userLabel,
                  color: user.isOrganization
                      ? context.colors.accentAlt
                      : context.colors.accent,
                ),
              ],
            ],
          ),
          if (user != null &&
              (user.publicRepos > 0 || user.followers > 0)) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            // Wrap: nunca estoura a largura em colunas estreitas.
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (user.publicRepos > 0)
                  Text(
                    '${user.publicRepos} ${l10n.repositoriesLabel}',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                if (user.followers > 0)
                  Text(
                    '${compactNumber(user.followers)} ${l10n.followersLabel}',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: l10n.viewGithubProfile,
            icon: Icons.open_in_new_rounded,
            height: 44,
            onPressed: () => _openProfile(user?.htmlUrl),
          ),
        ],
      ),
    );
  }
}

/// Avatar de fallback com as iniciais (owner sem foto / falha de rede).
class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.glassStrong,
      child: Center(
        child: Text(
          initialsOf(name),
          style: context.texts.titleSmall?.copyWith(
            color: context.colors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
