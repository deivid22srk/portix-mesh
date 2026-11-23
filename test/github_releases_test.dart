import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/formatters.dart';
import 'package:portix/core/github_releases.dart';

GithubRelease _release(
  String tag, {
  DateTime? publishedAt,
  bool prerelease = false,
  List<ApkAsset> assets = const <ApkAsset>[],
  String? body,
}) => GithubRelease(
  tag: tag,
  publishedAt: publishedAt,
  prerelease: prerelease,
  assets: assets,
  body: body,
);

ApkAsset _apk(String name, {int size = 100, int downloads = 0}) => ApkAsset(
  name: name,
  url: 'https://github.com/o/r/releases/download/$name',
  sizeBytes: size,
  downloadCount: downloads,
);

void main() {
  group('githubRepoOf', () {
    test('extrai owner/repo de URLs do GitHub', () {
      final GithubRepo? repo = githubRepoOf(
        'https://github.com/VinTeRuS/spore-re',
      );
      expect(repo?.owner, 'VinTeRuS');
      expect(repo?.repo, 'spore-re');
      expect(repo?.id, 'VinTeRuS/spore-re');
    });

    test('ignora URLs que não são repos', () {
      expect(githubRepoOf('https://github.com/explore'), isNull);
      expect(githubRepoOf('https://github.com/releases'), isNull); // sem owner
      expect(
        githubRepoOf('https://github.com/releases/tag/v1'),
        isNull,
      ); // path reservado
      expect(githubRepoOf('https://example.com/owner/repo'), isNull);
      expect(githubRepoOf('não é url'), isNull);
    });
  });

  group('visibleReleases', () {
    test('ordena da mais nova para a mais antiga', () {
      final List<GithubRelease> sorted = visibleReleases(<GithubRelease>[
        _release('v1.0.0', publishedAt: DateTime(2026, 1, 1)),
        _release('v1.2.0', publishedAt: DateTime(2026, 3, 1)),
        _release('v1.1.0', publishedAt: DateTime(2026, 2, 1)),
      ]);
      expect(sorted.map((GithubRelease r) => r.tag).toList(), <String>[
        'v1.2.0',
        'v1.1.0',
        'v1.0.0',
      ]);
    });

    test(
      'mantém release sem APK na lista (caso de borda: card desabilitado)',
      () {
        final List<GithubRelease> sorted = visibleReleases(<GithubRelease>[
          _release('v2.0.0', publishedAt: DateTime(2026, 4, 1)), // sem assets
          _release(
            'v1.9.0',
            publishedAt: DateTime(2026, 3, 1),
            assets: <ApkAsset>[_apk('x.apk')],
          ),
        ]);
        expect(sorted, hasLength(2));
        expect(sorted.first.tag, 'v2.0.0');
      },
    );

    test('descarta tags vazias', () {
      final List<GithubRelease> sorted = visibleReleases(<GithubRelease>[
        _release(''),
        _release('v1.0.0', publishedAt: DateTime(2026, 1, 1)),
      ]);
      expect(sorted, hasLength(1));
    });
  });

  group('releasesWithApk', () {
    test('filtra apenas releases com APK', () {
      final List<GithubRelease> filtered = releasesWithApk(<GithubRelease>[
        _release('v2.0.0'),
        _release('v1.9.0', assets: <ApkAsset>[_apk('a.apk')]),
        _release('v1.8.0', assets: <ApkAsset>[_apk('b.apk')]),
      ]);
      expect(filtered.map((GithubRelease r) => r.tag).toList(), <String>[
        'v1.9.0',
        'v1.8.0',
      ]);
    });
  });

  group('preferredApkAsset', () {
    test('retorna o único asset diretamente', () {
      final ApkAsset? asset = preferredApkAsset(<ApkAsset>[_apk('game.apk')]);
      expect(asset?.name, 'game.apk');
    });

    test('prefere arm64 quando existir', () {
      final ApkAsset? asset = preferredApkAsset(<ApkAsset>[
        _apk('game-universal.apk'),
        _apk('game-arm64.apk'),
        _apk('game-v7a.apk'),
      ]);
      expect(asset?.name, 'game-arm64.apk');
    });

    test('prefere universal quando não há arm64', () {
      final ApkAsset? asset = preferredApkAsset(<ApkAsset>[
        _apk('game-v7a.apk'),
        _apk('game-universal.apk'),
      ]);
      expect(asset?.name, 'game-universal.apk');
    });

    test('cai no primeiro quando nomes não indicam ABI', () {
      final ApkAsset? asset = preferredApkAsset(<ApkAsset>[
        _apk('spore.apk'),
        _apk('spore-vk11.apk'),
      ]);
      expect(asset?.name, 'spore.apk');
    });

    test('lista vazia retorna null', () {
      expect(preferredApkAsset(const <ApkAsset>[]), isNull);
    });
  });

  group('isOlderThan', () {
    test('detecta downgrade semver', () {
      expect(isOlderThan('v1.2.0', 'v1.3.0'), isTrue);
      expect(isOlderThan('1.2', '1.2.1'), isTrue);
      expect(isOlderThan('v2.0.0', 'v1.9.9'), isFalse);
      expect(isOlderThan('v1.3.0', 'v1.3.0'), isFalse);
      expect(isOlderThan('v1.3.0', 'v1.2.0'), isFalse);
    });

    test('não arrisca palpite com tags fora do padrão semver', () {
      expect(isOlderThan('nightly-build', 'v1.0.0'), isFalse);
      expect(isOlderThan('v1.0.0', 'versao-instalada'), isFalse);
    });
  });

  group('GithubUser', () {
    test('displayName cai para o login quando name é nulo/vazio', () {
      const GithubUser semNome = GithubUser(
        login: 'spore-dev',
        avatarUrl: 'https://avatars.githubusercontent.com/u/73440180?v=4',
        htmlUrl: 'https://github.com/spore-dev',
      );
      expect(semNome.displayName, 'spore-dev');

      final GithubUser comNome = GithubUser(
        login: 'flutter',
        name: 'Flutter',
        avatarUrl: 'https://avatars.githubusercontent.com/u/14101776?v=4',
        htmlUrl: 'https://github.com/flutter',
        type: 'Organization',
      );
      expect(comNome.displayName, 'Flutter');
      expect(comNome.isOrganization, isTrue);
      expect(semNome.isOrganization, isFalse);
    });

    test('avatarUrlFor gera URL estável com ?s= e sem query aleatória', () {
      const GithubUser user = GithubUser(
        login: 'dev',
        avatarUrl: 'https://avatars.githubusercontent.com/u/73440180?v=4',
        htmlUrl: 'https://github.com/dev',
      );
      expect(
        user.avatarUrlFor(112),
        'https://avatars.githubusercontent.com/u/73440180?s=112',
      );
      expect(user.avatarUrlFor(112), user.avatarUrlFor(112));
    });
  });

  group('GithubRelease JSON (cache de disco)', () {
    test('idem via toJson/fromJson', () {
      final GithubRelease original = _release(
        'v0.1.4',
        publishedAt: DateTime(2026, 11, 16, 19, 45),
        prerelease: false,
        body: 'Notas **bold**',
        assets: <ApkAsset>[_apk('spore.apk', size: 98818871, downloads: 106)],
      );
      final GithubRelease restored = GithubRelease.fromJson(original.toJson());
      expect(restored.tag, 'v0.1.4');
      expect(restored.body, 'Notas **bold**');
      expect(restored.assets.single.name, 'spore.apk');
      expect(restored.assets.single.sizeBytes, 98818871);
      expect(restored.assets.single.downloadCount, 106);
      expect(restored.publishedAt, original.publishedAt);
      expect(restored.downloadCount, 106);
    });

    test('GithubUser idem via toJson/fromJson', () {
      const GithubUser user = GithubUser(
        login: 'dev',
        name: 'Dev',
        avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
        htmlUrl: 'https://github.com/dev',
        bio: 'bio',
        type: 'Organization',
        publicRepos: 13,
        followers: 37,
      );
      final GithubUser restored = GithubUser.fromJson(user.toJson());
      expect(restored.login, 'dev');
      expect(restored.type, 'Organization');
      expect(restored.followers, 37);
    });
  });

  group('formatBytes', () {
    test('formata KB/MB/GB', () {
      // Semântica canônica (padrão do app desde a missão de downloads):
      // `0` → `0 B`; o "—" de tamanho ausente é decisão do chamador.
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(98495287), '93,9 MB');
      expect(formatBytes(1024 * 1024 * 1024 * 2), '2,0 GB');
    });
  });
}
