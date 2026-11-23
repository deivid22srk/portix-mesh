import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/core/providers.dart';
import 'package:portix/features/downloads/downloads_controller.dart';
import 'package:portix/features/downloads/downloads_tile.dart';
import 'package:portix/models/download_task.dart';

import 'ui_test_helpers.dart';

DownloadTask _task(DownloadStatus status, {String? error}) => DownloadTask(
  gameId: 'g1',
  title: 'Super Mario 64',
  slug: 'super-mario-64',
  platformName: 'Nintendo 64',
  portKey: 'sm64',
  portUrl: 'https://example.com/sm64',
  status: status,
  progress: 0.32,
  startedAt: DateTime.now(),
  speedBps: 2097152,
  etaSecs: 194,
  doneBytes: 167772160,
  totalBytes: 524288000,
  error: error,
);

/// Embrulha o app num ProviderScope com SharedPreferences simulado — o
/// DownloadsController lê a fila persistida ao construir (build()).
Future<Widget Function(Widget app)> _withPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return (Widget app) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: app,
  );
}

void main() {
  testWidgets(
    'DownloadTile em download: título, badge, bytes, velocidade, ETA e Semantics',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        child: DownloadTile(task: _task(DownloadStatus.downloading)),
        wrap: wrap,
      );

      expect(find.text('Super Mario 64'), findsOneWidget);
      expect(find.text('32%'), findsOneWidget);
      // 160 MB / 500 MB · 2,0 MB/s
      expect(find.textContaining('160,0 MB / 500,0 MB'), findsOneWidget);
      expect(find.textContaining('2,0 MB/s'), findsOneWidget);
      expect(find.textContaining('3:14'), findsOneWidget);
      // TalkBack anuncia o estado da barra de progresso.
      expect(find.bySemanticsLabel('32%'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'DownloadTile em falha: erro humanizado (sem string crua) + ações',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      await pumpUi(
        tester,
        child: DownloadTile(
          task: _task(DownloadStatus.failed, error: 'network|boom'),
        ),
        wrap: wrap,
      );

      expect(find.textContaining('A conexão caiu'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Abrir fonte'), findsOneWidget);
    },
  );

  testWidgets(
    'Acessibilidade do tile: alvos 48dp, rótulos e contraste (guidelines do Flutter)',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      await pumpUi(
        tester,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DownloadTile(task: _task(DownloadStatus.downloading)),
            DownloadTile(task: _task(DownloadStatus.paused)),
            DownloadTile(
              task: _task(DownloadStatus.failed, error: 'network|boom'),
            ),
            DownloadTile(task: _task(DownloadStatus.done)),
          ],
        ),
        wrap: wrap,
      );

      await expectMeetsAccessibilityGuidelines(tester);
    },
  );

  testWidgets(
    'Sem overflow em 360x640, 411x891, 800x1280, paisagem e fonte 2.0',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      await expectNoOverflow(
        tester,
        (device) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DownloadTile(task: _task(DownloadStatus.downloading)),
            DownloadTile(
              task: _task(DownloadStatus.failed, error: 'disk_full|x'),
            ),
            DownloadTile(task: _task(DownloadStatus.done)),
          ],
        ),
        wrap: wrap,
      );
    },
  );

  testWidgets('Remover com desfazer: snackbar restaura a tarefa concluída', (
    WidgetTester tester,
  ) async {
    final wrap = await _withPrefs();
    await pumpUi(
      tester,
      child: DownloadTile(task: _task(DownloadStatus.done)),
      wrap: wrap,
    );
    final BuildContext context = tester.element(find.byType(DownloadTile));
    final ProviderContainer container = ProviderScope.containerOf(context);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Download removido'), findsOneWidget);
    expect(container.read(downloadsProvider), isEmpty);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(container.read(downloadsProvider), hasLength(1));
    // Tarefa concluída volta como concluída (nunca regride para ativa).
    expect(
      container.read(downloadsProvider).single.status,
      DownloadStatus.done,
    );
  });

  testWidgets(
    'Restaurar tarefa ativa volta como pausada (nunca retoma sozinha)',
    (WidgetTester tester) async {
      final wrap = await _withPrefs();
      await pumpUi(
        tester,
        child: DownloadTile(task: _task(DownloadStatus.downloading)),
        wrap: wrap,
      );
      final BuildContext context = tester.element(find.byType(DownloadTile));
      final ProviderContainer container = ProviderScope.containerOf(context);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(container.read(downloadsProvider), isEmpty);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(
        container.read(downloadsProvider).single.status,
        DownloadStatus.paused,
      );
    },
  );
}
