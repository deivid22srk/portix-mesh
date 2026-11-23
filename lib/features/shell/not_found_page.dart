import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_mark.dart';
import '../../shared/widgets/primitives.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PortixMark(size: 80, glow: false),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '404',
                    style: context.texts.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: context.colors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.noResultsTitle,
                    textAlign: TextAlign.center,
                    style: context.texts.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.errorNotFound,
                    textAlign: TextAlign.center,
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    label: l10n.navHome,
                    icon: Icons.home_rounded,
                    expand: false,
                    height: AppSpacing.secondaryButtonHeight,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
