import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Sink de impressões: recebe um lote já pronto para envio.
typedef ImpressionSink =
    Future<void> Function(List<Map<String, dynamic>> items);

/// Registra que um card ficou **realmente visível**.
///
/// Aproximação (sem dependências novas): os builders das listas/grades são
/// preguiçosos — só rodam para o que entra no viewport **e** no cache extent —,
/// então marcar no primeiro build já exclui a maior parte do payload. Quando
/// possível, o [FeedImpressionProbe] confirma por `RenderBox.localToGlobal`
/// contra a área visível antes de marcar; e a página reavalia os probes a cada
/// rolagem. Cada item entra no máximo uma vez por sessão ([_reported]); os
/// lotes são agrupados e enviados por [flush] (debounce curto ou lote cheio).
class FeedImpressionTracker {
  FeedImpressionTracker({
    required this.send,
    this.batchSize = 20,
    this.debounce = const Duration(milliseconds: 800),
  });

  final ImpressionSink send;
  final int batchSize;
  final Duration debounce;

  final Set<String> _reported = <String>{};
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  final List<VoidCallback> _probes = <VoidCallback>[];
  Timer? _timer;
  bool _disposed = false;

  /// Quantos itens já foram enviados (testes/telemetria).
  int get reportedCount => _reported.length;

  /// Itens aguardando envio (testes).
  int get pendingCount => _buffer.length;

  /// Registra um probe para reavaliar visibilidade a cada rolagem.
  void register(VoidCallback check) {
    if (_disposed) {
      return;
    }
    _probes.add(check);
  }

  void unregister(VoidCallback check) => _probes.remove(check);

  /// Reavalia todos os probes montados (chamado no scroll).
  void scan() {
    if (_disposed) {
      return;
    }
    for (final VoidCallback check in List<VoidCallback>.of(_probes)) {
      check();
    }
  }

  /// Marca um card como visto; ignora repetições da mesma sessão.
  void report(String gameId, String section, {String? sessionId}) {
    if (_disposed || gameId.isEmpty || !_reported.add(gameId)) {
      return;
    }
    _buffer.add(<String, dynamic>{
      'game_id': gameId,
      'section': section,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
    });
    _schedule();
  }

  void _schedule() {
    if (_buffer.length >= batchSize) {
      flush();
      return;
    }
    _timer ??= Timer(debounce, flush);
  }

  /// Envia o lote pendente (melhor esforço: erro é ignorado).
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) {
      return;
    }
    final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.of(
      _buffer,
    );
    _buffer.clear();
    unawaited(send(batch));
  }

  /// Nova sessão (pull-to-refresh girou a seed): libera os itens para novo
  /// registro e descarta o lote ainda não enviado.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _reported.clear();
    _buffer.clear();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _probes.clear();
    _buffer.clear();
    _reported.clear();
  }
}

/// Marca o card quando o seu `RenderBox` cruza a área visível.
class FeedImpressionProbe extends StatefulWidget {
  const FeedImpressionProbe({
    super.key,
    required this.tracker,
    required this.gameId,
    required this.section,
    this.sessionId,
    required this.child,
  });

  final FeedImpressionTracker tracker;
  final String gameId;
  final String section;
  final String? sessionId;
  final Widget child;

  @override
  State<FeedImpressionProbe> createState() => _FeedImpressionProbeState();
}

class _FeedImpressionProbeState extends State<FeedImpressionProbe> {
  late final VoidCallback _check = _evaluate;
  bool _reported = false;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.tracker.register(_check);
    // Primeira avaliação depois do layout (o RenderBox já tem tamanho).
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _evaluate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guarda a área visível aqui (build/didChangeDependencies) para não
    // consultar o InheritedWidget de dentro de um callback de rolagem.
    _viewport = MediaQuery.sizeOf(context);
  }

  @override
  void dispose() {
    widget.tracker.unregister(_check);
    super.dispose();
  }

  void _evaluate() {
    if (_reported || !mounted) {
      return;
    }
    final RenderObject? render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return;
    }
    final Rect card = render.localToGlobal(Offset.zero) & render.size;
    // Contra a área da janela (aproximação conservadora: inclui a faixa do
    // cabeçalho, mas nunca marca o que está fora do viewport).
    final Rect viewport = Offset.zero & _viewport;
    if (!card.overlaps(viewport)) {
      return;
    }
    _reported = true;
    widget.tracker.unregister(_check);
    widget.tracker.report(
      widget.gameId,
      widget.section,
      sessionId: widget.sessionId,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
