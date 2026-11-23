import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/cache_store.dart';
import 'package:portix/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Contrato de sessão do feed: semente estável DENTRO da sessão e diferente
// ENTRE sessões — é o que faz o feed deixar de ser sempre igual sem virar
// aleatoriedade a cada reconstrução de tela.

Future<FeedSession> _session() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return FeedSession(CacheStore(prefs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('anon_id é estável e tem formato de UUID v4', () async {
    final FeedSession session = await _session();
    final String first = session.anonymousId();
    expect(session.anonymousId(), first);

    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
        r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(first),
      isTrue,
      reason: 'anon_id e um UUID v4 opaco',
    );
  });

  test('a semente não muda dentro da mesma janela de 30 minutos', () async {
    final FeedSession session = await _session();
    final DateTime now = DateTime(2026, 1, 1, 12, 0);

    final String a = session.seed(now: now);
    final String b = session.seed(now: now.add(const Duration(minutes: 29)));

    expect(a, equals(b), reason: 'feed estável dentro da sessão');
  });

  test('a semente muda quando a sessão expira (30 min)', () async {
    final FeedSession session = await _session();
    final DateTime now = DateTime(2026, 1, 1, 12, 0);

    final String a = session.seed(now: now);
    final String b = session.seed(now: now.add(const Duration(minutes: 31)));

    expect(a, isNot(equals(b)), reason: 'sessão nova entrega outro feed');
  });

  test('pull-to-refresh gira a semente sem esperar a janela', () async {
    final FeedSession session = await _session();
    final DateTime now = DateTime(2026, 1, 1, 12, 0);

    final String before = session.seed(now: now);
    await session.rotate();
    final String after = session.seed(now: now);

    expect(after, isNot(equals(before)));
  });

  test(
    'usuário autenticado tem semente própria, sem perder o anon_id',
    () async {
      final FeedSession session = await _session();
      final DateTime now = DateTime(2026, 1, 1, 12, 0);

      final String anon = session.seed(now: now);
      final String user = session.seed(userId: 'uid-123', now: now);

      expect(user, isNot(equals(anon)));
      expect(user, contains('uid-123'));
      // O anon_id segue existindo: as impressões continuam sendo registradas.
      expect(session.anonymousId(), isNotEmpty);
    },
  );

  test('refresh consecutivos nunca repetem a semente', () async {
    final FeedSession session = await _session();
    final DateTime now = DateTime(2026, 1, 1, 12, 0);

    final Set<String> seeds = <String>{session.seed(now: now)};
    for (int i = 0; i < 4; i += 1) {
      await session.rotate();
      seeds.add(session.seed(now: now));
    }

    expect(seeds.length, 5, reason: 'cada refresh entrega outro feed');
  });

  test(
    'a semente cabe no limite aceito pelo servidor (64 caracteres)',
    () async {
      final FeedSession session = await _session();
      final String seed = session.seed(
        userId: '11111111-1111-1111-1111-111111111111',
      );
      expect(seed.length, lessThanOrEqualTo(64));
    },
  );
}
