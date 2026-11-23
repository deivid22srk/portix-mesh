import 'package:flutter_test/flutter_test.dart';
import 'package:portix/models/home_feed.dart';

// Contrato do modelo do feed: entende o payload NOVO (`get_home_feed`) e o
// LEGADO (`home_feed`), convertendo o legado em seções para o fallback.

Map<String, dynamic> _card({
  required String id,
  bool isNew = false,
  bool isUpdated = false,
  double score = 1.5,
}) => <String, dynamic>{
  'id': id,
  'slug': id,
  'title': 'Game $id',
  'year': 2024,
  'genre': 'RPG',
  'cover_url': null,
  'platforms': <String>['PC'],
  'port_count': 2,
  'visit_count': 10,
  'download_count': 5,
  'rating_avg': 4.2,
  'rating_count': 3,
  'is_free': false,
  'needs_rom': false,
  'developer': 'Studio X',
  'score': score,
  'is_new': isNew,
  'is_updated': isUpdated,
};

void main() {
  group('HomeFeed.fromMap (payload novo)', () {
    final HomeFeed feed = HomeFeed.fromMap(<String, dynamic>{
      'seed': 'sessao-1',
      'personalized': true,
      'degraded': false,
      'sections': <Object?>[
        <String, dynamic>{
          'key': 'featured',
          'kind': 'hero',
          'reason': null,
          'cursor': null,
          'items': <Object?>[_card(id: 'a', isNew: true)],
        },
        <String, dynamic>{
          'key': 'for_you',
          'kind': 'row',
          'reason': <String, dynamic>{'kind': 'genre', 'value': 'RPG'},
          'cursor': null,
          'items': <Object?>[_card(id: 'b')],
        },
        <String, dynamic>{
          'key': 'discover',
          'kind': 'grid',
          'reason': null,
          'cursor': <String, dynamic>{'score': 1.23, 'id': 'c'},
          'items': <Object?>[_card(id: 'c', isUpdated: true)],
        },
        <String, dynamic>{
          'key': 'category:RPG',
          'kind': 'row',
          'title': 'RPG',
          'reason': null,
          'cursor': null,
          'items': <Object?>[_card(id: 'd')],
        },
      ],
      'platforms': <Object?>[
        <String, dynamic>{
          'slug': 'pc',
          'name': 'PC',
          'kind': 'console',
          'port_count': 10,
        },
      ],
      'genres': <Object?>[
        <String, dynamic>{'name': 'RPG', 'game_count': 42},
      ],
      'stats': <String, dynamic>{'games': 839, 'ports': 1067, 'platforms': 26},
    });

    test('expõe seed, personalização e não está degradado', () {
      expect(feed.seed, 'sessao-1');
      expect(feed.personalized, isTrue);
      expect(feed.degraded, isFalse);
      expect(feed.isEmpty, isFalse);
    });

    test('monta as seções com chave, tipo e motivo', () {
      expect(feed.sections.length, 4);
      expect(feed.sectionByKey('featured')!.isHero, isTrue);
      expect(feed.sectionByKey('for_you')!.reason!.value, 'RPG');
      expect(feed.sectionByKey('category:RPG')!.isCategory, isTrue);
      expect(feed.sectionByKey('category:RPG')!.title, 'RPG');
    });

    test('expõe cursor, selos e score do card', () {
      final HomeFeedSection discover = feed.sectionByKey('discover')!;
      expect(discover.isGrid, isTrue);
      expect(discover.cursor!['score'], 1.23);
      expect(discover.cursor!['id'], 'c');
      expect(discover.items.single.isUpdated, isTrue);
    });

    test('campos extras do card ficam acessíveis (selo e score)', () {
      final item = feed.sectionByKey('featured')!.items.single;
      expect(item.isNew, isTrue);
      expect(item.isUpdated, isFalse);
      expect(item.score, closeTo(1.5, 0.0001));
      expect(item.developer, 'Studio X');
    });

    test('highlights usa a seção featured', () {
      expect(feed.highlights.single.id, 'a');
    });

    test('facetas e estatísticas chegam ao modelo', () {
      expect(feed.platforms.single.name, 'PC');
      expect(feed.genres.single.gameCount, 42);
      expect(feed.stats.ports, 1067);
    });
  });

  group('HomeFeed.fromMap (payload legado → fallback)', () {
    final HomeFeed feed = HomeFeed.fromMap(<String, dynamic>{
      'trending': <Object?>[_card(id: 't')],
      'recent': <Object?>[_card(id: 'r')],
      'top_rated': <Object?>[_card(id: 'x')],
      'free': <Object?>[_card(id: 'f')],
      'classics': <Object?>[_card(id: 'k')],
      'platforms': <Object?>[],
      'genres': <Object?>[],
      'stats': <String, dynamic>{'games': 5, 'ports': 5, 'platforms': 1},
    });

    test('mantém as listas legadas e marca degradado', () {
      expect(feed.degraded, isTrue);
      expect(feed.trending.length, 1);
      expect(feed.recent.single.id, 'r');
      expect(feed.classics.single.id, 'k');
      expect(feed.isEmpty, isFalse);
    });

    test('converte as cinco listas em seções na mesma ordem', () {
      expect(feed.sections.map((HomeFeedSection s) => s.key).toList(), <String>[
        'trending',
        'new_releases',
        'top_rated',
        'free',
        'classics',
      ]);
      expect(feed.sections.every((HomeFeedSection s) => s.isRow), isTrue);
    });

    test('highlights cai no cálculo legado quando não há featured', () {
      expect(feed.highlights.first.id, 't');
    });
  });

  test('feed sem nenhuma lista é vazio', () {
    expect(const HomeFeed().isEmpty, isTrue);
    expect(const HomeFeed().sections, isEmpty);
  });
}
