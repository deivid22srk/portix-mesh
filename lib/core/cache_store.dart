import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Cache local de leitura: guarda o último payload bom de cada tela para o app
// abrir instantaneamente e continuar útil com conexão ruim (stale-while-revalidate).
class CacheStore {
  CacheStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'cache.';

  Map<String, dynamic>? readMap(String key) {
    final String? raw = _prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  String? readString(String key) {
    final String? raw = _prefs.getString('$_prefix$key');
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> writeString(String key, String value) =>
      _prefs.setString('$_prefix$key', value);

  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _prefs.setString('$_prefix$key', jsonEncode(value));

  List<String> readList(String key) =>
      _prefs.getStringList('$_prefix$key') ?? const <String>[];

  Future<void> writeList(String key, List<String> value) =>
      _prefs.setStringList('$_prefix$key', value);

  Future<void> remove(String key) => _prefs.remove('$_prefix$key');

  Future<void> clearAll() async {
    final List<String> keys = _prefs
        .getKeys()
        .where((String key) => key.startsWith(_prefix))
        .toList(growable: false);
    for (final String key in keys) {
      await _prefs.remove(key);
    }
  }
}
