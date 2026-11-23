import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portix/core/env.dart';
import 'package:portix/features/device_specs/data/device_specs_api.dart';
import 'package:portix/features/device_specs/data/device_specs_models.dart';
import 'package:portix/features/device_specs/data/device_specs_repository.dart';

void main() {
  const String detailJson =
      '{"status":true,"data":{"brand":"Xiaomi","phone_name":"Poco X6 Pro",'
      '"thumbnail":"https://fdn2.gsmarena.com/vv/bigpic/xiaomi-poco-x6-pro.jpg",'
      '"phone_images":["https://img/1.jpg","https://img/2.jpg"],'
      '"release_date":"Released 2024, January 10",'
      '"dimension":"186g, 8.3mm thickness",'
      '"os":"Android 14, HyperOS",'
      '"storage":"256GB/512GB storage",'
      '"specifications":[{"title":"Display","specs":[{"key":"Type","val":["AMOLED 120Hz"]},{"key":"Size","val":["6.67 inches"]}]},{"title":"Platform","specs":[{"key":"Chipset","val":["Dimensity 8300 Ultra"]}]}]}}';

  // Instância simulada da API: busca direta quebrada (como hoje), marcas com
  // paginação real e detalhe por slug.
  ({int Function() calls, http.Client client}) buildClient(
    List<_StubPage> Function(String brandSlug) pagesFor,
  ) {
    int calls = 0;
    final http.Client client = MockClient((http.Request request) async {
      calls += 1;
      final String path = request.url.path;
      if (path == '/search') {
        return http.Response(
          '{"status":false,"error":"Something went wrong: Could not find Chrome"}',
          200,
        );
      }
      if (path == '/brands') {
        return http.Response(
          '{"status":true,"data":['
          '{"brand_id":80,"brand_name":"Xiaomi","brand_slug":"xiaomi-phones-80","device_count":700},'
          '{"brand_id":9,"brand_name":"Samsung","brand_slug":"samsung-phones-9","device_count":300}'
          ']}',
          200,
        );
      }
      if (path.startsWith('/brands/')) {
        final String slug = path.split('/').last;
        final int page =
            int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
        final List<_StubPage> pages = pagesFor(slug);
        final _StubPage stub = pages[page - 1];
        return http.Response(
          jsonEncode(<String, dynamic>{
            'status': true,
            'data': <String, dynamic>{
              'title': slug,
              'current_page': page,
              'last_page': stub.lastPage,
              'phones': stub.phones,
            },
          }),
          200,
        );
      }
      if (path == '/test_poco_x6_pro-1') {
        return http.Response(detailJson, 200);
      }
      return http.Response('{"status":false,"error":"Route not found!"}', 404);
    });
    return (calls: () => calls, client: client);
  }

  DeviceSpecsRepository repoWith(http.Client client) =>
      DeviceSpecsRepository(api: DeviceSpecsApi(client: client));

  List<_StubPage> xiaomiAndSamsung(String slug) {
    if (slug == 'xiaomi-phones-80') {
      return <_StubPage>[
        const _StubPage(
          lastPage: 2,
          phones: <Map<String, dynamic>>[
            <String, dynamic>{
              'phone_name': 'Poco X6 Pro',
              'slug': 'test_poco_x6_pro-1',
              'image': 'https://img/poco.jpg',
            },
          ],
        ),
        const _StubPage(
          lastPage: 2,
          phones: <Map<String, dynamic>>[
            <String, dynamic>{
              'phone_name': 'Redmi Note 10',
              'slug': 'test_redmi_note_10-2',
              'image': 'https://img/redmi.jpg',
            },
          ],
        ),
      ];
    }
    return <_StubPage>[
      const _StubPage(
        lastPage: 1,
        phones: <Map<String, dynamic>>[
          <String, dynamic>{
            'phone_name': 'Galaxy S24 5G',
            'slug': 'test_galaxy_s24-3',
            'image': 'https://img/s24.jpg',
          },
        ],
      ),
    ];
  }

  test(
    'busca cai para o fallback por marca e acha o aparelho do relato',
    () async {
      final built = buildClient(xiaomiAndSamsung);
      final DeviceSpecsRepository repo = repoWith(built.client);

      final List<DeviceSpecsSummary> results = await repo.search(
        'Xiaomi Poco X6 Pro',
      );

      expect(results, hasLength(1));
      expect(results.single.name, 'Poco X6 Pro');
      expect(results.single.slug, 'test_poco_x6_pro-1');
      // /search + /brands + 2 páginas da marca.
      expect(built.calls(), 4);
    },
  );

  test(
    'apelido resolve a marca (Redmi → Xiaomi) e paginação é usada',
    () async {
      final built = buildClient(xiaomiAndSamsung);
      final DeviceSpecsRepository repo = repoWith(built.client);

      final List<DeviceSpecsSummary> results = await repo.search(
        'Redmi Note 10',
      );
      expect(results, hasLength(1));
      expect(results.single.slug, 'test_redmi_note_10-2');
    },
  );

  test('Galaxy resolve Samsung e ranking descarta parecidos fracos', () async {
    final built = buildClient(xiaomiAndSamsung);
    final DeviceSpecsRepository repo = repoWith(built.client);

    final List<DeviceSpecsSummary> results = await repo.search('Galaxy S24');
    expect(results.single.slug, 'test_galaxy_s24-3');
  });

  test('busca repetida pela mesma marca não refaz requisições', () async {
    final built = buildClient(xiaomiAndSamsung);
    final DeviceSpecsRepository repo = repoWith(built.client);

    await repo.search('Xiaomi Poco X6 Pro');
    final int afterFirst = built.calls();
    await repo.search('Redmi Note 10');
    expect(built.calls(), afterFirst);
  });

  test(
    'ficha técnica é cacheada: segunda abertura não gera requisição',
    () async {
      final built = buildClient(xiaomiAndSamsung);
      final DeviceSpecsRepository repo = repoWith(built.client);

      final DeviceSpecsDetail first = await repo.device('test_poco_x6_pro-1');
      expect(first.name, 'Poco X6 Pro');
      expect(first.images, hasLength(2));
      expect(first.groups, hasLength(2));
      expect(first.groups.last.rows.first.key, 'Chipset');

      final int afterFirst = built.calls();
      final DeviceSpecsDetail second = await repo.device('test_poco_x6_pro-1');
      expect(identical(first, second), isTrue);
      expect(built.calls(), afterFirst);
    },
  );

  test(
    'busca sem marca conhecida e sem endpoint direto retorna vazio',
    () async {
      final built = buildClient(xiaomiAndSamsung);
      final DeviceSpecsRepository repo = repoWith(built.client);

      final List<DeviceSpecsSummary> results = await repo.search('SM-S928B');
      expect(results, isEmpty);
    },
  );

  test('erro de rede vira AppFailure.network', () async {
    final http.Client client = MockClient((http.Request request) async {
      throw const SocketException('sem conexão');
    });
    final DeviceSpecsRepository repo = repoWith(client);

    await expectLater(repo.device('qualquer'), throwsA(isA<AppFailure>()));
    await expectLater(repo.brands(), throwsA(isA<AppFailure>()));
  });
}

class _StubPage {
  const _StubPage({required this.lastPage, required this.phones});

  final int lastPage;
  final List<Map<String, dynamic>> phones;
}
