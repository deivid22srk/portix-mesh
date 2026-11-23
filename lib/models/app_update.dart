import 'parsing.dart';

/// Aviso de atualização publicado pelo ADM raiz.
class AppUpdate {
  const AppUpdate({required this.version, this.message = '', this.url});

  final String version;
  final String message;
  final String? url;

  factory AppUpdate.fromMap(Map<String, dynamic> map) => AppUpdate(
    version: asTextOr(map['version'], ''),
    message: asTextOr(map['message'], ''),
    url: asText(map['url']),
  );
}
