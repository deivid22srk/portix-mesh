import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/apk_tools.dart';
import '../../core/native_downloader.dart';
import '../../core/providers.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../models/game_detail.dart';
import '../collections/collections_controller.dart';

final downloadsProvider =
    NotifierProvider<DownloadsController, List<DownloadTask>>(
      DownloadsController.new,
    );

final downloadForGameProvider = Provider.family<DownloadTask?, String>((
  ref,
  String gameId,
) {
  final List<DownloadTask> tasks = ref.watch(downloadsProvider);
  for (final DownloadTask task in tasks) {
    if (task.gameId == gameId) {
      return task;
    }
  }
  return null;
});

/// Fila de downloads. No Android usa o motor nativo (Rust + serviço em primeiro
/// plano com notificação); em outras plataformas cai numa simulação local.
class DownloadsController extends Notifier<List<DownloadTask>> {
  static const String _storageKey = 'downloads.tasks';

  Timer? _ticker;
  int _ticks = 0;
  StreamSubscription<NativeDownloadEvent>? _events;

  @override
  List<DownloadTask> build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      _events?.cancel();
      _events = null;
    });
    if (NativeDownloader.isAndroid) {
      _events = NativeDownloader.events().listen(_onNativeEvent);
    }
    return _loadPersisted();
  }

  List<DownloadTask> _loadPersisted() {
    final String? raw = ref
        .read(sharedPreferencesProvider)
        .getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <DownloadTask>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <DownloadTask>[];
      }
      final List<DownloadTask> tasks = <DownloadTask>[];
      for (final Object? item in decoded) {
        if (item is Map) {
          final DownloadTask task = DownloadTask.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (task.gameId.isEmpty) {
            continue;
          }
          // Um download interrompido volta como pausado, nunca progredindo.
          tasks.add(
            task.isActive || task.status == DownloadStatus.failed
                ? task.copyWith(status: DownloadStatus.paused)
                : task,
          );
        }
      }
      return tasks;
    } on Object {
      return const <DownloadTask>[];
    }
  }

  void start(
    Game game, {
    GamePort? port,
    String? urlOverride,
    String? releaseTag,
    bool restart = false,
  }) {
    final int index = state.indexWhere(
      (DownloadTask task) => task.gameId == game.id,
    );
    if (index >= 0 && !restart) {
      final DownloadTask current = state[index];
      if (current.status == DownloadStatus.done) {
        return;
      }
      if (current.status != DownloadStatus.downloading) {
        resume(game.id);
      }
      return;
    }
    if (index >= 0) {
      // Atualização: descarta a tarefa anterior antes de baixar de novo.
      state = state
          .where((DownloadTask item) => item.gameId != game.id)
          .toList(growable: false);
    }

    final String? url = urlOverride ?? port?.url;
    final bool useNative = NativeDownloader.isAndroid && url != null;
    final DownloadTask task = DownloadTask(
      gameId: game.id,
      title: game.title,
      slug: game.slug,
      coverUrl: game.coverUrl,
      portKey: port?.portKey,
      portUrl: url,
      platformName: port?.platformName,
      status: DownloadStatus.downloading,
      progress: useNative ? 0 : 0.03,
      startedAt: DateTime.now(),
      nativeId: useNative ? _nativeIdFor(game.id) : null,
      releaseTag: releaseTag,
    );
    state = <DownloadTask>[task, ...state];
    _persist();
    if (useNative) {
      unawaited(_startNative(task));
    } else {
      _ensureTicker();
      _sync(task);
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _startNative(DownloadTask task) async {
    final String? url = task.portUrl;
    final int? id = task.nativeId;
    if (url == null || id == null) {
      return;
    }
    await NativeDownloader.requestNotifications();
    final bool ok = await NativeDownloader.start(
      id: id,
      url: url,
      title: task.title,
    );
    if (!ok) {
      _update(
        task.gameId,
        (DownloadTask current) => current.copyWith(
          status: DownloadStatus.failed,
          error: 'motor de download indisponível',
        ),
      );
      _persist();
    }
  }

  void _onNativeEvent(NativeDownloadEvent event) {
    final int index = state.indexWhere(
      (DownloadTask task) => task.nativeId == event.id,
    );
    if (index < 0) {
      return;
    }
    final DownloadTask task = state[index];
    switch (event.status) {
      case 'done':
        unawaited(_finishNative(task, event.path));
      case 'failed':
        _update(
          task.gameId,
          (DownloadTask current) => applyNativeEvent(current, event),
        );
        _persist();
      default:
        _update(
          task.gameId,
          (DownloadTask current) => applyNativeEvent(current, event),
        );
    }
  }

  /// Fusão pura de um evento nativo no estado atual da tarefa (visível para
  /// testes). Ponto crítico do contrato: o motor emite DOIS tipos de evento
  /// `downloading` — o rico (~10/s, com velocidade/ETA) e o legado de
  /// notificação (~3/s, sem `speed`/`eta`). O legado chega aqui com
  /// `speedBps`/`etaSecs` nulos e NÃO rebaixa a última estatística válida:
  /// antes ele chegava como 0/-1 e sobrescrevia os valores, fazendo a
  /// velocidade e o tempo restante piscarem na fila do Meu Hub.
  @visibleForTesting
  static DownloadTask applyNativeEvent(
    DownloadTask current,
    NativeDownloadEvent event,
  ) {
    switch (event.status) {
      case 'connecting':
        return current.copyWith(status: DownloadStatus.connecting);
      case 'downloading':
        return current.copyWith(
          status: DownloadStatus.downloading,
          progress: event.progress ?? current.progress,
          // null = evento sem estatística → copyWith mantém o valor anterior.
          speedBps: event.speedBps,
          etaSecs: event.etaSecs,
          doneBytes: event.done,
          totalBytes: event.total,
        );
      case 'verifying':
        return current.copyWith(
          status: DownloadStatus.verifying,
          progress: event.progress ?? current.progress,
        );
      case 'failed':
        return current.copyWith(
          status: DownloadStatus.failed,
          error: event.error ?? 'internal|',
          speedBps: 0,
          etaSecs: -1,
        );
      default:
        return current;
    }
  }

  /// Conclui um download nativo: inspeciona o próprio APK baixado para guardar
  /// o nome do pacote e a versão, junto da tag da release de origem.
  Future<void> _finishNative(DownloadTask task, String? path) async {
    DownloadTask done = task.copyWith(
      status: DownloadStatus.done,
      progress: 1,
      apkPath: path,
    );
    if (path != null) {
      final ApkSummary? apk = await ApkTools.inspect(path);
      if (apk != null) {
        done = done.copyWith(
          packageName: apk.packageName,
          versionName: apk.versionName,
          versionCode: apk.versionCode,
        );
      }
    }
    if (!ref.mounted) {
      return;
    }
    _replace(done);
    _persist();
    _sync(done);
    HapticFeedback.mediumImpact();
    unawaited(_addToLibrary(done));
  }

  void pause(String gameId) {
    final DownloadTask? task = taskFor(gameId);
    if (task?.nativeId != null && task?.status == DownloadStatus.downloading) {
      unawaited(NativeDownloader.cancel(task!.nativeId!));
    }
    _update(
      gameId,
      (DownloadTask current) => current.copyWith(status: DownloadStatus.paused),
    );
    _persist();
    _syncFor(gameId);
    _stopTickerIfIdle();
  }

  void resume(String gameId) {
    final DownloadTask? task = taskFor(gameId);
    _update(
      gameId,
      (DownloadTask current) =>
          current.copyWith(status: DownloadStatus.downloading),
    );
    _persist();
    _syncFor(gameId);
    if (task?.nativeId != null) {
      final DownloadTask? updated = taskFor(gameId);
      if (updated != null) {
        unawaited(_startNative(updated));
      }
    } else {
      _ensureTicker();
    }
    HapticFeedback.selectionClick();
  }

  void cancel(String gameId) {
    final DownloadTask? task = taskFor(gameId);
    if (task?.nativeId != null) {
      unawaited(NativeDownloader.cancel(task!.nativeId!));
    }
    state = state
        .where((DownloadTask item) => item.gameId != gameId)
        .toList(growable: false);
    _persist();
    _stopTickerIfIdle();
  }

  void remove(String gameId) => cancel(gameId);

  /// Reinsere uma tarefa removida (ação "Desfazer" do snackbar). Tarefas
  /// ativas voltam como pausadas — nada é retomado sem gesto do usuário;
  /// se o id já existe de novo, a versão atual vence (nunca regredir estado).
  void restore(DownloadTask task) {
    if (taskFor(task.gameId) != null) {
      return;
    }
    final DownloadTask safe = task.isActive
        ? task.copyWith(status: DownloadStatus.paused)
        : task;
    state = <DownloadTask>[...state, safe];
    _persist();
  }

  void clearCompleted() {
    state = state
        .where((DownloadTask task) => !task.isDone)
        .toList(growable: false);
    _persist();
  }

  DownloadTask? taskFor(String gameId) {
    for (final DownloadTask task in state) {
      if (task.gameId == gameId) {
        return task;
      }
    }
    return null;
  }

  int _nativeIdFor(String gameId) {
    final int raw = gameId.hashCode & 0x7fffffff;
    return raw == 0 ? 1 : raw;
  }

  void _replace(DownloadTask task) {
    state = state
        .map((DownloadTask item) => item.gameId == task.gameId ? task : item)
        .toList(growable: false);
  }

  void _update(String gameId, DownloadTask Function(DownloadTask) transform) {
    state = state
        .map(
          (DownloadTask task) => task.gameId == gameId ? transform(task) : task,
        )
        .toList(growable: false);
  }

  void _ensureTicker() {
    if (_ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 420), (Timer timer) {
      _tick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _ticks = 0;
  }

  bool get _hasSimulated => state.any(
    (DownloadTask task) =>
        task.nativeId == null && task.status == DownloadStatus.downloading,
  );

  void _stopTickerIfIdle() {
    if (!_hasSimulated) {
      _stopTicker();
    }
  }

  void _tick() {
    final List<DownloadTask> next = <DownloadTask>[];
    final List<DownloadTask> finished = <DownloadTask>[];
    for (final DownloadTask task in state) {
      if (task.nativeId != null || task.status != DownloadStatus.downloading) {
        next.add(task);
        continue;
      }
      final double value = task.progress + 0.028;
      if (value >= 1) {
        final DownloadTask done = task.copyWith(
          status: DownloadStatus.done,
          progress: 1,
        );
        next.add(done);
        finished.add(done);
      } else {
        next.add(task.copyWith(progress: value));
      }
    }
    state = next;
    _ticks += 1;
    if (_ticks % 8 == 0) {
      _persist();
    }
    for (final DownloadTask task in finished) {
      _complete(task);
    }
    _stopTickerIfIdle();
  }

  void _complete(DownloadTask task) {
    _persist();
    _sync(task);
    HapticFeedback.mediumImpact();
    unawaited(_addToLibrary(task));
  }

  Future<void> _addToLibrary(DownloadTask task) async {
    try {
      await ref.read(catalogRepositoryProvider).addToLibrary(task.gameId);
      ref.invalidate(collectionsProvider);
    } on Object {
      return;
    }
  }

  void _syncFor(String gameId) {
    for (final DownloadTask task in state) {
      if (task.gameId == gameId) {
        _sync(task);
        return;
      }
    }
  }

  void _sync(DownloadTask task) {
    unawaited(_pushSync(task));
  }

  Future<void> _pushSync(DownloadTask task) async {
    try {
      await ref
          .read(catalogRepositoryProvider)
          .syncDownload(
            gameId: task.gameId,
            portKey: task.portKey,
            status: task.status.name,
            progress: (task.progress * 100).round(),
          );
    } on Object {
      // Sem conexão o estado local continua válido.
    }
  }

  void _persist() {
    final String payload = jsonEncode(
      state.map((DownloadTask task) => task.toJson()).toList(growable: false),
    );
    unawaited(
      ref.read(sharedPreferencesProvider).setString(_storageKey, payload),
    );
  }
}
