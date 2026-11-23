import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/native_downloader.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../models/app_update.dart';
import '../../shared/widgets/primitives.dart';
import 'home_controller.dart';

/// Mostra o diálogo de atualização (uma vez por versão) quando o ADM raiz
/// publica um aviso. Fica na árvore do shell e não desenha nada.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key});

  static const String _dismissKey = 'update.dismissed';

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppUpdate?> async = ref.watch(latestUpdateProvider);
    if (!_checked && async.hasValue) {
      _checked = true;
      final AppUpdate? update = async.value;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          _maybeShow(update);
        }
      });
    }
    return const SizedBox.shrink();
  }

  Future<void> _maybeShow(AppUpdate? update) async {
    if (update == null ||
        update.version.isEmpty ||
        update.version == kAppVersion) {
      return;
    }
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getString(UpdateGate._dismissKey) == update.version) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppContentColors.scrim.withValues(alpha: 0.72),
      builder: (BuildContext context) => UpdateDialog(update: update),
    );
  }
}

/// Diálogo com a novidade e o botão que baixa o APK pelo próprio app.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.update});

  final AppUpdate update;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  late final int _id = widget.update.version.hashCode & 0x7fffffff;
  StreamSubscription<NativeDownloadEvent>? _subscription;
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    final String? url = widget.update.url;
    if (url == null) {
      return;
    }
    if (!NativeDownloader.isAndroid) {
      await _openExternal(url);
      return;
    }
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    await NativeDownloader.requestNotifications();
    await _subscription?.cancel();
    _subscription = NativeDownloader.events().listen(_onEvent);
    final bool ok = await NativeDownloader.start(
      id: _id,
      url: url,
      title: 'PORTIX v${widget.update.version}',
    );
    if (!ok && mounted) {
      setState(() {
        _downloading = false;
        _error = context.l10n.downloadStartFailed;
      });
    }
  }

  void _onEvent(NativeDownloadEvent event) {
    if (event.id != _id || !mounted) {
      return;
    }
    switch (event.status) {
      case 'downloading':
        setState(() => _progress = event.progress ?? _progress);
      case 'done':
        _finish(event.path);
      case 'failed':
        setState(() {
          _downloading = false;
          _error = event.error ?? 'falha no download';
        });
      default:
        break;
    }
  }

  Future<void> _finish(String? path) async {
    if (path != null) {
      await NativeDownloader.install(path);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancelDownload() async {
    await NativeDownloader.cancel(_id);
    if (mounted) {
      setState(() => _downloading = false);
    }
  }

  Future<void> _openExternal(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // sem app que trate o link
    }
  }

  Future<void> _later() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(UpdateGate._dismissKey, widget.update.version);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final bool hasUrl = widget.update.url != null;
    return Dialog(
      backgroundColor: AppContentColors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: context.colors.glassBorder),
          boxShadow: context.colors.floatingShadow,
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.system_update_alt_rounded,
                  color: context.colors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.updateAvailable,
                    style: context.texts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                BadgeChip(
                  label: l10n.versionBadge(widget.update.version),
                  color: context.colors.accent,
                ),
              ],
            ),
            if (widget.update.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.update.message,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (_downloading) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              GradientProgress(value: _progress),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.progressPercent((_progress * 100).round()),
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (_downloading)
              SecondaryButton(
                label: l10n.cancel,
                icon: Icons.close_rounded,
                onPressed: _cancelDownload,
              )
            else ...<Widget>[
              if (hasUrl)
                PrimaryButton(
                  label: l10n.updateNow,
                  icon: Icons.download_rounded,
                  onPressed: _download,
                ),
              if (hasUrl) const SizedBox(height: AppSpacing.sm),
              SecondaryButton(label: l10n.later, onPressed: _later),
            ],
          ],
        ),
      ),
    );
  }
}
