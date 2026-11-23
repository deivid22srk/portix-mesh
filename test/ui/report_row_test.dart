import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:portix/models/compat_report.dart';
import 'package:portix/shared/widgets/feedback_report_row.dart';

import 'ui_test_helpers.dart';

void main() {
  testWidgets('relato mostra o aparelho e o processador do autor', (
    WidgetTester tester,
  ) async {
    await pumpUi(
      tester,
      child: FeedbackReportRow(
        report: CompatReport(
          author: 'Maria Silva',
          authorHandle: 'maria',
          status: 'good',
          rating: 4,
          fps: 60,
          brand: 'Xiaomi',
          model: 'Redmi Note 10',
          soc: 'Snapdragon 678',
          gpu: 'Adreno 612',
          ramGb: 4,
          body: 'Roda liso em configurações altas.',
        ),
      ),
    );

    // Aparelho no título...
    expect(find.text('Xiaomi Redmi Note 10'), findsOneWidget);
    // ...e processador em linha própria, sempre visível (não depende do
    // espaço restante na linha do autor, que truncava com ellipsis).
    expect(find.textContaining('Snapdragon 678'), findsOneWidget);
    expect(find.textContaining('Adreno 612'), findsOneWidget);
    expect(find.textContaining('4 GB'), findsOneWidget);
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
    // Autor continua na linha de meta.
    expect(find.textContaining('@maria'), findsOneWidget);
  });

  testWidgets('relato sem dados de aparelho não inventa specs', (
    WidgetTester tester,
  ) async {
    await pumpUi(
      tester,
      child: FeedbackReportRow(
        report: CompatReport(author: 'João', status: 'perfect'),
      ),
    );

    expect(find.text('Aparelho'), findsOneWidget); // reserva localizada
    expect(find.byIcon(Icons.memory_rounded), findsNothing);
    expect(find.textContaining('João'), findsOneWidget);
  });

  testWidgets(
    'specs e nomes longos truncam sem overflow em nenhum dispositivo',
    (WidgetTester tester) async {
      await expectNoOverflow(
        tester,
        (UiDevice device) => FeedbackReportRow(
          report: CompatReport(
            author: 'Autoria com nome comprido demais para a linha',
            authorHandle: 'handle_tambem_comprido',
            authorRole: 'admin',
            brand: 'Xiaomi',
            model: 'Redmi Note 10 Pro Max 5G Global Edition',
            soc: 'Snapdragon 778G 5G Octa Core',
            gpu: 'Adreno 642L',
            ramGb: 8,
            fps: 60,
            rating: 5,
            status: 'good',
            body: 'Relato com texto bem longo. ' * 6,
          ),
        ),
      );
    },
  );
}
