import 'parsing.dart';

/// Relato público de como um jogo roda num aparelho (sem expor o user_id).
class CompatReport {
  const CompatReport({
    required this.author,
    required this.status,
    this.authorCover,
    this.authorRole,
    this.authorId,
    this.authorHandle,
    this.rating = 0,
    this.body = '',
    this.fps,
    this.brand,
    this.model,
    this.soc,
    this.gpu,
    this.ramGb,
    this.createdAt,
  });

  final String author;
  final String? authorCover;
  final String? authorRole;
  final String? authorId;
  final String? authorHandle;
  final String status;
  final int rating;
  final String body;
  final int? fps;
  final String? brand;
  final String? model;
  final String? soc;
  final String? gpu;
  final int? ramGb;
  final DateTime? createdAt;

  /// "Marca Modelo" ou o texto de reserva informado pela tela (localizado).
  String deviceLabelOr(String fallback) {
    final List<String> parts = <String>[?brand, ?model];
    return parts.isEmpty ? fallback : parts.join(' ');
  }

  factory CompatReport.fromMap(Map<String, dynamic> map) => CompatReport(
    author: asTextOr(map['author'], ''),
    status: asTextOr(map['status'], 'good'),
    authorCover: asText(map['author_cover']),
    authorRole: asText(map['author_role']),
    authorId: asText(map['author_id']),
    authorHandle: asText(map['author_handle']),
    rating: asInt(map['rating']),
    body: asTextOr(map['body'], ''),
    fps: map['fps'] == null ? null : asInt(map['fps']),
    brand: asText(map['brand']),
    model: asText(map['model']),
    soc: asText(map['soc']),
    gpu: asText(map['gpu']),
    ramGb: map['ram_gb'] == null ? null : asInt(map['ram_gb']),
    createdAt: asDate(map['created_at']),
  );
}
