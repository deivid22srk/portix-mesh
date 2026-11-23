import 'game.dart';
import 'home_feed.dart';
import 'parsing.dart';

// Feed agregado da tela Explorar (RPC `explore_feed`, migration 0025).
// Uma chamada por tela, na convenção do app: seções em carrossel + categorias
// + termos populares + estatísticas. Seções vazias são simplesmente ignoradas
// pela tela (nunca renderiza um carrossel vazio).

class ExploreFeed {
  const ExploreFeed({
    this.trending = const <Game>[],
    this.newReleases = const <Game>[],
    this.topRated = const <Game>[],
    this.free = const <Game>[],
    this.popularSearches = const <Game>[],
    this.genres = const <GenreInfo>[],
    this.stats = const CatalogStats(),
  });

  /// Em alta: popularidade (views/downloads) desc.
  final List<Game> trending;

  /// Novidades: released_on desc.
  final List<Game> newReleases;

  /// Mais bem avaliados: rating_avg desc (só jogos avaliados).
  final List<Game> topRated;

  /// Grátis e aberto.
  final List<Game> free;

  /// "Em alta nas buscas": títulos mais visitados como atalhos de busca.
  ///
  /// Decisão conservadora documentada (sem necessidade de nova coleta): não
  /// existe registro de termos de busca no banco — nem tabelas nem policies —
  /// então o proxy mais próximo é a popularidade (`visit_count`), a mesma
  /// métrica que a Início usa em "Em alta".
  final List<Game> popularSearches;

  /// Grade de categorias (gênero + contagem de jogos).
  final List<GenreInfo> genres;

  final CatalogStats stats;

  bool get isEmpty =>
      trending.isEmpty &&
      newReleases.isEmpty &&
      topRated.isEmpty &&
      free.isEmpty &&
      popularSearches.isEmpty &&
      genres.isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory ExploreFeed.fromMap(Map<String, dynamic> map) => ExploreFeed(
    trending: mapList(map['trending'], Game.fromMap),
    newReleases: mapList(map['new_releases'], Game.fromMap),
    topRated: mapList(map['top_rated'], Game.fromMap),
    free: mapList(map['free'], Game.fromMap),
    popularSearches: mapList(map['popular_searches'], Game.fromMap),
    genres: mapList(map['genres'], GenreInfo.fromMap),
    stats: CatalogStats.fromMap(asMap(map['stats'])),
  );
}
