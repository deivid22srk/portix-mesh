import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/core/native_downloader.dart';
import 'package:portix/features/downloads/downloads_controller.dart';
import 'package:portix/features/downloads/downloads_tile.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/models/download_task.dart';

import 'ui_test_helpers.dart';

/// Tarefa em andamento via motor nativo (nativeId casa com os eventos).
DownloadTask _task() => const DownloadTask(
  gameId: 'g1',
  title: 'Super Mario 64',
  slug: 'super-mario-64',
  status: DownloadStatus.downloading,
  progress: 0.3,
  nativeId: 7,
);

/// Evento rico do motor (~10/s, onStats): traz velocidade e ETA.
NativeDownloadEvent _rich({int done = 160, int total = 500}) =>
    NativeDownloadEvent.fromMap(<Object?, Object?>{
      'id': 7,
      'status': 'downloading',
      'done': done,
      'total': total,
      'speed': 2097152.0,
      'eta': 35,
    });

/// Evento legado de notificação (~3/s, onProgress): SEM speed/eta —
/// exatamente o payload emitido por `DownloadService.onProgress`.
NativeDownloadEvent _legacy({int done = 190, int total = 500}) =>
    NativeDownloadEvent.fromMap(<Object?, Object?>{
      'id': 7,
      'status': 'downloading',
      'done': done,
      'total': total,
    });

Future<Widget Function(Widget app)> _withPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return (Widget app) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: app,
  );
}

void main() {
  group('fusão de eventos nativos (DownloadsController.applyNativeEvent)', () {
    test('evento rico alimenta status, progresso, velocidade, ETA e bytes', () {
      final DownloadTask task = DownloadsController.applyNativeEvent(
        _task(),
        _rich(),
      );
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, closeTo(0.32, 0.0001));
      expect(task.speedBps, 2097152.0);
      expect(task.etaSecs, 35);
      expect(task.doneBytes, 160);
      expect(task.totalBytes, 500);
    });

    test(
      'bug do piscar: evento legado de notificação mantém a última estatística',
      () {
        DownloadTask task = DownloadsController.applyNativeEvent(
          _task(),
          _rich(),
        );
        task = DownloadsController.applyNativeEvent(task, _legacy());
        expect(
          task.speedBps,
          2097152.0,
          reason: 'evento legado não pode zerar a velocidade (era o piscar)',
        );
        expect(
          task.etaSecs,
          35,
          reason: 'evento legado não pode apagar o ETA (era o piscar)',
        );
        // Bytes e progresso seguem atualizando normalmente no evento legado.
        expect(task.doneBytes, 190);
        expect(task.progress, closeTo(0.38, 0.0001));
      },
    );

    test('onStats com eta -1 explícito é desconhecido legítimo', () {
      final DownloadTask task = DownloadsController.applyNativeEvent(
        _task(),
        NativeDownloadEvent.fromMap(<Object?, Object?>{
          'id': 7,
          'status': 'downloading',
          'done': 10,
          'total': -1,
          'speed': 12.0,
          'eta': -1,
        }),
      );
      expect(task.speedBps, 12.0);
      expect(task.etaSecs, -1);
    });

    test('connecting/verifying preservam a estatística; falha zera', () {
      final DownloadTask rich = DownloadsController.applyNativeEvent(
        _task(),
        _rich(done: 10, total: 100),
      );
      final DownloadTask connecting = DownloadsController.applyNativeEvent(
        rich,
        NativeDownloadEvent.fromMap(<Object?, Object?>{
          'id': 7,
          'status': 'connecting',
        }),
      );
      expect(connecting.speedBps, 2097152.0);
      expect(connecting.etaSecs, 35);

      final DownloadTask failed = DownloadsController.applyNativeEvent(
        rich,
        NativeDownloadEvent.fromMap(<Object?, Object?>{
          'id': 7,
          'status': 'failed',
          'error': 'network|x',
        }),
      );
      expect(failed.status, DownloadStatus.failed);
      expect(failed.speedBps, 0);
      expect(failed.etaSecs, -1);
    });
  });

  testWidgets(
    'fila estável: velocidade e ETA continuam visíveis após evento legado',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      final DownloadTask rich = DownloadsController.applyNativeEvent(
        _task(),
        _rich(),
      );
      await pumpUi(
        tester,
        child: DownloadTile(task: rich),
        wrap: wrap,
      );
      expect(find.textContaining('2,0 MB/s'), findsOneWidget);
      expect(find.textContaining('0:35'), findsOneWidget);

      // Chega o evento legado (sem estatística): o tile NÃO pode perder os
      // campos — antes disso a linha de stats e o ETA piscavam ~3x/s.
      final DownloadTask after = DownloadsController.applyNativeEvent(
        rich,
        _legacy(),
      );
      await pumpUi(
        tester,
        child: DownloadTile(task: after),
        wrap: wrap,
      );
      expect(find.textContaining('2,0 MB/s'), findsOneWidget);
      expect(find.textContaining('0:35'), findsOneWidget);
      // Bytes evoluíram no mesmo intervalo (o legado é útil para progresso).
      expect(find.textContaining('190 B / 500 B'), findsOneWidget);
    },
  );
}
