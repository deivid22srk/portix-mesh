import 'dart:convert';

import 'package:http/http.dart' as http;

/// Repositório GitHub (owner/repo) extraído de uma URL de port.
class GithubRepo {
  const GithubRepo(this.owner, this.repo);

  final String owner;
  final String repo;

  String get id => '$owner/$repo';

  @override
  String toString() => id;
}

const Set<String> _reservedPaths = <String>{
  'releases',
  'tags',
  'tree',
  'blob',
  'issues',
  'pulls',
  'actions',
  'raw',
  'download',
  'archive',
  'sponsors',
};

/// Extrai owner/repo de uma URL do GitHub (ex.: github.com/owner/repo).
GithubRepo? githubRepoOf(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !uri.host.toLowerCase().endsWith('github.com')) {
    return null;
  }
  final List<String> segments = uri.pathSegments
      .where((String part) => part.isNotEmpty)
      .toList();
  if (segments.length < 2 || _reservedPaths.contains(segments[0])) {
    return null;
  }
  return GithubRepo(segments[0], segments[1]);
}

/// Um arquivo .apk anexado a uma release.
class ApkAsset {
  const ApkAsset({
    required this.name,
    required this.url,
    this.sizeBytes = 0,
    this.downloadCount = 0,
  });

  final String name;
  final String url;
  final int sizeBytes;
  final int downloadCount;

  factory ApkAsset.fromMap(Map<Object?, Object?> map) {
    final Object? size = map['size'];
    final Object? downloads = map['download_count'];
    return ApkAsset(
      name: (map['name'] ?? '').toString(),
      url: (map['browser_download_url'] ?? '').toString(),
      sizeBytes: size is num ? size.toInt() : 0,
      downloadCount: downloads is num ? downloads.toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'url': url,
    'sizeBytes': sizeBytes,
    'downloadCount': downloadCount,
  };

  factory ApkAsset.fromJson(Map<String, dynamic> map) => ApkAsset(
    name: (map['name'] ?? '').toString(),
    url: (map['url'] ?? '').toString(),
    sizeBytes: map['sizeBytes'] is num ? (map['sizeBytes'] as num).toInt() : 0,
    downloadCount: map['downloadCount'] is num
        ? (map['downloadCount'] as num).toInt()
        : 0,
  );
}

/// Uma release do GitHub (tag, notas em markdown e assets .apk).
class GithubRelease {
  const GithubRelease({
    required this.tag,
    required this.assets,
    this.name,
    this.publishedAt,
    this.body,
    this.prerelease = false,
  });

  /// Etiqueta da release (ex.: `v1.2.0`).
  final String tag;

  /// APKs anexados à release.
  final List<ApkAsset> assets;

  /// Nome amigável declarado na release (pode diferir da tag).
  final String? name;

  /// Data de publicação (null em releases ainda não publicadas).
  final DateTime? publishedAt;

  /// Corpo das notas da release, em markdown.
  final String? body;

  /// `true` quando a release foi marcada como pré-release (beta).
  final bool prerelease;

  bool get hasApk => assets.isNotEmpty;

  /// Soma dos downloads de todos os assets .apk.
  int get downloadCount => assets.fold<int>(
    0,
    (int total, ApkAsset asset) => total + asset.downloadCount,
  );

  factory GithubRelease.fromMap(Map<Object?, Object?> map) {
    final List<ApkAsset> apks = <ApkAsset>[];
    final Object? rawAssets = map['assets'];
    if (rawAssets is List) {
      for (final Object? asset in rawAssets) {
        if (asset is Map) {
          final ApkAsset parsed = ApkAsset.fromMap(asset);
          if (parsed.url.isNotEmpty &&
              parsed.name.toLowerCase().endsWith('.apk')) {
            apks.add(parsed);
          }
        }
      }
    }
    return GithubRelease(
      tag: (map['tag_name'] ?? '').toString(),
      assets: apks,
      name: (map['name'] as String?)?.trim(),
      publishedAt: _dateOf(map['published_at']),
      body: (map['body'] as String?)?.trim(),
      prerelease: map['prerelease'] == true,
    );
  }

  static DateTime? _dateOf(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tag': tag,
    'name': name,
    'publishedAt': publishedAt?.toIso8601String(),
    'body': body,
    'prerelease': prerelease,
    'assets': assets
        .map((ApkAsset asset) => asset.toJson())
        .toList(growable: false),
  };

