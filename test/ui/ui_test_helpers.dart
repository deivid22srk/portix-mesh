import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:portix/app/theme.dart';
import 'package:portix/core/theme/tokens.dart';

/// Dispositivos da varredura de overflow (seção 6 do loop v2).
class UiDevice {
  const UiDevice(this.name, this.size, this.textScale);

  final String name;
  final Size size;
  final double textScale;

  @override
  String toString() =>
      '$name ${size.width.toInt()}x${size.height.toInt()} @$textScale';
}

const List<UiDevice> uiDevices = <UiDevice>[
  UiDevice('telefone pequeno', Size(360, 640), 1.0),
  UiDevice('telefone', Size(411, 891), 1.0),
  UiDevice('tablet', Size(800, 1280), 1.0),
  UiDevice('paisagem', Size(891, 411), 1.0),
  UiDevice('telefone pequeno fonte 2.0', Size(360, 640), 2.0),
  UiDevice('telefone fonte 2.0', Size(411, 891), 2.0),
];

/// Infla `child` dentro do app real (tema Aurora, pt-BR, delegates) no
/// dispositivo informado. Uso:
///
/// ```dart
/// await pumpUi(tester, child: const DownloadTile(task: t));
/// ```
Future<void> pumpUi(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(411, 891),
  double textScale = 1.0,
  ThemeData? theme,
  Widget Function(Widget app)? wrap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  // flutter_test assume android como plataforma padrão — isso faria o app
  // assinar os channels nativos (MissingPluginException). No host de teste
  // tratamos o app como rodando fora do Android, igual ao fallback simulado.
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(tester.view.reset);
  addTearDown(() => debugDefaultTargetPlatformOverride = null);

  final Widget app = MaterialApp(
    theme: theme ?? AppTheme.dark(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (BuildContext context, Widget? inner) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: inner!,
    ),
    home: Scaffold(
      backgroundColor: auroraDark.bg,
      // Corpo rolável: o conteúdo sob teste cresce como numa tela real
      // (SliverList) em vez de estourar o Scaffold no modo paisagem.
      body: SingleChildScrollView(
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );

  await tester.pumpWidget(wrap?.call(app) ?? app);
  await tester.pump();
}

/// Diretrizes oficiais de acessibilidade do Flutter para a árvore atual:
/// alvos de toque 48dp, rótulos em alvos tocáveis e contraste de texto AA.
Future<void> expectMeetsAccessibilityGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Infla `builder` em cada dispositivo e falha se houver RenderFlex overflow.
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget Function(UiDevice device) builder, {
  Widget Function(Widget app)? wrap,
  Duration settle = Duration.zero,
}) async {
  final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) => errors.add(details);
  try {
    for (final UiDevice device in uiDevices) {
      await pumpUi(
        tester,
        child: builder(device),
        size: device.size,
        textScale: device.textScale,
        wrap: wrap,
      );
      if (settle != Duration.zero) {
        await tester.pump(settle);
      }
    }
  } finally {
    FlutterError.onError = previous;
  }
  final List<String> overflows = errors
      .map((FlutterErrorDetails e) => e.exception.toString())
      .where(
        (String message) =>
            message.contains('RenderFlex') || message.contains('overflowed'),
      )
      .toList();
  expect(
    overflows,
    isEmpty,
    reason: 'Overflow detectado nos dispositivos: ${uiDevices.join(', ')}',
  );
}
