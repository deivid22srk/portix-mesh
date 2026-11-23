import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/app/app_strings.dart';
import 'package:portix/features/device_specs/data/device_specs_models.dart';
import 'package:portix/features/device_specs/device_specs_labels.dart';

void main() {
  test('ficha técnica completa faz parse do JSON da API', () {
    final DeviceSpecsDetail detail = DeviceSpecsDetail.fromMap(
      <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'brand': 'Apple',
          'phone_name': 'iPhone 12 Pro Max',
          'thumbnail': 'https://fdn2.gsmarena.com/vv/bigpic/apple-iphone.jpg',
          'phone_images': <String>['https://img/1.jpg', 'https://img/2.jpg'],
          'release_date': 'Released 2020, November 13',
          'dimension': '228g, 7.4mm thickness',
          'os': 'iOS 14.1',
          'storage': '128GB/256GB storage',
          'specifications': <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Display',
              'specs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'key': 'Type',
                  'val': <String>['Super Retina XDR OLED'],
                },
                <String, dynamic>{
                  'key': 'Size',
                  'val': <String>['6.7 inches'],
                },
              ],
            },
            <String, dynamic>{
              'title': 'Battery',
              'specs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'key': 'Type',
                  'val': <String>['Li-Ion 3687 mAh'],
                },
              ],
            },
          ],
        },
      },
    );

    expect(detail.name, 'iPhone 12 Pro Max');
    expect(detail.brand, 'Apple');
    expect(detail.thumbnail, isNotNull);
    expect(detail.images, hasLength(2));
    expect(detail.releaseInfo, 'Released 2020, November 13');
    expect(detail.dimensionsInfo, '228g, 7.4mm thickness');
    expect(detail.osInfo, 'iOS 14.1');
    expect(detail.storageInfo, '128GB/256GB storage');
    expect(detail.groups, hasLength(2));
    expect(detail.groups.first.title, 'Display');
    expect(detail.groups.first.rows.first.key, 'Type');
    expect(detail.groups.first.rows.first.values, <String>[
      'Super Retina XDR OLED',
    ]);
  });

  test(
    'summary aceita variações de chave (phone_name/name, image/thumbnail)',
    () {
      final DeviceSpecsSummary a = DeviceSpecsSummary.fromMap(<String, dynamic>{
        'phone_name': 'Poco X6 Pro',
        'slug': 'xiaomi_poco_x6_pro-12814',
        'image': 'https://img/poco.jpg',
      });
      expect(a.name, 'Poco X6 Pro');
      expect(a.slug, 'xiaomi_poco_x6_pro-12814');
      expect(a.imageUrl, 'https://img/poco.jpg');

      final DeviceSpecsSummary b = DeviceSpecsSummary.fromMap(<String, dynamic>{
        'name': 'Galaxy S24',
        'slug': 'samsung_galaxy_s24-14701',
        'thumbnail': 'https://img/s24.jpg',
        'brand': 'Samsung ',
      });
      expect(b.name, 'Galaxy S24');
      expect(b.imageUrl, 'https://img/s24.jpg');
      expect(b.brand, 'Samsung');
    },
  );

  test('parse tolerante não lança com dados ausentes ou de tipos errados', () {
    final DeviceSpecsDetail empty = DeviceSpecsDetail.fromMap(<String, dynamic>{
      'status': true,
      'data': <String, dynamic>{},
    });
    expect(empty.name, '');
    expect(empty.images, isEmpty);
    expect(empty.groups, isEmpty);
    expect(empty.releaseInfo, isNull);

    final DeviceSpecGroup broken = DeviceSpecGroup.fromMap(<String, dynamic>{
      'title': 'Memory',
      'specs': 'não é lista',
    });
    expect(broken.title, 'Memory');
    expect(broken.rows, isEmpty);
  });

  test('vocabulário das fichas é traduzido em pt e mantido em inglês', () {
    const L10n pt = L10n(Locale('pt', 'BR'));
    const L10n en = L10n(Locale('en'));

    expect(specSectionLabel(pt, 'Display'), 'Tela');
    expect(specSectionLabel(pt, 'Battery'), 'Bateria');
    expect(specSectionLabel(pt, 'Main Camera'), 'Câmera principal');
    expect(specSectionLabel(en, 'Display'), 'Display');

    expect(specRowLabel(pt, 'Resolution'), 'Resolução');
    expect(specRowLabel(pt, 'Chipset'), 'Chipset');
    expect(specRowLabel(pt, 'Charging'), 'Carregamento');
    expect(specRowLabel(en, 'Resolution'), 'Resolution');
    // Termo fora do dicionário cai no original (nunca quebra).
    expect(specRowLabel(pt, 'Termino ultrarraro'), 'Termino ultrarraro');
  });
}
