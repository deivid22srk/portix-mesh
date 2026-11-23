import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Índice em memória do catálogo **embutido no APK**.
///
/// O catálogo é um asset (`assets/catalog/portix_catalog.json`, gerado por
/// `tools/catalog/build_catalog.py` a partir do dump público do NAPL). Como
/// viaja dentro do app, navegar, buscar e abrir fichas **não dependem de
/// nenhuma rede** — não existe servidor de catálogo para derrubar.
class LocalCatalog {
  LocalCatalog._({
    required this.games,
    required this.bySlug,
    required this.portsBySlug,
    required this.platforms,
    required this.genres,
    required this.stats,
    required this.updatedAt,
  });

  final List<Map<String, dynamic>> games;
  final Map<String, Map<String, dynamic>> bySlug;
  final Map<String, List<Map<String, dynamic>>> portsBySlug;
  final List<Map<String, dynamic>> platforms;
  final List<Map<String, dynamic>> genres;
  final Map<String, dynamic> stats;
  final String updatedAt;

  static const String assetPath = 'assets/catalog/portix.json';

  static LocalCatalog _empty() => LocalCatalog._(
    games: const <Map<String, dynamic>>[],
    bySlug: const <String, Map<String, dynamic>>{},
    portsBySlug: const <String, List<Map<String, dynamic>>>{},
    platforms: const <Map<String, dynamic>>[],
    genres: const <Map<String, dynamic>>[],
    stats: const <String, dynamic>{},
    updatedAt: '',
  );

  /// Carrega e indexa o asset. Nunca lança: um asset ausente vira catálogo
  /// vazio (a UI mostra o estado vazio, não um crash).
  static Future<LocalCatalog> load() async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } on Object {
      return _empty();
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      return _empty();
    }
    if (decoded is! Map) {
      return _empty();
    }
    final Map<String, dynamic> document = Map<String, dynamic>.from(decoded);

    final List<Map<String, dynamic>> games = <Map<String, dynamic>>[];
    final Map<String, Map<String, dynamic>> bySlug =
        <String, Map<String, dynamic>>{};
    final Map<String, List<Map<String, dynamic>>> portsBySlug =
        <String, List<Map<String, dynamic>>>{};
    final Object? rawGames = document['games'];
    if (rawGames is List) {
      for (final Object? item in rawGames) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> game = Map<String, dynamic>.from(item);
        final String slug = game['slug']?.toString() ?? '';
        if (slug.isEmpty) {
          continue;
        }
        games.add(game);
        bySlug[slug] = game;
        final List<Map<String, dynamic>> ports = <Map<String, dynamic>>[];
        final Object? rawPorts = game['ports'];
        if (rawPorts is List) {
          for (final Object? port in rawPorts) {
            if (port is Map) {
              ports.add(Map<String, dynamic>.from(port));
            }
          }
        }
        portsBySlug[slug] = ports;
      }
    }

    return LocalCatalog._(
      games: games,
      bySlug: bySlug,
      portsBySlug: portsBySlug,
      platforms: _mapList(document['platforms']),
      genres: _mapList(document['genres']),
      stats: document['stats'] is Map
          ? Map<String, dynamic>.from(document['stats'] as Map)
          : const <String, dynamic>{},
      updatedAt: document['updated_at']?.toString() ?? '',
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final Object? item in value) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }

  Map<String, dynamic>? game(String slug) => bySlug[slug];

  List<Map<String, dynamic>> ports(String slug) =>
      portsBySlug[slug] ?? const <Map<String, dynamic>>[];

  /// Nome da plataforma a partir do slug (para o filtro da busca).
  String? platformName(String slug) {
    for (final Map<String, dynamic> platform in platforms) {
      if (platform['slug']?.toString() == slug) {
        return platform['name']?.toString();
      }
    }
    return null;
  }
}
