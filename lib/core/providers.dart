import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog_repository.dart';
import '../data/local_catalog_repository.dart';
import 'cache_store.dart';
import 'mesh/mesh_config.dart';
import 'mesh/mesh_identity.dart';
import 'mesh/mesh_node.dart';
import 'mesh/mesh_store.dart';

// ============================================================================
// Providers globais do PORTIX sem backend central:
//   - catálogo: asset embutido (LocalCatalogRepository);
//   - dados do usuário: store local + malha P2P (MeshStore/MeshNode).
// ============================================================================

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider precisa ser sobrescrito no bootstrap do app.',
  );
});

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => CacheStore(ref.watch(sharedPreferencesProvider)),
);

// ---------------------------------------------------------------------- malha

final meshConfigProvider = Provider<MeshConfig>(
  (ref) => MeshConfig(ref.watch(sharedPreferencesProvider)),
);

final meshIdentityStoreProvider = Provider<MeshIdentityStore>(
  (ref) => MeshIdentityStore(ref.watch(sharedPreferencesProvider)),
);

final meshIdentityProvider = Provider<MeshIdentity>(
  (ref) => ref.watch(meshIdentityStoreProvider).loadOrCreate(),
);

final meshStoreProvider = Provider<MeshStore>((ref) {
  final MeshStore store = MeshStore(
    ref.watch(sharedPreferencesProvider),
    ref.watch(meshIdentityProvider).deviceId,
  );
  ref.onDispose(store.dispose);
  return store;
});

/// Emite a cada mudança no store (local ou recebida da malha).
final meshRevisionProvider = StreamProvider<int>(
  (ref) => ref.watch(meshStoreProvider).changes,
);

final meshNodeProvider = Provider<MeshNode>((ref) {
  final MeshStore store = ref.watch(meshStoreProvider);
  final MeshNode node = MeshNode(
    identity: ref.watch(meshIdentityProvider),
    config: ref.watch(meshConfigProvider),
    onOp: store.applyOp,
    // Ao descobrir um par novo, publica o estado completo (convergência).
    onSyncRequest: () => ref.read(meshNodeProvider).publish(store.fullState()),
  );
  ref.onDispose(node.dispose);
  return node;
});

/// Presença da malha (quantos dispositivos, quais relays, LAN).
final meshPresenceProvider = StreamProvider<MeshPresence>(
  (ref) => ref.watch(meshNodeProvider).presence,
);

/// Liga a malha e aquece o catálogo. NUNCA falha: o app é local por natureza;
/// a malha é um extra que pode estar indisponível sem quebrar nada.
final meshBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ref.read(localCatalogRepositoryProvider).warmUp();
  } on Object {
    // Catálogo ausente vira estado vazio, não erro de boot.
  }
  try {
    await ref.read(meshNodeProvider).start();
  } on Object {
    // Sem rede/relay: catálogo e dados locais seguem funcionando.
  }
});

// ------------------------------------------------------------------ catálogo

final localCatalogRepositoryProvider = Provider<LocalCatalogRepository>(
  (ref) => LocalCatalogRepository(
    cache: ref.watch(cacheStoreProvider),
    store: ref.watch(meshStoreProvider),
    mesh: ref.watch(meshNodeProvider),
  ),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => ref.watch(localCatalogRepositoryProvider),
);
