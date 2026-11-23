import 'parsing.dart';

class Game {
  const Game({
    required this.id,
    required this.slug,
    required this.title,
    this.year,
    this.genre,
    this.coverUrl,
    this.bannerUrl,
    this.developer,
    this.description = '',
    this.platforms = const <String>[],
    this.portCount = 0,
    this.visitCount = 0,
    this.downloadCount = 0,
    this.rating = 0,
    this.ratingCount = 0,
    this.isFree = false,
    this.needsRom = false,
    this.releasedOn,
    this.isNew = false,
    this.isUpdated = false,
    this.score = 0,
  });

  final String id;
  final String slug;
  final String title;
  final int? year;
  final String? genre;
  final String? coverUrl;

  /// Banner horizontal 16:9 — arte de destaque do carrossel da Início.
  /// Preenchido no Supabase só para os jogos que entram no carrossel; nulo
  /// para o resto do catálogo (o carrossel cai para a [coverUrl]).
  final String? bannerUrl;
  final String? developer;
  final String description;
  final List<String> platforms;
  final int portCount;
  final int visitCount;
  final int downloadCount;
  final double rating;
  final int ratingCount;
  final bool isFree;
  final bool needsRom;
  final DateTime? releasedOn;

  /// Selo "NOVO": lançado recentemente (ver `get_home_feed`). Ausente no
  /// catálogo legado — por isso o padrão é `false`.
  final bool isNew;

  /// Selo "ATUALIZADO": o port recebeu atividade recente.
  final bool isUpdated;

  /// Pontuação do ranking do feed (só o feed algorítmico preenche; 0 fora dele).
  final double score;

  bool get hasRating => ratingCount > 0 && rating > 0;
  String get primaryPlatform => platforms.isEmpty ? '' : platforms.first;

  factory Game.fromMap(Map<String, dynamic> map) {
    final int? year = map['year'] == null ? null : asInt(map['year']);
    return Game(
      id: asText(map['id']) ?? asText(map['slug']) ?? '',
      slug: asText(map['slug']) ?? '',
      title: asTextOr(map['title'], 'Sem título'),
      year: year == 0 ? null : year,
      genre: asText(map['genre']),
      coverUrl: asText(map['cover_url']),
      bannerUrl: asText(map['banner_url']),
      developer: asText(map['developer']),
      description: asTextOr(map['description'], ''),
      platforms: asStringList(map['platforms']),
      portCount: asInt(map['port_count']),
      visitCount: asInt(map['visit_count']),
      downloadCount: asInt(map['download_count']),
      rating: asDouble(map['rating_avg']),
      ratingCount: asInt(map['rating_count']),
      isFree: map['is_free'] == true,
      needsRom: map['needs_rom'] == true,
      releasedOn: asDate(map['released_on']),
      isNew: map['is_new'] == true,
      isUpdated: map['is_updated'] == true,
      score: asDouble(map['score']),
    );
  }

  /// Mesmo formato do payload do catálogo — permite persistir/relê-lo.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'slug': slug,
    'title': title,
    'year': year,
    'genre': genre,
    'cover_url': coverUrl,
    'banner_url': bannerUrl,
    'developer': developer,
    'description': description,
    'platforms': platforms,
    'port_count': portCount,
    'visit_count': visitCount,
    'download_count': downloadCount,
    'rating_avg': rating,
    'rating_count': ratingCount,
    'is_free': isFree,
    'needs_rom': needsRom,
    'released_on': releasedOn?.toIso8601String(),
    'is_new': isNew,
    'is_updated': isUpdated,
    'score': score,
  };
}
