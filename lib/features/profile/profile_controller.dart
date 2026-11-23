import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../core/env.dart';
import '../../core/cache_store.dart';
import '../../core/providers.dart';
import '../../models/profile.dart';
import '../../models/public_profile.dart';
import '../../models/user_result.dart';

/// Chave do último perfil bom no CacheStore (stale-while-revalidate).
const String kProfileCacheKey = 'profile';

/// Limpa o cache de imagens **decodificadas** do framework (ImageCache em
/// memória). A invalidação por URL não é confiável quando o provider é
/// embrulhado por ResizeImage (memCacheWidth do CachedNetworkImage), então a
/// limpeza é global: as imagens voltam do DISCO instantaneamente, sem rede —
/// a métrica "2ª abertura = 0 downloads" fica intacta.
void clearInMemoryImageCache() {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

/// Perfil do usuário com **stale-while-revalidate**:
///
/// - abre instantâneo com o último valor bom (CacheStore em disco) — sem
///   estado de loading entre navegações, sem flash da imagem de perfil;
/// - revalida em segundo plano contra o Supabase;
/// - é keepAlive: sai e volta das configurações não refaz o fetch;
/// - logout limpa o cache persistido e o arquivo de imagem em disco.
final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<UserProfile> {
  /// Última capa vista — usada para limpar o arquivo em disco no logout.
  String? _lastCoverUrl;

  @override
  FutureOr<UserProfile> build() {
    // Sobrevive à navegação: reabrir configurações não é um refetch novo.
    ref.keepAlive();
    final AccountState account = ref.watch(accountProvider);
    if (!account.isSignedIn) {
      // Convidado (inclui o instante pós-logout): nada de conta pode restar
      // no dispositivo — cache do perfil e imagem da capa saem do disco.
      Future<void>.microtask(_clearCaches);
      return UserProfile(
        id: account.id ?? '',
        displayName: account.displayName,
      );
    }

    final CacheStore store = ref.read(cacheStoreProvider);
    final Map<String, dynamic>? cached = store.readMap(kProfileCacheKey);
    final UserProfile? cachedProfile = cached == null
        ? null
        : UserProfile.fromMap(cached);

    // Logout ativo: a sessão morre com o provider vivo → limpa tudo.
    ref.listen(accountProvider, (AccountState? prev, AccountState next) {
      if (prev?.isSignedIn == true && !next.isSignedIn) {
        Future<void>.microtask(_clearCaches);
      }
    });

    if (cachedProfile != null) {
      // Stale-while-revalidate sincrono: valor do cache é o estado INICIAL
      // (AsyncData no 1º frame — zero flicker), rede revalida em segundo plano.
      Future<void>.microtask(_revalidate);
      _lastCoverUrl = cachedProfile.coverUrl;
      return cachedProfile;
    }
    return _fetch();
  }

  /// Busca o perfil e grava o último valor bom no cache.
  Future<UserProfile> _fetch() async {
    final UserProfile profile = await ref
        .read(catalogRepositoryProvider)
        .fetchProfile();
    _lastCoverUrl = profile.coverUrl;
    await ref
        .read(cacheStoreProvider)
        .writeMap(kProfileCacheKey, profile.toMap());
    return profile;
  }

  /// Revalidação silenciosa: atualiza o estado ou mantém o cache (offline).
  Future<void> _revalidate() async {
    try {
      state = AsyncData<UserProfile>(await _fetch());
    } on AppFailure {
      // Sem rede (ou backend fora): o valor em cache continua na tela.
    }
  }

  /// Chamado após salvar no editor de perfil: refetch imediato.
  Future<void> refresh() => _revalidate();

  /// Limpa o cache do perfil e a imagem de capa em disco E memória
  /// (logout / troca): reupload na mesma URL não pode exibir avatar velho.
  Future<void> _clearCaches() async {
    final String? cover = _lastCoverUrl;
    await ref.read(cacheStoreProvider).remove(kProfileCacheKey);
    if (cover != null && cover.isNotEmpty) {
      try {
        await DefaultCacheManager().removeFile(cover);
      } on Object {
        // Cache de imagem é volátil: falha ao limpar não bloqueia o logout.
      }
    }
    _lastCoverUrl = null;
    clearInMemoryImageCache();
  }
}

/// Nível de ADM: definido em `core/auth.dart` (sem painel ADM no backend
/// local, `adminLevelProvider` sempre devolve null). Mantido no arquivo apenas
/// como referência histórica da migração Supabase → malha.

/// Busca de usuários (por @handle ou nome).
final userSearchProvider = FutureProvider.family<List<UserResult>, String>(
  (ref, String query) =>
      ref.watch(catalogRepositoryProvider).searchUsers(query),
);

/// Perfil público de um usuário (com a biblioteca).
final publicProfileProvider = FutureProvider.family<PublicProfile, String>(
  (ref, String id) =>
      ref.watch(catalogRepositoryProvider).fetchPublicProfile(id),
);
