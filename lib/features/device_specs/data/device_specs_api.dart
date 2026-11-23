import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/env.dart';
import '../../../models/parsing.dart';
import 'device_specs_models.dart';

/// Cliente HTTP da API pública de fichas técnicas.
///
/// Fonte: `phone-specs-api` (dados do GSMArena, sem chave de API).
/// A URL pode ser trocada por outra instância compatível via dart-define:
/// `--dart-define=PORTIX_SPECS_API=https://...`.
class DeviceSpecsApi {
  DeviceSpecsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  static const String defaultBaseUrl = 'https://phone-specs-api.vercel.app';

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const AppFailure(FailureKind.network);
    } catch (_) {
      throw const AppFailure(FailureKind.network);
    }
    if (response.statusCode == 404) {
      throw const AppFailure(FailureKind.notFound);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppFailure(FailureKind.server);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Object?;
    } catch (_) {
      throw const AppFailure(FailureKind.server);
    }
    final Map<String, dynamic> body = decoded is Map
        ? decoded.map(
            (Object? k, Object? v) =>
                MapEntry<String, dynamic>(k.toString(), v),
          )
        : throw const AppFailure(FailureKind.server);
    if (body['status'] != true) {
      throw const AppFailure(FailureKind.server);
    }
    return body;
  }

  /// Lista de marcas disponíveis na base.
  Future<List<DeviceSpecsBrand>> brands() async {
    final Map<String, dynamic> body = await _get(_uri('/brands'));
    return asMapList(
      body['data'],
    ).map(DeviceSpecsBrand.fromMap).toList(growable: false);
  }

  /// Uma página da listagem de aparelhos de uma marca.
  Future<DeviceSpecsBrandPage> brandPage(String brandSlug, int page) async {
    final Map<String, dynamic> body = await _get(
      _uri('/brands/$brandSlug', <String, String>{'page': '$page'}),
    );
    return DeviceSpecsBrandPage.fromMap(body);
  }

  /// Busca direta na API (endpoint opcional — pode estar indisponível em
  /// algumas instâncias; o repositório usa fallback por marca quando falha).
  Future<List<DeviceSpecsSummary>> search(String query) async {
    final Map<String, dynamic> body = await _get(
      _uri('/search', <String, String>{'query': query}),
    );
    return parseDeviceList(body['data']);
  }

  /// Ficha técnica completa por slug.
  Future<DeviceSpecsDetail> device(String slug) async {
    final Map<String, dynamic> body = await _get(_uri('/$slug'));
    final DeviceSpecsDetail detail = DeviceSpecsDetail.fromMap(body);
    if (detail.name.isEmpty) {
      throw const AppFailure(FailureKind.notFound);
    }
    return detail;
  }

  /// Aceita as variações de formato encontradas nas instâncias da API:
  /// `data.phones`, `data.items`, `data` como lista, itens com `phone_name`
  /// ou `name`, `image` ou `thumbnail`.
  static List<DeviceSpecsSummary> parseDeviceList(Object? data) {
    final Map<String, dynamic> map = data is Map
        ? data.map(
            (Object? k, Object? v) =>
                MapEntry<String, dynamic>(k.toString(), v),
          )
        : <String, dynamic>{};
    final List<Map<String, dynamic>> items = map.isNotEmpty
        ? asMapList(map['phones'] ?? map['items'])
        : asMapList(data);
    return items.map(DeviceSpecsSummary.fromMap).toList(growable: false);
  }
}
