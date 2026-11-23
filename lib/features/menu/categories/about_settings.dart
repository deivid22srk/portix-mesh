import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_strings.dart';
import '../../../app/theme.dart';
import '../../../core/env.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_mark.dart';
import '../../../shared/widgets/primitives.dart';

/// Categoria "Ajuda e Sobre": identidade, versão, fonte de dados, legal.
class AboutSettingsBody extends ConsumerWidget {
  const AboutSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  /// Abre um documento legal da landing page no navegador.
  Future<void> _openLegal(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Sem navegador disponível: o usuário ainda pode acessar pelo site.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GlassContainer(
          radius: AppRadii.lg,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const PortixMark(size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.appName,
                          style: context.texts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          l10n.tagline,
                          style: context.texts.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'v$kAppVersion',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.dataSource,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.code_rounded,
                    size: 14,
                    color: context.colors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.madeWith,
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionTile(
          icon: Icons.description_outlined,
          label: l10n.termsOfUse,
          onTap: () => _openLegal(context, kTermsUrl),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionTile(
          icon: Icons.privacy_tip_outlined,
          label: l10n.privacyPolicy,
          onTap: () => _openLegal(context, kPrivacyUrl),
        ),
      ],
    );
  }
}
