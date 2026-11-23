import 'parsing.dart';

/// Perfil do usuário (conta real). Capa de perfil é opcional.
class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName = '',
    this.coverUrl,
    this.handle,
  });

  final String id;
  final String displayName;
  final String? coverUrl;
  final String? handle;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: asTextOr(map['id'], ''),
    displayName: asTextOr(map['display_name'], ''),
    coverUrl: asText(map['cover_url']),
    handle: asText(map['handle']),
  );

  /// Mesmo formato do banco — permite persistir o último valor bom no
  /// CacheStore (stale-while-revalidate) e reler com [UserProfile.fromMap].
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'display_name': displayName,
    'cover_url': coverUrl,
    'handle': handle,
  };
}
