import 'package:shared_preferences/shared_preferences.dart';

/// Sala (tópico) única da malha PORTIX. Todos os dispositivos do app entram
/// na mesma sala; os relays agregam a presença por sala.
const String kMeshRoom = 'portix';

/// Relays padrão embutidos no build:
///   `--dart-define=PORTIX_RELAYS=wss://a.exemplo,wss://b.exemplo`
///
/// Sem a define, a lista começa vazia e o usuário adiciona relays em
/// Configurações → Dados e Rede. A descoberta em rede local continua
/// funcionando sem nenhum relay.
const String _kRelaysDefine = String.fromEnvironment('PORTIX_RELAYS');

/// Relays vindos do build (vazia quando a define não existe).
List<String> builtInRelayUrls() {
  final List<String> urls = <String>[];
  for (final String part in _kRelaysDefine.split(',')) {
    final String? normalized = normalizeRelayUrl(part);
    if (normalized != null && !urls.contains(normalized)) {
      urls.add(normalized);
    }
  }
  return urls;
}

/// Normaliza um endereço para WebSocket.
///
/// Aceita `https://host` (→ `wss://host`), `http://host` (→ `ws://host`),
/// `wss://`/`ws://` prontos ou apenas `host[:porta]`. Devolve `null` quando
/// não é um endereço válido.
String? normalizeRelayUrl(String input) {
  String text = input.trim();
  if (text.isEmpty) {
    return null;
  }
  if (text.startsWith('https://')) {
    text = 'wss://${text.substring('https://'.length)}';
  } else if (text.startsWith('http://')) {
    text = 'ws://${text.substring('http://'.length)}';
  } else if (!text.startsWith('ws://') && !text.startsWith('wss://')) {
    text = 'wss://$text';
  }
  final Uri? uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return text;
}

/// Configuração persistida da malha: ligar/desligar e lista de relays.
class MeshConfig {
  MeshConfig(this._prefs);

  final SharedPreferences _prefs;

  static const String _relaysKey = 'mesh.relays';
  static const String _enabledKey = 'mesh.enabled';

  /// A malha começa ligada: sem ela, não há contagem de dispositivos.
  bool get enabled => _prefs.getBool(_enabledKey) ?? true;

  Future<void> setEnabled(bool value) => _prefs.setBool(_enabledKey, value);

  /// Relays ativos: os do usuário quando existirem; senão, os do build.
  List<String> relayUrls() {
    final List<String>? stored = _prefs.getStringList(_relaysKey);
    if (stored != null) {
      return List<String>.unmodifiable(stored);
    }
    return builtInRelayUrls();
  }

  /// Grava a lista (normalizada e sem repetições).
  Future<void> setRelayUrls(List<String> urls) {
    final List<String> clean = <String>[];
    for (final String url in urls) {
      final String? normalized = normalizeRelayUrl(url);
      if (normalized != null && !clean.contains(normalized)) {
        clean.add(normalized);
      }
    }
    return _prefs.setStringList(_relaysKey, clean);
  }

  /// Volta à lista embutida no build (remove a personalizada).
  Future<void> resetRelayUrls() => _prefs.remove(_relaysKey);
}
