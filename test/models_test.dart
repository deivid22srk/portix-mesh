import 'package:flutter_test/flutter_test.dart';
import 'package:portix/models/download_task.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/home_feed.dart';
import 'package:portix/models/search.dart';

Map<String, dynamic> _gameMap() => <String, dynamic>{
  'id': 'game-1',
  'slug': 'super-mario-64',
  'title': 'Super Mario 64',
  'year': 1996,
  'genre': 'Platformer',
  'cover_url': 'https://example.com/cover.jpg',
  'platforms': <Object?>['Nintendo 64', null, ''],
  'port_count': '2',
  'visit_count': 1500,
  'download_count': 7,
  'rating_avg': '4.5',
  'rating_count': 8,
  'is_free': true,
  'needs_rom': false,
};

void main() {
  group('Game', () {
    test('converte tipos tolerantes', () {
      final Game game = Game.fromMap(_gameMap());
      expect(game.id, 'game-1');
      expect(game.year, 1996);
      expect(game.platforms, <String>['Nintendo 64']);
      expect(game.portCount, 2);
      expect(game.visitCount, 1500);
      expect(game.downloadCount, 7);
      expect(game.rating, 4.5);
      expect(game.hasRating, isTrue);
      expect(game.isFree, isTrue);
      expect(game.needsRom, isFalse);
      expect(game.primaryPlatform, 'Nintendo 64');
    });

    test('aceita ano zero e capa vazia', () {
      final Game game = Game.fromMap(<String, dynamic>{
        'id': 'x',
        'slug': 'x',
        'title': 'X',
        'year': 0,
        'cover_url': '   ',
        'platforms': <Object?>[],
      });
      expect(game.year, isNull);
      expect(game.coverUrl, isNull);
      expect(game.hasRating, isFalse);
      expect(game.primaryPlatform, '');
    });
  });

  group('GameDetail', () {
    test('lê ports, reviews e relacionados', () {
      final GameDetail detail = GameDetail.fromMap(<String, dynamic>{
        'game': _gameMap(),
        'ports': <Object?>[
          <String, dynamic>{
            'id': 'port-1',
            'port_key': 'mario64-android',
            'platform_name': 'Android',
            'platform_slug': 'android',
            'url': 'https://example.com/port',
            'needs_game_files': true,
            'visits': '12',
          },
        ],
        'reviews': <Object?>[
          <String, dynamic>{'id': 'review-1', 'rating': 5, 'body': 'Roda liso'},
        ],
        'related': <Object?>[
          <String, dynamic>{
            'id': 'game-2',
            'slug': 'mario-kart-64',
            'title': 'Mario Kart 64',
          },
        ],
      });

      expect(detail.game.title, 'Super Mario 64');
      expect(detail.ports.length, 1);
      expect(detail.primaryPort?.url, 'https://example.com/port');
      expect(detail.ports.first.needsGameFiles, isTrue);
      expect(detail.ports.first.visits, 12);
      expect(detail.reviews.single.rating, 5);
      expect(detail.reviews.single.author, '');
      expect(detail.related.single.slug, 'mario-kart-64');
    });

    test('exige o objeto do jogo', () {
      expect(
        () =>
            GameDetail.fromMap(<String, dynamic>{'game': <String, dynamic>{}}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('HomeFeed', () {
    test('monta seções, facetas e estatísticas', () {
      final HomeFeed feed = HomeFeed.fromMap(<String, dynamic>{
        'trending': <Object?>[_gameMap()],
        'platforms': <Object?>[
          <String, dynamic>{
            'slug': 'n64',
            'name': 'Nintendo 64',
            'kind': 'console',
            'port_count': 12,
          },
          <String, dynamic>{
            'slug': 'multi',
            'name': 'Multi-Game Apps',
            'kind': 'multi',
            'port_count': 3,
          },
        ],
        'genres': <Object?>[
          <String, dynamic>{'name': 'Platformer', 'game_count': 40},
        ],
        'stats': <String, dynamic>{
          'games': 839,
          'ports': 1067,
          'platforms': 26,
        },
      });

      expect(feed.trending.length, 1);
      expect(feed.platforms.first.isSecondary, isFalse);
      expect(feed.platforms.last.isSecondary, isTrue);
      expect(feed.genres.single.name, 'Platformer');
      expect(feed.stats.ports, 1067);
      expect(feed.isEmpty, isFalse);
    });

    test('facets reaproveitam os mesmos modelos', () {
      final CatalogFacets facets = CatalogFacets.fromMap(<String, dynamic>{
        'platforms': <Object?>[
          <String, dynamic>{'slug': 'pc', 'name': 'PC', 'kind': 'other'},
        ],
        'genres': <Object?>[
          <String, dynamic>{'name': 'RPG', 'game_count': 7},
        ],
      });
      expect(facets.platforms.single.slug, 'pc');
      expect(facets.genres.single.gameCount, 7);
    });
  });

  group('SearchFilters', () {
    test('conta filtros ativos', () {
      const SearchFilters filters = SearchFilters(
        platform: 'pc',
        genre: 'RPG',
        freeOnly: true,
        needsRom: true,
        sort: 'az',
      );
      expect(filters.activeCount, 5);
      expect(filters.isDefault, isFalse);
      expect(const SearchFilters().isDefault, isTrue);
      expect(filters.copyWith(clearPlatform: true).platform, isNull);
      expect(filters.copyWith(clearGenre: true).genre, isNull);
      expect(filters.copyWith(freeOnly: false).freeOnly, isFalse);
    });
  });

  group('DownloadTask', () {
    test('serializa e restaura estado', () {
      final DownloadTask task = DownloadTask(
        gameId: 'game-1',
        title: 'Super Mario 64',
        slug: 'super-mario-64',
        portKey: 'mario64-android',
        status: DownloadStatus.downloading,
        progress: 0.5,
        startedAt: DateTime.utc(2024, 1, 2),
        releaseTag: 'v1.2.0',
        packageName: 'com.exemplo.mario64',
        versionName: '1.2.0',
        versionCode: 120,
      );

      final DownloadTask restored = DownloadTask.fromJson(task.toJson());
      expect(restored.gameId, 'game-1');
      expect(restored.status, DownloadStatus.downloading);
      expect(restored.progress, 0.5);
      expect(restored.startedAt, DateTime.utc(2024, 1, 2));
      expect(restored.releaseTag, 'v1.2.0');
      expect(restored.packageName, 'com.exemplo.mario64');
      expect(restored.versionName, '1.2.0');
      expect(restored.versionCode, 120);
      expect(restored.isActive, isTrue);
      expect(restored.isDone, isFalse);
    });

    test('status desconhecido vira pausado', () {
      final DownloadTask task = DownloadTask.fromJson(<String, dynamic>{
        'game_id': 'g',
        'title': 'T',
        'slug': 't',
        'status': 'invalido',
        'progress': '0.2',
      });
      expect(task.status, DownloadStatus.paused);
      expect(task.progress, 0.2);
    });
  });
}
