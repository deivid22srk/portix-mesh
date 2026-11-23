import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  // Edge-to-edge: o conteúdo desenha sob as barras do sistema e o app reserva
  // os insets (viewPadding) — evita sobreposição em aparelhos com 3 botões.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // O estilo das barras (ícones claro/escuro) é declarativo: o
  // AnnotatedRegion<SystemUiOverlayStyle> do builder do PortixApp resolve
  // pelo tema já no 1º frame e reage a modo Sistema/brilho do SO.

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PortixApp(),
    ),
  );
}
