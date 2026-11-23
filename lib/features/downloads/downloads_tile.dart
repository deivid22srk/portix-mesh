import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../core/theme/tokens.dart';
import '../../models/download_task.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import 'downloads_controller.dart';

/// Linha de download com progresso e controles (usada no Meu Hub).
class DownloadTile extends ConsumerWidget {
  const DownloadTile({super.key, required this.task});

  final DownloadTask task;

  String _statusLabel(L10n l10n) {
    switch (task.status) {
      case DownloadStatus.queued:
        return l10n.statusQueued;
      case DownloadStatus.connecting:
        return l10n.statusConnecting;
      case DownloadStatus.downloading:
        return l10n.progressPercent((task.progress * 100).round());
      case DownloadStatus.verifying:
        return l10n.statusVerifying;
      case DownloadStatus.paused:
        return l10n.statusPaused;
      case DownloadStatus.done:
        return l10n.statusDone;
      case DownloadStatus.failed:
        return l10n.statusFailed;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.queued:
        return context.colors.warning;
      case DownloadStatus.connecting:
        return context.colors.textSecondary;
      case DownloadStatus.downloading:
        return context.colors.accent;
      case DownloadStatus.verifying:
        return context.colors.accentAlt;
      case DownloadStatus.paused:
        return context.colors.textSecondary;
      case DownloadStatus.done:
        return context.colors.success;
      case DownloadStatus.failed:
        return context.colors.danger;
    }
  }

  /// Linha de estatísticas: bytes baixados + velocidade (quando o motor
  /// informa) — nunca “solta” números sem contexto.
  String _statsLine(L10n l10n) {
    final List<String> parts = <String>[
      if (task.totalBytes > 0)
        '${formatBytes(task.doneBytes)} / ${formatBytes(task.totalBytes)}',
      if (task.speedBps > 0) formatSpeed(task.speedBps),
    ];
    if (parts.isEmpty) {
      return task.status == DownloadStatus.connecting
          ? l10n.statusConnecting
          : '';
    }
    return parts.join(' · ');
  }

  String _etaOrEmpty() => formatEta(task.etaSecs) ?? '';

  /// Remove/cancela com snackbar e desfazer — destrutivo nunca é sem volta.
  void _removeWithUndo(
    BuildContext context,
    L10n l10n,
    DownloadsController controller,
  ) {
    controller.remove(task.gameId);
    showAppSnackBar(
      context,
      message: l10n.downloadRemoved,
      actionLabel: l10n.undo,
      onAction: () => controller.restore(task),
    );
  }

  Future<void> _openSource(String? url) async {
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Sem app que trate o link, nada a fazer aqui.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final DownloadsController controller = ref.read(downloadsProvider.notifier);
    final List<String> metaParts = <String>[?task.platformName, ?task.portKey];
    final String meta = metaParts.isEmpty
        ? l10n.notInformed
        : metaParts.join(' · ');

    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: task.slug.isEmpty
          ? null
          : () => context.push<Object?>('/game/${task.slug}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: AppSpacing.tileCoverWidth,
            height: AppSpacing.tileCoverHeight,
            child: GameCover(
              imageUrl: task.coverUrl,
              title: task.title,
              memWidth: 180,
              borderRadius: AppRadii.sm,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    BadgeChip(
                      label: _statusLabel(l10n),
                      color: _statusColor(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                // Corpo por estado com transição: crossfade entre grupos
                // (progresso/falha/concluído) + ajuste animado de altura.
                AnimatedSize(
                  duration: AppMotion.fast,
                  curve: AppMotion.out,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: AppMotion.base,
                    switchInCurve: AppMotion.out,
                    switchOutCurve: AppMotion.out.flipped,
                    transitionBuilder: (Widget child, Animation<double> a) =>
                        FadeTransition(opacity: a, child: child),
                    child: KeyedSubtree(
                      key: ValueKey<String>(_stateGroup),
                      child: _stateBody(context, l10n, controller),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grupo visual do estado: controla a chave do AnimatedSwitcher — mudanças
  /// dentro do mesmo grupo (ex.: conectando→baixando) não piscam.
  String get _stateGroup {
    if (task.status == DownloadStatus.failed) {
      return 'failed';
    }
    return task.isDone ? 'done' : 'progress';
  }

  Widget _stateBody(
    BuildContext context,
    L10n l10n,
    DownloadsController controller,
  ) {
    if (task.status == DownloadStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: context.colors.danger,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.downloadErrorLabel(task.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Wrap (não Row): em fonte 2,0 os botões quebram de linha em
          // vez de estourar a largura (varredura de overflow do helper).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (task.portUrl != null)
                SecondaryButton(
                  label: l10n.openSource,
                  icon: Icons.open_in_new_rounded,
                  height: AppSpacing.secondaryButtonHeight,
                  expand: false,
                  onPressed: () => _openSource(task.portUrl),
                ),
              GlassCircleButton(
                icon: Icons.refresh_rounded,
                size: 48,
                tooltip: l10n.tryAgain,
                onTap: () => controller.resume(task.gameId),
              ),
              GlassCircleButton(
                icon: Icons.close_rounded,
                size: 48,
                tooltip: l10n.cancel,
                onTap: () => _removeWithUndo(context, l10n, controller),
              ),
            ],
          ),
        ],
      );
    }

    if (!task.isDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          // RepaintBoundary: o tick do progresso (~10/s) repinta só a barra,
          // não o tile inteiro.
          RepaintBoundary(
            child: GradientProgress(
              value: task.progress,
              height: AppSpacing.sm,
              semanticLabel: _statusLabel(l10n),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _statsLine(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              if (task.isTransferring && task.etaSecs >= 0)
                Text(
                  l10n.timeLeft(_etaOrEmpty()),
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              if (task.isTransferring)
                GlassCircleButton(
                  icon: Icons.pause_rounded,
                  size: 48,
                  tooltip: l10n.pause,
                  onTap: () => controller.pause(task.gameId),
                )
              else
                GlassCircleButton(
                  icon: Icons.play_arrow_rounded,
                  size: 48,
                  tooltip: l10n.resume,
                  onTap: () => controller.resume(task.gameId),
                ),
              const SizedBox(width: AppSpacing.sm),
              GlassCircleButton(
                icon: Icons.close_rounded,
                size: 48,
                tooltip: l10n.cancel,
                onTap: () => _removeWithUndo(context, l10n, controller),
              ),
              const Spacer(),
              if (task.startedAt != null)
                Text(
                  relativeDay(task.startedAt, en: l10n.isEn),
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: context.colors.success,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.downloadDone,
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.success,
                ),
              ),
            ),
            GlassCircleButton(
              icon: Icons.delete_outline_rounded,
              size: 48,
              tooltip: l10n.remove,
              onTap: () => _removeWithUndo(context, l10n, controller),
            ),
          ],
        ),
      ],
    );
  }
}
