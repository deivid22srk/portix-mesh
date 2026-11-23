import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/shared/widgets/markdown_lite.dart';

void main() {
  group('parseMarkdownLines', () {
    test('cabeçalhos, bullets, listas ordenadas e parágrafos', () {
      final List<MarkdownChunk> chunks = parseMarkdownLines('''
## Corrigido nesta versão
- Crash ao iniciar no Android 9
- Suporte a Vulkan 1.3

### Novo
1. Seletor de versões

Texto simples com **negrito** e `código`.
''');
      expect(chunks, hasLength(6));
      expect(chunks[0].type, 'heading');
      expect(chunks[0].text, 'Corrigido nesta versão');
      expect(chunks[1].type, 'bullet');
      expect(chunks[1].text, 'Crash ao iniciar no Android 9');
      expect(chunks[2].type, 'bullet');
      expect(chunks[3].type, 'heading');
      expect(chunks[4].type, 'ordered');
      expect(chunks[5].type, 'paragraph');
    });

    test('linhas vazias são ignoradas', () {
      expect(parseMarkdownLines('\n\n\n'), isEmpty);
    });

    test('HTML cru NÃO é interpretado — aparece como texto literal', () {
      final List<MarkdownChunk> chunks = parseMarkdownLines(
        '<script>alert(1)</script>',
      );
      expect(chunks.single.text, '<script>alert(1)</script>');
      expect(chunks.single.type, 'paragraph');
    });
  });

  group('markdownInlineSpans', () {
    test('negrito, código e link viram spans', () {
      final List<TapGestureRecognizer> recognizers = <TapGestureRecognizer>[];
      String? tappedUrl;
      final List<InlineSpan> spans = markdownInlineSpans(
        'Corrigido **crash** e `bug` no [site](https://example.com)',
        base: const TextStyle(fontSize: 13),
        bold: const TextStyle(fontWeight: FontWeight.bold),
        code: const TextStyle(fontFamily: 'monospace'),
        linkStyle: const TextStyle(color: Colors.blue),
        recognizers: recognizers,
        onLink: (String url) => tappedUrl = url,
      );

      expect(spans, hasLength(6)); // texto/bold/código/texto/link
      expect((spans[0] as TextSpan).text, 'Corrigido ');
      expect((spans[1] as TextSpan).text, 'crash');
      expect((spans[2] as TextSpan).text, ' e ');
      expect((spans[3] as TextSpan).text, 'bug');
      expect((spans[4] as TextSpan).text, ' no ');
      expect((spans[5] as TextSpan).text, 'site');
      expect(recognizers, hasLength(1));

      recognizers.single.onTap?.call();
      expect(tappedUrl, 'https://example.com');
      for (final TapGestureRecognizer recognizer in recognizers) {
        recognizer.dispose();
      }
    });

    test('texto sem marcação vira um único span', () {
      final List<TapGestureRecognizer> recognizers = <TapGestureRecognizer>[];
      final List<InlineSpan> spans = markdownInlineSpans(
        'apenas texto',
        base: const TextStyle(),
        bold: const TextStyle(),
        code: const TextStyle(),
        linkStyle: const TextStyle(),
        recognizers: recognizers,
        onLink: (String url) {},
      );
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'apenas texto');
    });
  });

  testWidgets('MarkdownLite renderiza blocos sem erro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MarkdownLite(
            data:
                '## Novidades\n- **Crash** corrigido\n- Link para o [repo](https://github.com/o/r)\n<script>js</script>',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Novidades'), findsOneWidget);
    expect(find.textContaining('<script>'), findsOneWidget); // HTML literal
    expect(tester.takeException(), isNull);
  });
}
