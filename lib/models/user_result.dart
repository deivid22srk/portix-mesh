import 'parsing.dart';

/// Usuário encontrado na busca (apenas quem tem @handle).
class UserResult {
  const UserResult({
    required this.id,
    this.displayName = '',
    this.handle,
    this.coverUrl,
    this.level,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? coverUrl;
  final String? level;

  factory UserResult.fromMap(Map<String, dynamic> map) => UserResult(
    id: asTextOr(map['id'], ''),
    displayName: asTextOr(map['display_name'], ''),
    handle: asText(map['handle']),
    coverUrl: asText(map['cover_url']),
    level: asText(map['level']),
  );
}

class UserSearchPayload {
  const UserSearchPayload({this.items = const <UserResult>[], this.total = 0});

  final List<UserResult> items;
  final int total;
}
