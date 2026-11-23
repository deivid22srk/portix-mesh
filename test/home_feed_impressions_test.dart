import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/home/feed_impressions.dart';

// Impressões: política de opt-out, agrupamento em lote, uma vez por item por
// sessão e confirmação de visibilidade real (RenderBox contra o viewport).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opt-out: ausente ou "on" permite; qualquer outro valor desliga', () {
    expect(feedImpressionsAllowed(null), isTrue);
    expect(feedImpressionsAllowed('on'), isTrue);
    expect(feedImpressionsAllowed('off'), isFalse);
    expect(feedImpressionsAllowed(''), isFalse);
    expect(kFeedImpressionsPrefKey, 'privacy.feed_impressions');
  });

  test('agrupa em lote e envia uma única vez por item', () {
    fakeAsync((FakeAsync async) {
      final List<List<Map<String, dynamic>>> batches =
          <List<Map<String, dynamic>>>[];
      final FeedImpressionTracker tracker = FeedImpressionTracker(
        send: (List<Map<String, dynamic>> items) async => batches.add(items),
        debounce: const Duration(milliseconds: 800),
      );

      tracker.report('a', 'trending', sessionId: 'sessao');
      tracker.report('a', 'trending', sessionId: 'sessao');
      tracker.report('b', 'discover', sessionId: 'sessao');
      expect(tracker.pendingCount, 2);
      expect(tracker.reportedCount, 2);

      async.elapse(const Duration(milliseconds: 900));
      expect(batches.length, 1);
      expect(
        batches.single.map((Map<String, dynamic> e) => e['game_id']).toList(),
        <String>['a', 'b'],
      );
      expect(
        batches.single.every(
          (Map<String, dynamic> e) => e['session_id'] == 'sessao',
        ),
        isTrue,
      );

      // Repetir um item já visto não entra de novo.
      tracker.report('a', 'trending', sessionId: 'sessao');
      expect(tracker.pendingCount, 0);

      // Nova sessão (refresh) libera os itens.
      tracker.reset();
      tracker.report('a', 'trending', sessionId: 'sessao-2');
      expect(tracker.pendingCount, 1);
      async.elapse(const Duration(milliseconds: 900));
      expect(batches.length, 2);

      tracker.dispose();
    });
  });

  test('lote cheio é enviado sem esperar o debounce', () {
    final List<List<Map<String, dynamic>>> batches =
        <List<Map<String, dynamic>>>[];
    final FeedImpressionTracker tracker = FeedImpressionTracker(
      send: (List<Map<String, dynamic>> items) async => batches.add(items),
      batchSize: 3,
    );
    tracker.report('a', 'x');
    tracker.report('b', 'x');
    expect(batches, isEmpty);
    tracker.report('c', 'x');
    expect(batches.length, 1);
    expect(batches.single.length, 3);
    tracker.dispose();
  });

  testWidgets('só marca o card que cruza a área visível', (
    WidgetTester tester,
  ) async {
    final List<List<Map<String, dynamic>>> batches =
        <List<Map<String, dynamic>>>[];
    final FeedImpressionTracker tracker = FeedImpressionTracker(
      send: (List<Map<String, dynamic>> items) async => batches.add(items),
      debounce: const Duration(seconds: 30),
    );
    addTearDown(tracker.dispose);

    tester.view.physicalSize = const Size(400, 150);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemExtent: 100,
            itemCount: 4,
            itemBuilder: (BuildContext context, int index) =>
                FeedImpressionProbe(
                  tracker: tracker,
                  gameId: 'g$index',
                  section: 'discover',
                  child: const SizedBox.expand(),
                ),
          ),
        ),
      ),
    );
    // Um frame para os callbacks pós-layout avaliarem a visibilidade.
    await tester.pump();

    // Itens 0 e 1 estão no viewport (150px); 2 e 3 só no cache extent.
    expect(tracker.reportedCount, 2);
    tracker.flush();
    expect(batches.single.length, 2);
  });
}
