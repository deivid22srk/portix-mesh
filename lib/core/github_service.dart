import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'cache_store.dart';
import 'github_releases.dart';
import 'providers.dart';

// ============================================================================
// Camada única de dados do GitHub.
// - Cache em memória (válido ~5 min) + em disco (payloads + ETag).
// - Requisições condicionais: If-None-Match → 304 = 0 bytes e UI intacta.
// - Rate limit (403/429) e offline: devolve o payload em cache (stale) quando
//   existir; só falha com exceção tipada quando não há nada para mostrar.
// - NUNCA embute tokens: todas as chamadas são anônimas (limite 60/h por IP).
// ============================================================================

/// Motivo da falha, mapeado para mensagens amigáveis na UI.
enum GitHubErrorKind { offline, rateLimit, notFound, server, unknown }

class GitHubApiException implements Exception {
  const GitHubApiException(this.kind, {this.statusCode});

  final GitHubErrorKind kind;
  final int? statusCode;

  @override
  String toString() => 'GitHubApiException(${kind.name}, $statusCode)';
}

class _Entry {
  _Entry({required this.value, required this.fetchedAt, this.etag});

  dynamic value;
  DateTime fetchedAt;
  String? etag;

  bool get isFresh => DateTime.now().difference(fetchedAt) < _freshTtl;
}

Duration _freshTtl = const Duration(minutes: 5);
@visibleForTesting
set freshTtlForTest(Duration value) => _freshTtl = value;
@visibleForTesting
void resetFreshTtl() => _freshTtl = const Duration(minutes: 5);

class GitHubApi {
  GitHubApi({http.Client? client, CacheStore? cache})
    : _client = client ?? http.Client(),
      _cache = cache;

  final http.Client _client;
  final CacheStore? _cache;

  final Map<String, _Entry> _memory = <String, _Entry>{};

  static const String _accept = 'application/vnd.github+json';
  static const String _userAgent = 'PORTIX';
  static const String _baseUrl = 'https://api.github.com';

  // ---------------------------------------------------------------- helpers

  String? _memoryEtag(String key) => _memory[key]?.etag;

  String? _diskEtag(String key) => _diskEntry(key)?['etag'] as String?;

  Map<String, dynamic>? _diskEntry(String key) {
    return _cache?.readMap(key);
  }

  /// Salva payload + etag + timestamp em disco.
  Future<void> _writeDisk(String key, String? etag, dynamic value) async {
    await _cache?.writeMap(key, <String, dynamic>{
      'etag': etag,
      'ts': DateTime.now().toIso8601String(),
      'data': value,
    });
  }

  Future<Map<String, String>> _requestHeaders(String key, String? etag) async {
    final Map<String, String> headers = <String, String>{
      'Accept': _accept,
      'User-Agent': _userAgent,
    };
    final String? known = etag ?? _memoryEtag(key) ?? _diskEtag(key);
    if (known != null && known.isNotEmpty) {
      headers['If-None-Match'] = known;
    }
    return headers;
  }

  // ------------------------------------------------------------- principais

  /// Releases de um repo (drafts descartados na origem). Prioridade:
  /// memória fresca → requisição condicional → disco (stale).
  Future<List<GithubRelease>> fetchReleases(GithubRepo repo) async {
    final String key = 'gh.releases.${repo.id}';
    final _Entry? memory = _memory[key];

    // 1) Memória fresca: zero requisições ao reabrir a tela.
    if (memory != null && memory.isFresh) {
      return _asReleases(memory.value);
    }

    // 2) Cache de disco sem rede? Só usado como fallback (stale).
    final List<GithubRelease> diskData =
        _diskReleases(key) ?? const <GithubRelease>[];

    try {
      final http.Response response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/repos/${repo.owner}/${repo.repo}/releases?per_page=20',
            ),
            headers: await _requestHeaders(key, memory?.etag),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 304) {
        // 304 = nada mudou: reidrata a memória (0 bytes na rede) e devolve
        // o payload que a UI já conhece, sem recarregar nada.
        final dynamic payload =
            memory?.value ??
            diskData
                .map((GithubRelease r) => r.toJson())
                .toList(growable: false);
        _touch(key, memory?.etag ?? _diskEtag(key), payload);
        return _asReleases(payload);
      }

      if (response.statusCode == 200) {
        final String etag = response.headers['etag'] ?? '';
        final List<GithubRelease> releases = parseReleases(response);
        // Memória guarda SEMPRE o mesmo formato (JSON) que o disco.
        _memory[key] = _Entry(
          value: releases
              .map((GithubRelease r) => r.toJson())
              .toList(growable: false),
          fetchedAt: DateTime.now(),
          etag: etag,
        );
        await _writeDisk(
          key,
          etag,
          releases.map((GithubRelease r) => r.toJson()).toList(),
        );
        return releases;
      }

      if (response.statusCode == 404) {
        throw const GitHubApiException(
          GitHubErrorKind.notFound,
          statusCode: 404,
        );
      }

      if (_isRateLimited(response)) {
        throw GitHubApiException(
          GitHubErrorKind.rateLimit,
          statusCode: response.statusCode,
        );
      }

