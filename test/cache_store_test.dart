import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// O feed precisa de duas chaves simples no cache local (anon_id da instalação e
// contador de rotação da sessão). `readString`/`writeString` cobrem isso sem
// serializar um mapa inteiro.

Future<CacheStore> _store() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return CacheStore(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('readString devolve null quando a chave não existe', () async {
    final CacheStore store = await _store();
    expect(store.readString('feed.anon_id'), isNull);
  });

  test('writeString e readString preservam o valor', () async {
    final CacheStore store = await _store();
    await store.writeString('feed.anon_id', 'abc-123');
    expect(store.readString('feed.anon_id'), 'abc-123');
  });

  test('string vazia é tratada como ausente', () async {
    final CacheStore store = await _store();
    await store.writeString('feed.seed_nonce', '');
    expect(store.readString('feed.seed_nonce'), isNull);
  });

  test('as chaves ficam isoladas sob o prefixo do cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final CacheStore store = CacheStore(prefs);

    await store.writeString('feed.anon_id', 'abc-123');

    expect(prefs.getString('cache.feed.anon_id'), 'abc-123');
    expect(prefs.getString('feed.anon_id'), isNull);
  });

  test('clearAll remove as chaves do cache', () async {
    final CacheStore store = await _store();
    await store.writeString('feed.anon_id', 'abc-123');
    await store.clearAll();
    expect(store.readString('feed.anon_id'), isNull);
  });
}
