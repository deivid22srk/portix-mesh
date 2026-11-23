import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/theme/tokens.dart';

// ============================================================================
// Renderizador mínimo e seguro de markdown para notas de release.
// Suporta: cabeçalhos (#, ##, ###), listas (-, *, 1.), **negrito**, `código`
// e [link](url). NUNCA interpreta HTML — tags aparecem como texto literal.
// Reconhecedores de link são descartados quando o widget é desmontado.
// ============================================================================

/// Um pedaço parseado de markdown (usado nos testes).
class MarkdownChunk {
  const MarkdownChunk._(this.type, this.text, {this.url});

  final String type; // heading | bullet | paragraph | ordered
  final String text;
  final String? url;
}

/// Parser puro (sem Flutter) — retorna os blocos de uma linha à vez.
List<MarkdownChunk> parseMarkdownLines(String input) {
  final List<MarkdownChunk> chunks = <MarkdownChunk>[];
  final List<String> lines = input.replaceAll('\r\n', '\n').split('\n');
  for (final String raw in lines) {
    final String line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      chunks.add(MarkdownChunk._('heading', heading.group(2)!.trim()));
      continue;
    }
    final RegExpMatch? bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      chunks.add(MarkdownChunk._('bullet', bullet.group(1)!.trim()));
      continue;
    }
    final RegExpMatch? ordered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      chunks.add(
        MarkdownChunk._(
          'ordered',
          ordered.group(2)!.trim(),
          url: ordered.group(1),
        ),
      );
      continue;
    }
    chunks.add(MarkdownChunk._('paragraph', line));
  }
  return chunks;
}

/// Spans inline de um texto: **negrito**, `código`, [link](url).
List<InlineSpan> markdownInlineSpans(
  String text, {
  required TextStyle? base,
  required TextStyle? bold,
  required TextStyle? code,
  required TextStyle? linkStyle,
  required List<TapGestureRecognizer> recognizers,
  required void Function(String url) onLink,
}) {
  final List<InlineSpan> spans = <InlineSpan>[];
  final RegExp pattern = RegExp(
    r'\*\*(.+?)\*\*|`(.+?)`|\[([^\]]+)\]\((https?://[^)\s]+)\)',
  );
  int cursor = 0;
  for (final RegExpMatch match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: base),
      );
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1), style: bold));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(text: match.group(2), style: code));
    } else if (match.group(3) != null && match.group(4) != null) {
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => onLink(match.group(4)!);
      recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: match.group(3),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}

/// Blocos de markdown renderizados com os tokens do tema.
class MarkdownLite extends StatefulWidget {
  const MarkdownLite({
    super.key,
    required this.data,
    this.style,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;

  @override
  State<MarkdownLite> createState() => _MarkdownLiteState();
}

class _MarkdownLiteState extends State<MarkdownLite> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void didUpdateWidget(MarkdownLite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openLink(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Falha ao abrir o navegador não deve derrubar a tela.
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final TextStyle? base = (widget.style ?? context.texts.bodyMedium)
        ?.copyWith(color: context.colors.textSecondary, height: 1.45);

    final List<Widget> blocks = <Widget>[];
    for (final MarkdownChunk chunk in parseMarkdownLines(widget.data)) {
      final bool isHeading = chunk.type == 'heading';
      final bool isBullet = chunk.type == 'bullet';
      final TextStyle? blockStyle = isHeading
          ? context.texts.titleSmall?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            )
          : base;
      final TextStyle? codeStyle = blockStyle?.copyWith(
        fontFamily: 'monospace',
        fontSize: (blockStyle.fontSize ?? 13) - 1,
        color: context.colors.accentAlt,
      );

      blocks.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: isHeading ? AppSpacing.sm : AppSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isBullet) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.compact),
              ] else if (chunk.type == 'ordered') ...<Widget>[
                Text(
                  '${chunk.url}. ',
                  style: base?.copyWith(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: markdownInlineSpans(
                      chunk.text,
                      base: blockStyle,
                      bold: blockStyle?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                      code: codeStyle,
                      linkStyle: blockStyle?.copyWith(
                        color: context.colors.accent,
                        decoration: TextDecoration.underline,
                      ),
                      recognizers: _recognizers,
                      onLink: _openLink,
                    ),
                  ),
                  maxLines: widget.maxLines,
                  overflow: widget.maxLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return SelectionArea(child: Column(children: blocks));
  }
}