  factory GithubRelease.fromJson(Map<String, dynamic> map) => GithubRelease(
    tag: (map['tag'] ?? '').toString(),
    name: map['name'] as String?,
    publishedAt: map['publishedAt'] is String
        ? DateTime.tryParse(map['publishedAt'] as String)
        : null,
    body: map['body'] as String?,
    prerelease: map['prerelease'] == true,
    assets: (map['assets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ApkAsset.fromJson)
        .toList(growable: false),
  );
}

/// Perfil público do dono do repositório (usuário ou organização).
class GithubUser {
  const GithubUser({
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    this.name,
    this.bio,
    this.type = 'User',
    this.publicRepos = 0,
    this.followers = 0,
  });

  final String login;
  final String? name;
  final String avatarUrl;
  final String htmlUrl;
  final String? bio;
  final String type;
  final int publicRepos;
  final int followers;

  bool get isOrganization => type == 'Organization';

  /// Nome para exibição: `name` com fallback para o `login`.
  String get displayName =>
      (name == null || name!.trim().isEmpty) ? login : name!.trim();

  /// URL do avatar com tamanho fixo (sem query aleatória) para o cache bater.
  String avatarUrlFor(int size) {
    final String base = avatarUrl.split('?').first;
    return '$base?s=${size.round()}';
  }

  factory GithubUser.fromMap(Map<Object?, Object?> map) => GithubUser(
    login: (map['login'] ?? '').toString(),
    name: map['name'] as String?,
    avatarUrl: (map['avatar_url'] ?? '').toString(),
    htmlUrl: (map['html_url'] ?? '').toString(),
    bio: map['bio'] as String?,
    type: (map['type'] ?? 'User').toString(),
    publicRepos: map['public_repos'] is num
        ? (map['public_repos'] as num).toInt()
        : 0,
    followers: map['followers'] is num ? (map['followers'] as num).toInt() : 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'login': login,
    'name': name,
    'avatarUrl': avatarUrl,
    'htmlUrl': htmlUrl,
    'bio': bio,
    'type': type,
    'publicRepos': publicRepos,
    'followers': followers,
  };

  factory GithubUser.fromJson(Map<String, dynamic> map) => GithubUser(
    login: (map['login'] ?? '').toString(),
    name: map['name'] as String?,
    avatarUrl: (map['avatarUrl'] ?? '').toString(),
    htmlUrl: (map['htmlUrl'] ?? '').toString(),
    bio: map['bio'] as String?,
    type: (map['type'] ?? 'User').toString(),
    publicRepos: map['publicRepos'] is num
        ? (map['publicRepos'] as num).toInt()
        : 0,
    followers: map['followers'] is num ? (map['followers'] as num).toInt() : 0,
  );
}

// ============================================================================
// Regras puras (sem I/O) para seleção de versões — cobertas por testes.
// ============================================================================

/// Ordena por data de publicação (mais nova primeiro) e descarta drafts.
/// Releases SEM APK continuam na lista: o seletor as exibe desabilitadas,
/// com explicação (requisito de caso de borda). Pré-releases aparecem com
/// badge "Beta" (decisão conservadora registrada) e nunca são
/// pré-selecionadas por padrão.
List<GithubRelease> visibleReleases(List<GithubRelease> releases) {
  final List<GithubRelease> visible = releases
      .where((GithubRelease release) => release.tag.isNotEmpty)
      .toList(growable: false);
  final List<GithubRelease> sorted = <GithubRelease>[...visible];
  sorted.sort((GithubRelease a, GithubRelease b) {
    final DateTime? aDate = a.publishedAt;
    final DateTime? bDate = b.publishedAt;
    if (aDate != null && bDate != null) {
      return bDate.compareTo(aDate);
    }
    if (aDate != null) {
      return -1;
    }
    if (bDate != null) {
      return 1;
    }
    return 0;
  });
  return sorted;
}

/// Somente releases com APK anexado (usadas para instalação/atualização).
List<GithubRelease> releasesWithApk(List<GithubRelease> releases) => releases
    .where((GithubRelease release) => release.hasApk)
    .toList(growable: false);

/// Escolhe o APK mais compatível de uma release: arm64 > universal > primeiro.
ApkAsset? preferredApkAsset(List<ApkAsset> assets) {
  if (assets.isEmpty) {
    return null;
  }
  if (assets.length == 1) {
    return assets.first;
  }
  for (final ApkAsset asset in assets) {
    final String lower = asset.name.toLowerCase();
    if (lower.contains('arm64') ||
        lower.contains('arm64-v8a') ||
        lower.contains('aarch64')) {
      return asset;
    }
  }
  for (final ApkAsset asset in assets) {
    final String lower = asset.name.toLowerCase();
    if (lower.contains('universal') || lower.contains('all')) {
      return asset;
    }
  }
  return assets.first;
}

/// Comparação semver simplificada: extrai `1.2(.3)` de qualquer tag.
List<int>? semverPartsOf(String tag) {
  final RegExpMatch? match = RegExp(
    r'(\d+)\.(\d+)(?:\.(\d+))?',
  ).firstMatch(tag);
  if (match == null) {
    return null;
  }
  return <int>[
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3) ?? '0'),
  ];
}

/// `true` quando `candidate` é uma versão mais antiga que `installed`
/// (só avisa quando ambas são interpretáveis como semver — decisão
/// conservadora: sem palpite quando a tag não segue o padrão).
bool isOlderThan(String candidateTag, String installedTag) {
  final List<int>? candidate = semverPartsOf(candidateTag);
  final List<int>? installed = semverPartsOf(installedTag);
  if (candidate == null || installed == null) {
    return false;
  }
  for (int index = 0; index < 3; index += 1) {
    if (candidate[index] != installed[index]) {
      return candidate[index] < installed[index];
    }
  }
  return false;
}

/// Decodifica a resposta da listagem de releases em modelos tipados.
List<GithubRelease> parseReleases(http.Response response) {
  final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
  if (body is! List) {
    return const <GithubRelease>[];
  }
  return body
      .whereType<Map<Object?, Object?>>()
      .where((Map<Object?, Object?> map) => map['draft'] != true)
      .map(GithubRelease.fromMap)
      .toList(growable: false);
}
