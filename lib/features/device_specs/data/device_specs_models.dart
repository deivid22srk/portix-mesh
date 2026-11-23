import '../../../models/parsing.dart';

/// Aparelho resumido (resultado de busca ou de listagem de marca).
///
/// `slug` é a chave do GSMArena (ex.: `xiaomi_poco_x6_pro-12814`) e é o que
/// abre a ficha técnica completa.
class DeviceSpecsSummary {
  const DeviceSpecsSummary({
    required this.name,
    required this.slug,
    this.imageUrl,
    this.brand,
  });

  final String name;
  final String slug;
  final String? imageUrl;
  final String? brand;

  factory DeviceSpecsSummary.fromMap(Map<String, dynamic> map) =>
      DeviceSpecsSummary(
        name: asTextOr(map['phone_name'] ?? map['name'], ''),
        slug: asTextOr(map['slug'], ''),
        imageUrl: asText(map['image'] ?? map['thumbnail']),
        brand: asText(map['brand']),
      );
}

/// Uma linha de especificação (`Tela` → `Tipo`, `Resolução`...).
class DeviceSpecRow {
  const DeviceSpecRow({required this.key, required this.values});

  final String key;
  final List<String> values;

  factory DeviceSpecRow.fromMap(Map<String, dynamic> map) => DeviceSpecRow(
    key: asTextOr(map['key'], ''),
    values: asStringList(map['val']),
  );
}

/// Grupo de especificações (ex.: `Display`, `Platform`, `Battery`).
class DeviceSpecGroup {
  const DeviceSpecGroup({required this.title, required this.rows});

  final String title;
  final List<DeviceSpecRow> rows;

  factory DeviceSpecGroup.fromMap(Map<String, dynamic> map) => DeviceSpecGroup(
    title: asTextOr(map['title'], ''),
    rows: asMapList(
      map['specs'],
    ).map(DeviceSpecRow.fromMap).toList(growable: false),
  );
}

/// Ficha técnica completa de um aparelho.
class DeviceSpecsDetail {
  const DeviceSpecsDetail({
    required this.slug,
    required this.brand,
    required this.name,
    this.thumbnail,
    this.images = const <String>[],
    this.releaseInfo,
    this.dimensionsInfo,
    this.osInfo,
    this.storageInfo,
    this.groups = const <DeviceSpecGroup>[],
  });

  final String slug;
  final String brand;
  final String name;

  /// Imagem principal (thumbnail grande do GSMArena).
  final String? thumbnail;

  /// Galeria oficial de imagens do aparelho.
  final List<String> images;

  /// Fatos rápidos exibidos na visão geral (ex.: `Released 2020, November 13`).
  final String? releaseInfo;
  final String? dimensionsInfo;
  final String? osInfo;
  final String? storageInfo;

  final List<DeviceSpecGroup> groups;

  factory DeviceSpecsDetail.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> data = asMap(map['data'] ?? map);
    return DeviceSpecsDetail(
      slug: asTextOr(map['slug'] ?? data['slug'], ''),
      brand: asTextOr(data['brand'], ''),
      name: asTextOr(data['phone_name'], ''),
      thumbnail: asText(data['thumbnail']),
      images: asStringList(data['phone_images']),
      releaseInfo: asText(data['release_date']),
      dimensionsInfo: asText(data['dimension']),
      osInfo: asText(data['os']),
      storageInfo: asText(data['storage']),
      groups: asMapList(
        data['specifications'],
      ).map(DeviceSpecGroup.fromMap).toList(growable: false),
    );
  }
}

/// Marca disponível na base de fichas técnicas (ex.: `Samsung`, `samsung-phones-9`).
class DeviceSpecsBrand {
  const DeviceSpecsBrand({
    required this.name,
    required this.slug,
    this.deviceCount,
  });

  final String name;
  final String slug;
  final int? deviceCount;

  factory DeviceSpecsBrand.fromMap(Map<String, dynamic> map) =>
      DeviceSpecsBrand(
        name: asTextOr(map['brand_name'], ''),
        slug: asTextOr(map['brand_slug'], ''),
        deviceCount: map['device_count'] == null
            ? null
            : asInt(map['device_count']),
      );
}

/// Resposta de listagem de marca (com paginação do GSMArena).
class DeviceSpecsBrandPage {
  const DeviceSpecsBrandPage({
    required this.currentPage,
    required this.lastPage,
    required this.phones,
  });

  final int currentPage;
  final int lastPage;
  final List<DeviceSpecsSummary> phones;

  factory DeviceSpecsBrandPage.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> data = asMap(map['data'] ?? map);
    return DeviceSpecsBrandPage(
      currentPage: asInt(data['current_page']),
      lastPage: asInt(data['last_page']),
      phones: asMapList(
        data['phones'],
      ).map(DeviceSpecsSummary.fromMap).toList(growable: false),
    );
  }
}
