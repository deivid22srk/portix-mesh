import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/auth.dart';
import 'package:portix/core/providers.dart';
import 'package:portix/data/catalog_repository.dart';
import 'package:portix/features/profile/profile_controller.dart';
import 'package:portix/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Stale-while-revalidate do perfil: abre instantâneo com o último valor bom,
// reabrir configurações NÃO refaz o fetch (keepAlive), trocar foto revalida
// e logout limpa o cache.
// ============================================================================

class _FakeRepository implements CatalogRepository {
  _FakeRepository(this.profile);

  UserProfile profile;
  int fetchCalls = 0;

  @override
  Future<UserProfile> fetchProfile() async {
    fetchCalls++;
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} não usado no teste');
}

/// Controller de conta controlado pelos testes (sem tocar no backend).
class _FixedAccountController extends AccountController {
  _FixedAccountController();

  @override
  AccountState build() {
    ref.onDispose(() => _closed = true);
    return _state;
  }

  AccountState _state = const AccountState();
  bool _closed = false;

  void set(AccountState value) {
    _state = value;
    if (!_closed) {
      state = value;
    }
  }
}

Future<ProviderContainer> _container({
  required _FakeRepository repo,
  required AccountState account,
  Map<String, Object> stored = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogRepositoryProvider.overrideWithValue(repo),
      accountProvider.overrideWith(_FixedAccountController.new),
    ],
  );
  (container.read(accountProvider.notifier) as _FixedAccountController).set(
    account,
  );
  return container;
}

Future<ProviderContainer> _signedInContainer({
  required _FakeRepository repo,
  Map<String, Object> stored = const <String, Object>{},
}) {
  return _container(
    repo: repo,
    account: const AccountState(
      id: 'u-1',
      displayName: 'Ana',
      signedIn: true,
    ),
    stored: stored,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // O logout limpa o arquivo da imagem em disco (DefaultCacheManager) —
    // no host de teste mocka o channel do path_provider.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async {
            final Directory dir = await Directory.systemTemp.createTemp(
              'portix_swr_test',
            );
            return dir.path;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test('convidado não consulta rede nem cria cache', () async {
    final _FakeRepository repo = _FakeRepository(
      const UserProfile(
        id: 'u1',
        displayName: 'Ana',
        coverUrl: 'http://x/a.png',
      ),
    );
    final ProviderContainer container = await _container(
      repo: repo,
      account: const AccountState(),
    );
    addTearDown(container.dispose);

    final UserProfile profile = container.read(profileProvider).value!;
    expect(profile.displayName, isEmpty, reason: 'UI resolve o nome com l10n');
    expect(repo.fetchCalls, 0);
    expect(
      container.read(cacheStoreProvider).readMap(kProfileCacheKey),
      isNull,
    );
  });

  test('primeira sessão: fetch real, cache gravado, estado sem erro', () async {
    final _FakeRepository repo = _FakeRepository(
      const UserProfile(
        id: 'u-1',
        displayName: 'Ana',
        coverUrl: 'http://127.0.0.1:9/a.png',
        handle: 'ana',
      ),
    );
    final ProviderContainer container = await _signedInContainer(repo: repo);
    addTearDown(container.dispose);

    // Aguarda o fetch inicial.
    final AsyncValue<UserProfile> state = await container
        .read(profileProvider.future)
        .then(AsyncValue.data);
    expect(state.value!.displayName, 'Ana');
    expect(repo.fetchCalls, 1);
    expect(
      container
          .read(cacheStoreProvider)
          .readMap(kProfileCacheKey)!['display_name'],
      'Ana',
    );
  });

  test('reabrir configurações (mesma sessão) NÃO refaz o fetch', () async {
    final _FakeRepository repo = _FakeRepository(
      const UserProfile(
        id: 'u-1',
        displayName: 'Ana',
        coverUrl: 'http://127.0.0.1:9/a.png',
      ),
    );
    final ProviderContainer container = await _signedInContainer(repo: repo);
    addTearDown(container.dispose);

    await container.read(profileProvider.future);
    final int afterFirst = repo.fetchCalls;

    // "Reabre": o widget desmonta/monta e watch de novo — keepAlive mantém.
    container.read(profileProvider);
    container.read(profileProvider);
    expect(
      repo.fetchCalls,
      afterFirst,
      reason: 'keepAlive: reabrir não é refetch',
    );
  });

  test(
    'SWR: com cache em disco o perfil abre instantâneo e revalida em bg',
    () async {
      final _FakeRepository repo = _FakeRepository(
        const UserProfile(
          id: 'u-1',
          displayName: 'Ana',
          coverUrl: 'http://127.0.0.1:9/a.png',
        ),
      );
      // Cache pré-semeado (abertura anterior gravou o perfil).
      final Map<String, Object> stored = <String, Object>{
        'cache.profile':
            '{"id":"u-1","display_name":"Ana","cover_url":"http://127.0.0.1:9/a.png","handle":null}',
      };
      final ProviderContainer container = await _signedInContainer(
        repo: repo,
        stored: stored,
      );
      addTearDown(container.dispose);

      // 1º frame: valor do cache disponível AGORA (sem loading).
      final AsyncValue<UserProfile> immediate = container.read(profileProvider);
      expect(
        immediate.hasValue,
        true,
        reason: 'cache abre instantâneo (sem flash)',
      );
      expect(immediate.value!.displayName, 'Ana');

      // Revalidação em background termina com 1 fetch.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await container.read(profileProvider.future);
      expect(repo.fetchCalls, 1);
    },
  );

  test('logout limpa o cache persistido do perfil', () async {
    final _FakeRepository repo = _FakeRepository(
      const UserProfile(
        id: 'u-1',
        displayName: 'Ana',
        coverUrl: 'http://127.0.0.1:9/a.png',
      ),
    );
    final ProviderContainer container = await _signedInContainer(repo: repo);
    addTearDown(container.dispose);

    await container.read(profileProvider.future);
    expect(
      container.read(cacheStoreProvider).readMap(kProfileCacheKey),
      isNotNull,
    );

    // Logout: account muda para convidado → o menu re-renderiza (lê o
    // provider) e o listener/microtask limpa o cache.
    (container.read(accountProvider.notifier) as _FixedAccountController).set(
      const AccountState(),
    );
    container.read(profileProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(cacheStoreProvider).readMap(kProfileCacheKey),
      isNull,
      reason: 'cache.profile sai do disco no logout',
    );
  });
}
