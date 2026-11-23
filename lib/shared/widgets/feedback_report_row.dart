import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/compat_report.dart';
import 'admin_crown.dart';
import 'compat_report_sheet.dart';
import 'primitives.dart';
import 'profile_avatar.dart';

/// Rótulo de cada veredito de compatibilidade.
String compatVerdictLabel(L10n l10n, String status) {
  switch (status) {
    case 'perfect':
      return l10n.compatPerfect;
    case 'stutter':
      return l10n.compatStutter;
    case 'unplayable':
      return l10n.compatUnplayable;
    case 'not_run':
      return l10n.compatNotRun;
    case 'good':
    default:
      return l10n.compatGood;
  }
}

Color compatVerdictColor(String status, AppColorsTheme colors) {
  switch (status) {
    case 'perfect':
      return colors.success;
    case 'stutter':
      return colors.warning;
    case 'unplayable':
      return colors.danger;
    case 'not_run':
      return colors.textSecondary;
    case 'good':
    default:
      return colors.accentAlt;
  }
}

/// Nome do aparelho do relato: abre a ficha técnica pública (rota de busca
/// da API de especificações). Sem marca/modelo informados, fica como texto
/// de reserva sem interação.
class _DeviceLink extends StatelessWidget {
  const _DeviceLink({required this.device, required this.enabled});

  final String device;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.texts.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    if (!enabled) {
      return Text(
        device,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Pressable(
      onTap: () {
        final String query = Uri.encodeQueryComponent(device);
        context.push<Object?>('/specs/search?q=$query');
      },
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              device,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(color: context.colors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.hairline),
          Icon(
            Icons.chevron_right_rounded,
            size: 12,
            color: context.colors.accent,
          ),
        ],
      ),
    );
  }
}

/// Linha de um relato: autor, aparelho, nota, veredito, FPS e texto.
class FeedbackReportRow extends StatelessWidget {
  const FeedbackReportRow({
    super.key,
    required this.report,
    this.sameSoc = false,
  });

  final CompatReport report;
  final bool sameSoc;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String author = report.author.isEmpty ? l10n.player : report.author;
    final String device = report.deviceLabelOr(l10n.reportDevice);
    final String authorMeta =
        '${report.authorHandle != null ? '@${report.authorHandle} · ' : ''}$author';

    return Pressable(
      onTap: () => showCompatReportSheet(context, report),
      child: GlassContainer(
        radius: AppRadii.md,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Pressable(
              onTap: report.authorId == null
                  ? null
                  : () => context.push<Object?>('/u/${report.authorId}'),
              child: ProfileAvatar(
                name: author,
                imageUrl: report.authorCover,
                size: 34,
                level: report.authorRole,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _DeviceLink(
                          device: device,
                          enabled: report.brand != null || report.model != null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      BadgeChip(
                        label: compatVerdictLabel(l10n, report.status),
                        color: compatVerdictColor(
                          report.status,
                          context.colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Estrelas, FPS e cargo num Wrap: em telas estreitas ou com
                  // fonte ampliada (200%) o grupo quebra em duas linhas em
                  // vez de estourar a Row (overflow de 93px no pior caso).
                  if (report.rating > 0 ||
                      report.fps != null ||
                      report.authorRole != null) ...<Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (report.rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (int i = 1; i <= 5; i += 1)
                                Icon(
                                  i <= report.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 12,
                                  color: i <= report.rating
                                      ? context.colors.warning
                                      : context.colors.textTertiary,
                                ),
                            ],
                          ),
                        if (report.fps != null)
                          BadgeChip(
                            label: context.l10n.fpsValue(report.fps!),
                            color: context.colors.accent,
                            icon: Icons.speed_rounded,
                          ),
                        if (report.authorRole != null)
                          AdminBadge(level: report.authorRole!),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  // Autor em linha própria: antes dividia espaço com as specs
                  // e truncava junto (@handle · nome · soc · gpu · ram).
                  Text(
                    authorMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                  ..._deviceSpecsLine(context),
                  if (report.body.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      report.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (sameSoc) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    BadgeChip(
                      label: l10n.compatSameSoc,
                      color: context.colors.accent,
                      icon: Icons.memory_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Linha dedicada ao APARELHO DO RELATOR: processador (SoC) em destaque,
  /// seguido de GPU e RAM. Antes essas infos dividiam a linha do autor
  /// (@handle · nome) e eram quase sempre cortadas pelo ellipsis — o usuário
  /// não conseguia ver qual processador gerou o relato.
  List<Widget> _deviceSpecsLine(BuildContext context) {
    final TextStyle? base = context.texts.labelSmall?.copyWith(
      color: context.colors.textTertiary,
    );
    final TextStyle? strong = base?.copyWith(
      color: context.colors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    void add(String text, {required bool highlight}) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: ' · ', style: base));
      }
      spans.add(TextSpan(text: text, style: highlight ? strong : base));
    }

    final String? soc = report.soc;
    if (soc != null && soc.isNotEmpty) {
      add(soc, highlight: true);
    }
    final String? gpu = report.gpu;
    if (gpu != null && gpu.isNotEmpty) {
      add(gpu, highlight: false);
    }
    final int? ram = report.ramGb;
    if (ram != null) {
      add('$ram GB', highlight: false);
    }
    if (spans.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: AppSpacing.xxs),
      Row(
        children: <Widget>[
          Icon(
            Icons.memory_rounded,
            size: 12,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(children: spans),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ];
  }
}
