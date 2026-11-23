import 'game.dart';
import 'parsing.dart';

/// Perfil público de um usuário (sem e-mail): nome, @, capa, nível e biblioteca.
class PublicProfile {
  const PublicProfile({
    required this.id,
    this.displayName = '',
    this.handle,
    this.coverUrl,
    this.level,
    this.library = const <Game>[],
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? coverUrl;
  final String? level;
  final List<Game> library;

  factory PublicProfile.fromMap(Map<String, dynamic> map) => PublicProfile(
    id: asTextOr(map['id'], ''),
    displayName: asTextOr(map['display_name'], ''),
    handle: asText(map['handle']),
    coverUrl: asText(map['cover_url']),
    level: asText(map['level']),
    library: asMapList(
      map['library'],
    ).map(Game.fromMap).toList(growable: false),
  );
}
