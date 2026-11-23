import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portix/core/cache_store.dart';
import 'package:portix/core/github_releases.dart';
import 'package:portix/core/github_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _assetJson(String name, int size) => <String, dynamic>{
  'name': name,
  'size': size,
  'download_count': 10,
  'browser_download_url': 'https://github.com/o/r/releases/download/v1/$name',
  'state': 'uploaded',
};

Map<String, dynamic> _releaseJson(
  String tag, {
  DateTime? publishedAt,
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>> assets = const <Map<String, dynamic>>[],
  String body = '',
}) => <String, dynamic>{
  'tag_name': tag,
  'name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'published_at': publishedAt?.toIso8601String(),
  'body': body,
  'assets': assets,
};

http.Response _json(
  Object body, {
  int status = 200,
  Map<String, String> headers = const <String, String>{},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json', ...headers},
);

Future<CacheStore> _disk() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return CacheStore(prefs);
}

void main() {
  tearDown(() => resetFreshTtl());

  test('fetchReleases: descarta drafts e parsing completo', () async {
    final GitHubApi api = GitHubApi(
      cache: await _disk(),
      client: MockClient(
        (http.Request request) async => _json(<Object?>[
          _releaseJson('v9.9.9-draft', draft: true),
          _releaseJson(
            'v1.1.0',
            publishedAt: DateTime(2026, 11, 16),
            assets: <Map<String, dynamic>>[
              _assetJson('game-arm64.apk', 98818871),
            ],
            body: 'Notas **bold**',
          ),
          _releaseJson('v1.0.0', publishedAt: DateTime(2026, 10, 1)),
        ]),
      ),
    );

    final List<GithubRelease> releases = await api.fetchReleases(
      const GithubRepo('o', 'r'),
    );
    expect(releases, hasLength(2)); // draft fora
    expect(releases.first.tag, 'v1.1.0');
    expect(releases.first.assets.single.sizeBytes, 98818871);
    expect(releases.first.body, 'Notas **bold**');
  });

  test(
    'cache em memória: reabrir dentro do TTL = 0 requisições novas',
    () async {
      int calls = 0;
      final GitHubApi api = GitHubApi(
        client: MockClient((http.Request request) async {
          calls += 1;
          return _json(<Object?>[
            _releaseJson('v1.0.0', publishedAt: DateTime(2026, 10, 1)),
          ]);
        }),
      );
      await api.fetchReleases(const GithubRepo('o', 'r'));
      await api.fetchReleases(const GithubRepo('o', 'r'));
      await api.fetchReleases(const GithubRepo('o', 'r'));
      expect(calls, 1); // 3 aberturas, 1 download
    },
  );

  test(
    'ETag: fora do TTL usa If-None-Match e 304 devolve cache intacto',
    () async {
      freshTtlForTest = Duration.zero;
      int calls = 0;
      String? ifNoneMatch;
      final GitHubApi api = GitHubApi(
        client: MockClient((http.Request request) async {
          calls += 1;
          ifNoneMatch = request.headers['If-None-Match'];
          if (calls == 1) {
            return _json(
              <Object?>[
                _releaseJson('v1.0.0', publishedAt: DateTime(2026, 10, 1)),
              ],
              headers: <String, String>{'etag': 'W/"abc123"'},
            );
          }
          return http.Response(
            '',
            304,
            headers: <String, String>{'etag': 'W/"abc123"'},
          );
        }),
      );

      final List<GithubRelease> first = await api.fetchReleases(
        const GithubRepo('o', 'r'),
      );
      final List<GithubRelease> second = await api.fetchReleases(
        const GithubRepo('o', 'r'),
      );

      expect(calls, 2);
      expect(ifNoneMatch, 'W/"abc123"');
      expect(
        second.single.tag,
        first.single.tag,
      ); // 304 não quebra nem recarrega
    },
  );

  test(
    'rate limit (403, remaining=0) sem cache lança exceção tipada',
    () async {
      final GitHubApi api = GitHubApi(
        client: MockClient(
          (http.Request request) async => _json(
            <String, dynamic>{'message': 'API rate limit exceeded'},
            status: 403,
            headers: <String, String>{'x-ratelimit-remaining': '0'},
          ),
        ),
      );
      await expectLater(
        api.fetchReleases(const GithubRepo('o', 'r')),
        throwsA(
          isA<GitHubApiException>().having(
            (GitHubApiException e) => e.kind,
            'kind',
            GitHubErrorKind.rateLimit,
          ),
        ),
      );
    },
  );

  test('rate limit com cache: devolve stale em vez de tela vazia', () async {
    int calls = 0;
    final GitHubApi api = GitHubApi(
      client: MockClient((http.Request request) async {
        calls += 1;
        if (calls == 1) {
          return _json(<Object?>[
            _releaseJson('v1.0.0', publishedAt: DateTime(2026, 10, 1)),
          ]);
        }
        return _json(
          <String, dynamic>{'message': 'API rate limit exceeded'},
          status: 403,
          headers: <String, String>{'x-ratelimit-remaining': '0'},
        );
      }),
    );
    await api.fetchReleases(const GithubRepo('o', 'r'));
    freshTtlForTest = Duration.zero; // força rede na 2ª chamada
    final List<GithubRelease> stale = await api.fetchReleases(
      const GithubRepo('o', 'r'),
    );
    expect(stale, hasLength(1)); // cache stale servido, sem exceção
  });

  test('offline com cache de disco: devolve payload salvo', () async {
    final CacheStore store = await _disk();
    int calls = 0;
    final GitHubApi api = GitHubApi(
      cache: store,
      client: MockClient((http.Request request) async {
        calls += 1;
        if (calls == 1) {
          return _json(
            <Object?>[
              _releaseJson('v1.0.0', publishedAt: DateTime(2026, 10, 1)),
            ],
            headers: <String, String>{'etag': 'W/"x1"'},
          );
        }
        throw http.ClientException('offline');
      }),
    );
    await api.fetchReleases(const GithubRepo('o', 'r'));
    freshTtlForTest = Duration.zero;
    final List<GithubRelease> stale = await api.fetchReleases(
      const GithubRepo('o', 'r'),
    );
    expect(stale.single.tag, 'v1.0.0');
  });

  test('offline sem cache lança exceção offline', () async {
    final GitHubApi api = GitHubApi(
      client: MockClient((http.Request request) async {
        throw http.ClientException('offline');
      }),
    );
    await expectLater(
      api.fetchReleases(const GithubRepo('o', 'r')),
      throwsA(
        isA<GitHubApiException>().having(
          (GitHubApiException e) => e.kind,
          'kind',
          GitHubErrorKind.offline,
        ),
      ),
    );
  });

  test('repo removido/privado (404) lança notFound', () async {
    final GitHubApi api = GitHubApi(
      client: MockClient(
        (http.Request request) async =>
            _json(<String, dynamic>{'message': 'Not Found'}, status: 404),
      ),
    );
    await expectLater(
      api.fetchReleases(const GithubRepo('o', 'r')),
      throwsA(
        isA<GitHubApiException>().having(
          (GitHubApiException e) => e.kind,
          'kind',
          GitHubErrorKind.notFound,
        ),
      ),
    );
  });

  test('fetchUser: parse User com name; 404 devolve null', () async {
    int calls = 0;
    final GitHubApi api = GitHubApi(
      client: MockClient((http.Request request) async {
        calls += 1;
        if (calls == 1) {
          return _json(<String, dynamic>{
            'login': 'VinTeRuS',
            'name': 'VinTeRuS404',
            'avatar_url':
                'https://avatars.githubusercontent.com/u/73440180?v=4',
            'html_url': 'https://github.com/VinTeRuS',
            'bio': null,
            'type': 'User',
            'public_repos': 13,
            'followers': 37,
          });
        }
        return _json(<String, dynamic>{'message': 'Not Found'}, status: 404);
      }),
    );

    final GithubUser? user = await api.fetchUser('VinTeRuS');
    expect(user?.displayName, 'VinTeRuS404');
    expect(user?.publicRepos, 13);
    expect(user?.isOrganization, isFalse);

    expect(await api.fetchUser('ghost-404'), isNull);
  });

  test('fetchUser: Organization com rótulo adequado', () async {
    final GitHubApi api = GitHubApi(
      client: MockClient(
        (http.Request request) async => _json(<String, dynamic>{
          'login': 'flutter',
          'name': 'Flutter',
          'avatar_url': 'https://avatars.githubusercontent.com/u/14101776?v=4',
          'html_url': 'https://github.com/flutter',
          'type': 'Organization',
        }),
      ),
    );
    final GithubUser? user = await api.fetchUser('flutter');
    expect(user?.isOrganization, isTrue);
  });

  test('cache da foto: 5 reaberturas do perfil = 1 download', () async {
    int calls = 0;
    final GitHubApi api = GitHubApi(
      client: MockClient((http.Request request) async {
        calls += 1;
        return _json(
          <String, dynamic>{
            'login': 'VinTeRuS',
            'name': 'VinTeRuS404',
            'avatar_url':
                'https://avatars.githubusercontent.com/u/73440180?v=4',
            'html_url': 'https://github.com/VinTeRuS',
            'type': 'User',
          },
          headers: <String, String>{'etag': 'W/"u1"'},
        );
      }),
    );
    for (int i = 0; i < 5; i++) {
      final GithubUser? user = await api.fetchUser('VinTeRuS');
      expect(user?.displayName, 'VinTeRuS404');
    }
    expect(calls, 1); // 1 download de dados, 4 hits de memória
  });

  test('fetchLatestApkRelease: primeira release com APK', () async {
    final GitHubApi api = GitHubApi(
      client: MockClient(
        (http.Request request) async => _json(<Object?>[
          _releaseJson('v2.0.0', publishedAt: DateTime(2026, 11, 1)), // sem apk
          _releaseJson(
            'v1.5.0',
            publishedAt: DateTime(2026, 10, 1),
            assets: <Map<String, dynamic>>[_assetJson('game.apk', 100)],
          ),
        ]),
      ),
    );
    final GithubRelease? latest = await api.fetchLatestApkRelease(
      const GithubRepo('o', 'r'),
    );
    expect(latest?.tag, 'v1.5.0');
  });
}