      throw GitHubApiException(
        GitHubErrorKind.server,
        statusCode: response.statusCode,
      );
    } on GitHubApiException {
      // 3) Falha HTTP com cache disponível: devolve stale em vez de quebrar.
      if (memory != null) {
        return _asReleases(memory.value);
      }
      if (diskData.isNotEmpty) {
        return diskData;
      }
      rethrow;
    } on TimeoutException {
      throw const GitHubApiException(GitHubErrorKind.offline);
    } on Object catch (error) {
      final bool networkish =
          error is http.ClientException ||
          error.toString().contains('SocketException') ||
          error.toString().contains('Failed host lookup');
      if (memory != null) {
        return _asReleases(memory.value);
      }
      if (diskData.isNotEmpty) {
        return diskData;
      }
      throw GitHubApiException(
        networkish ? GitHubErrorKind.offline : GitHubErrorKind.unknown,
      );
    }
  }

  /// Perfil público do dono do repo. 404 devolve `null` (caso normal:
  /// owner renomeado/conta removida) — a UI mostra fallback com iniciais.
  Future<GithubUser?> fetchUser(String owner) async {
    final String key = 'gh.user.$owner';
    final _Entry? memory = _memory[key];
    if (memory != null && memory.isFresh) {
      return _asUser(memory.value);
    }

    final GithubUser? diskUser = _diskUser(key);

    try {
      final http.Response response = await _client
          .get(
            Uri.parse('$_baseUrl/users/$owner'),
            headers: await _requestHeaders(key, memory?.etag),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 304) {
        final GithubUser? current = memory != null
            ? _asUser(memory.value)
            : diskUser;
        _touch(key, memory?.etag ?? _diskEtag(key), current?.toJson());
        return current;
      }

      if (response.statusCode == 200) {
        final String etag = response.headers['etag'] ?? '';
        final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
        final GithubUser? user = body is Map ? GithubUser.fromMap(body) : null;
        _memory[key] = _Entry(
          value: user?.toJson(),
          fetchedAt: DateTime.now(),
          etag: etag,
        );
        await _writeDisk(key, etag, user?.toJson());
        return user;
      }

      if (response.statusCode == 404) {
        return null;
      }
      if (_isRateLimited(response)) {
        throw GitHubApiException(
          GitHubErrorKind.rateLimit,
          statusCode: response.statusCode,
        );
      }
      throw GitHubApiException(
        GitHubErrorKind.server,
        statusCode: response.statusCode,
      );
    } on GitHubApiException {
      if (memory != null) {
        return _asUser(memory.value);
      }
      return diskUser;
    } on TimeoutException {
      throw const GitHubApiException(GitHubErrorKind.offline);
    } on Object catch (error) {
      final bool networkish =
          error is http.ClientException ||
          error.toString().contains('SocketException') ||
          error.toString().contains('Failed host lookup');
      if (memory != null) {
        return _asUser(memory.value);
      }
      if (diskUser != null) {
        return diskUser;
      }
      throw GitHubApiException(
        networkish ? GitHubErrorKind.offline : GitHubErrorKind.unknown,
      );
    }
  }

  /// Última release com APK (atalho usado para detectar atualizações).
  Future<GithubRelease?> fetchLatestApkRelease(GithubRepo repo) async {
    final List<GithubRelease> releases = await fetchReleases(repo);
    for (final GithubRelease release in releasesWithApk(
      visibleReleases(releases),
    )) {
      return release;
    }
    return null;
  }

  /// Limpa somente a memória (o disco persiste para uso offline).
  void clearMemory() => _memory.clear();

  // ------------------------------------------------------------------ utils

  bool _isRateLimited(http.Response response) {
    final String remaining = response.headers['x-ratelimit-remaining'] ?? '';
    if (response.statusCode == 429) {
      return true;
    }
    if (response.statusCode == 403) {
      return remaining == '0' || response.body.contains('rate limit');
    }
    return false;
  }

  void _touch(String key, String? etag, dynamic value) {
    _memory[key] = _Entry(value: value, fetchedAt: DateTime.now(), etag: etag);
  }

  List<GithubRelease> _asReleases(dynamic value) =>
      (value as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(GithubRelease.fromJson)
          .toList(growable: false) ??
      const <GithubRelease>[];

  GithubUser? _asUser(dynamic value) =>
      value is Map<String, dynamic> ? GithubUser.fromJson(value) : null;

  List<GithubRelease>? _diskReleases(String key) {
    final Object? raw = _diskEntry(key)?['data'];
    if (raw is! List) {
      return null;
    }
    return raw
        .whereType<Map>()
        .map(
          (Map item) => GithubRelease.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  GithubUser? _diskUser(String key) {
    final Object? raw = _diskEntry(key)?['data'];
    if (raw is! Map) {
      return null;
    }
    return GithubUser.fromJson(Map<String, dynamic>.from(raw));
  }
}

// ----------------------------------------------------------------------------
// Providers — um único ponto de acesso para toda a UI.
// ----------------------------------------------------------------------------

final githubApiProvider = Provider<GitHubApi>(
  (ref) => GitHubApi(cache: ref.watch(cacheStoreProvider)),
);

/// Releases de `owner/repo` (parâmetro no formato "owner/repo").
final repoReleasesProvider = FutureProvider.autoDispose
    .family<List<GithubRelease>, String>((ref, String repoId) {
      final List<String> parts = repoId.split('/');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        return Future<List<GithubRelease>>.value(const <GithubRelease>[]);
      }
      return ref
          .watch(githubApiProvider)
          .fetchReleases(GithubRepo(parts[0], parts[1]));
    });

/// Perfil do dono do repositório (ex.: "VinTeRuS").
final githubUserProvider = FutureProvider.autoDispose
    .family<GithubUser?, String>((ref, String owner) {
      if (owner.isEmpty) {
        return Future<GithubUser?>.value(null);
      }
      return ref.watch(githubApiProvider).fetchUser(owner);
    });
