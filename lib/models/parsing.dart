// Conversores tolerantes: a API pública pode devolver num, String ou null.
double asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

int asInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String? asText(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String asTextOr(Object? value, String fallback) => asText(value) ?? fallback;

List<String> asStringList(Object? value) {
  if (value is List) {
    return value
        .map((Object? item) => asText(item))
        .whereType<String>()
        .toList(growable: false);
  }
  return const <String>[];
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

/// Mapeia uma lista de mapas do payload para uma lista imutável de [T].
///
/// Existe como função (e não como cadeia `asMapList(...).map(...).toList(...)`)
/// porque o portão de formato roda com outra versão do formatador no CI: uma
/// cadeia longa é quebrada em colunas diferentes entre as versões, e uma linha
/// curta não deixa margem para divergência.
List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) from) =>
    asMapList(raw).map(from).toList(growable: false);

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((Map item) => asMap(item))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

DateTime? asDate(Object? value) {
  final String? text = asText(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}
