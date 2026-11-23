import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import '../../models/public_profile.dart';
import '../../shared/widgets/admin_crown.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/states.dart';
import 'profile_controller.dart';

/// Perfil público de um usuário: capa, nome, @, coroa e a biblioteca.
class UserProfilePage extends ConsumerWidget {
  UserProfilePage({super.key, required this.id});

  final String id;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<PublicProfile> async = ref.watch(
      publicProfileProvider(id),
    );

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: async.when(
            loading: () => Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.accent,
                ),
              ),
            ),
            error: (Object error, StackTrace _) => Stack(
              children: <Widget>[
                Positioned(
                  left: AppSpacing.md,
                  top: AppSpacing.sm,
                  child: GlassCircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: context.l10n.tooltipBack,
                    onTap: () => _back(context),
                  ),
                ),
                ErrorStateView(
                  message: context.failureText(error),
                  retryLabel: l10n.tryAgain,
                  onRetry: () => ref.invalidate(publicProfileProvider(id)),
                ),
              ],
            ),
            data: (PublicProfile profile) =>
                _Content(profile: profile, onBack: () => _back(context)),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.profile, required this.onBack});

  final PublicProfile profile;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String handle = profile.handle == null
        ? l10n.noHandle
        : '@${profile.handle}';
    return AppContentMax(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GameCover(
                    title: profile.displayName,
                    imageUrl: profile.coverUrl,
                    memWidth: 900,
                    borderRadius: 0,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppContentColors.scrim.withValues(alpha: 0.40),
                          AppContentColors.transparent,
                          AppContentColors.scrim.withValues(alpha: 0.80),
                        ],
                        stops: <double>[0, 0.45, 1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    top: AppSpacing.sm,
                    child: GlassCircleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: l10n.tooltipBack,
                      onTap: onBack,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ProfileAvatar(
                    name: profile.displayName,
                    imageUrl: profile.coverUrl,
                    size: 64,
                    level: profile.level,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.hairline),
                        Text(
                          handle,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        if (profile.level != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          AdminBadge(level: profile.level!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: SectionHeader(
                title: l10n.userLibraryTitle,
                subtitle: l10n.gameCount(profile.library.length),
              ),
            ),
          ),
          if (profile.library.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: EmptyState(
                  icon: Icons.video_library_outlined,
                  title: l10n.userLibraryEmpty,
                  body: l10n.anonymousHint,
                ),
              ),
            )
          else
            ResponsiveCoverGrid(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                context.systemBottomInset + AppSpacing.xxxl,
              ),
              itemBuilder: (BuildContext context, int index) {
                final Game game = profile.library[index];
                return GameCard(
                  game: game,
                  heroTag: 'user-${profile.id}-${game.id}',
                );
              },
              itemCount: profile.library.length,
            ),
        ],
      ),
    );
  }
}
