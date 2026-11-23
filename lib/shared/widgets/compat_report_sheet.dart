import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../models/compat_report.dart';
import 'admin_crown.dart';
import 'feedback_report_row.dart';
import 'primitives.dart';
import 'profile_avatar.dart';

/// Abre o detalhe completo de um relato da comunidade.
Future<void> showCompatReportSheet(
  BuildContext context,
  CompatReport report,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppContentColors.transparent,
    barrierColor: AppContentColors.scrim.withValues(alpha: 0.6),
    builder: (BuildContext context) => _CompatReportSheet(report: report),
  );
}

/// Conteúdo do relato: autor, veredito, aparelho, especificações e texto
/// completo (sem o limite de linhas da lista).
class _CompatReportSheet extends StatelessWidget {
  _CompatReportSheet({required this.report});

  final CompatReport report;

  void _openAuthor(BuildContext context) {
    final String? id = report.authorId;
    if (id == null) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push<Object?>('/u/$id');
  }

  /// Abre a ficha técnica pública do aparelho citado no relato.
  void _openSpecs(BuildContext context) {
    if (report.brand == null && report.model == null) {
      return;
    }
    final String query = Uri.encodeQueryComponent(report.deviceLabelOr(''));
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push<Object?>('/specs/search?q=$query');
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String author = report.author.isEmpty ? l10n.player : report.author;
    final String device = report.deviceLabelOr(l10n.reportDevice);
    final String specs = <String>[
      ?report.soc,
      ?report.gpu,
      if (report.ramGb != null) '${report.ramGb} GB',
    ].join(' · ');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: BoxDecoration(
        color: context.colors.bgElevated,
        borderRadius: BorderRadius.vertical(top: AppRadii.sheet),
        border: Border(top: BorderSide(color: context.colors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.textTertiary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.reportDetails,
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Pressable(
                    onTap: report.authorId == null
                        ? null
                        : () => _openAuthor(context),
                    child: ProfileAvatar(
                      name: author,
                      imageUrl: report.authorCover,
                      size: 46,
                      level: report.authorRole,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.hairline),
                        Row(
                          children: <Widget>[
                            if (report.authorHandle != null) ...<Widget>[
                              Flexible(
                                child: Text(
                                  '@${report.authorHandle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.labelSmall?.copyWith(
                                    color: context.colors.textTertiary,
                                  ),
                                ),
                              ),
                              Text(
                                '  ·  ',
                                style: context.texts.labelSmall?.copyWith(
                                  color: context.colors.textTertiary,
                                ),
                              ),
                            ],
                            Text(
                              relativeDay(report.createdAt, en: l10n.isEn),
                              style: context.texts.labelSmall?.copyWith(
                                color: context.colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (report.authorRole != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    AdminBadge(level: report.authorRole!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        BadgeChip(
                          label: compatVerdictLabel(l10n, report.status),
                          color: compatVerdictColor(
                            report.status,
                            context.colors,
                          ),
                        ),
                        if (report.fps != null)
                          BadgeChip(
                            label: context.l10n.fpsValue(report.fps!),
                            color: context.colors.accent,
                            icon: Icons.speed_rounded,
                          ),
                      ],
                    ),
                  ),
                  if (report.rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 1; i <= 5; i += 1)
                          Icon(
                            i <= report.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: i <= report.rating
                                ? context.colors.warning
                                : context.colors.textTertiary,
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _SheetSection(
                title: l10n.reportDevice,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (specs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        specs,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    if (report.brand != null ||
                        report.model != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Pressable(
                        onTap: () => _openSpecs(context),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.smartphone_rounded,
                              size: 14,
                              color: context.colors.accent,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              l10n.specsOpenAction,
                              style: context.texts.labelSmall?.copyWith(
                                color: context.colors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (report.body.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _SheetSection(
                  title: l10n.reportBodyLabel,
                  child: Text(
                    report.body,
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SecondaryButton(
                      label: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (report.authorId != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SecondaryButton(
                        label: l10n.openProfile,
                        icon: Icons.person_rounded,
                        active: true,
                        onPressed: () => _openAuthor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: context.colors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
