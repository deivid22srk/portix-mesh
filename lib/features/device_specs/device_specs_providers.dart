import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/device_specs_api.dart';
import 'data/device_specs_models.dart';
import 'data/device_specs_repository.dart';

/// Repositório de fichas técnicas (substituível nos testes).
final deviceSpecsRepositoryProvider = Provider<DeviceSpecsRepository>((ref) {
  return DeviceSpecsRepository(api: DeviceSpecsApi());
});

/// Resultados de busca por texto livre.
final deviceSpecsSearchProvider =
    FutureProvider.family<List<DeviceSpecsSummary>, String>((
      ref,
      String query,
    ) {
      return ref.watch(deviceSpecsRepositoryProvider).search(query);
    });

/// Ficha técnica completa por slug.
final deviceSpecsDetailProvider =
    FutureProvider.family<DeviceSpecsDetail, String>((ref, String slug) {
      return ref.watch(deviceSpecsRepositoryProvider).device(slug);
    });
