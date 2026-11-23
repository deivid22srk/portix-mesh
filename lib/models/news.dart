import 'parsing.dart';

/// Um artigo de notícia do PORTIX.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    this.titleOriginal,
    this.author,
    this.summary = '',
    this.keyPoints = const <String>[],
    this.coverUrl,
    this.sourceName,
    this.sourceUrl,
    this.projectUrl,
    this.publishedAt,
  });

  final String id;
  final String slug;

  /// Categoria exibida em destaque no card (ex.: `Ports`).
  final String category;
  final String title;
  final String? titleOriginal;
  final String? author;
  final String summary;
  final List<String> keyPoints;
  final String? coverUrl;
  final String? sourceName;
  final String? sourceUrl;
  final String? projectUrl;
  final DateTime? publishedAt;

  factory NewsItem.fromMap(Map<String, dynamic> map) => NewsItem(
    id: asTextOr(map['id'], ''),
    slug: asTextOr(map['slug'], ''),
    category: asTextOr(map['category'], 'Notícias'),
    title: asTextOr(map['title'], ''),
    titleOriginal: asText(map['title_original']),
    author: asText(map['author']),
    summary: asTextOr(map['summary'], ''),
    keyPoints: asStringList(map['key_points']),
    coverUrl: asText(map['cover_url']),
    sourceName: asText(map['source_name']),
    sourceUrl: asText(map['source_url']),
    projectUrl: asText(map['project_url']),
    publishedAt: asDate(map['published_at']),
  );
}

class NewsPayload {
  const NewsPayload({this.items = const <NewsItem>[], this.total = 0});

  final List<NewsItem> items;
  final int total;
}
