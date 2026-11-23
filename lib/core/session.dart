import 'dart:math';

import 'cache_store.dart';

/// Identidade e janela de sessão do feed.
///
/// Duas necessidades de uma vez:
///   1. **Rotação** — sem uma semente que mude, o ranking devolve sempre a mesma
///      ordem (era a causa raiz do "sempre as mesmas coisas"). A semente é
///      derivada de quem está usando o app + uma janela de 30 minutos, então
///      abrir o app depois de meia hora em segundo plano já entrega outro feed.
///   2. **Estabilidade** — dentro da mesma sessão a semente não muda, então o
///      feed não troca de ordem sozinho enquanto o usuário olha para a tela.
///
/// O `anon_id` é um UUID opaco por instalação (nunca um identificador de
/// pessoa): serve só para o servidor não repetir os mesmos itens para a mesma
/// instalação e para registrar impressões.
class FeedSession {
  FeedSession(this._cache, {Random? random})
    : _random = random ?? Random.secure();

  final CacheStore _cache;
  final Random _random;

  /// Chaves no cache local (`cache.` é prefixado pelo CacheStore).
  static const String _anonKey = 'feed.anon_id';
  static const String _nonceKey = 'feed.seed_nonce';

  /// Tamanho da janela de sessão. Reabrir depois disso já é "sessão nova".
  static const Duration sessionWindow = Duration(minutes: 30);

  /// Identificador opaco da instalação (criado na primeira chamada).
  String anonymousId() {
    final String? stored = _cache.readString(_anonKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final String created = _uuidV4();
    _cache.writeString(_anonKey, created);
    return created;
  }

  /// Semente estável da sessão atual.
  ///
  /// [userId] entra quando existe conta: o mesmo usuário em dois aparelhos não
  /// recebe exatamente o mesmo feed (a identidade muda), mas recebe o mesmo
  /// conjunto de sinais de afinidade.
  String seed({String? userId, DateTime? now}) {
    final String identity = (userId == null || userId.isEmpty)
        ? anonymousId()
        : userId;
    final int bucket =
        (now ?? DateTime.now()).millisecondsSinceEpoch ~/
        sessionWindow.inMilliseconds;
    final int nonce = _nonce();
    return '$identity-$bucket-$nonce';
  }

  /// Gira a semente da sessão: usado pelo pull-to-refresh, que deve trazer
  /// outro feed sem esperar a janela de 30 minutos.
  Future<void> rotate() async {
    _cache.writeString(_nonceKey, '${_nonce() + 1}');
  }

  int _nonce() {
    final String? raw = _cache.readString(_nonceKey);
    if (raw == null) {
      return 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  String _uuidV4() {
    final List<int> bytes = List<int>.generate(
      16,
      (int _) => _random.nextInt(256),
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final String digits = bytes.map(hex).join();
    return '${digits.substring(0, 8)}-${digits.substring(8, 12)}-'
        '${digits.substring(12, 16)}-${digits.substring(16, 20)}-'
        '${digits.substring(20)}';
  }
}
