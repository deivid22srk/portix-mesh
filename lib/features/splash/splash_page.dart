import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_mark.dart';
import '../../shared/widgets/primitives.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PortixMark(size: 116),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'PORTIX',
                style: context.texts.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.tagline,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BootstrapErrorPage extends ConsumerWidget {
  const BootstrapErrorPage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final Object failure = error;
    final bool isConfig =
        failure is AppFailure && failure.kind == FailureKind.config;
    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const PortixMark(size: 88),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  isConfig ? l10n.configTitle : l10n.errorGeneric,
                  textAlign: TextAlign.center,
                  style: context.texts.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isConfig ? l10n.configBody : context.failureText(error),
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  label: l10n.tryAgain,
                  expand: false,
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(meshBootstrapProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
