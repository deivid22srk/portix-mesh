import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../data/catalog_repository.dart';
import '../../models/explore.dart';

// ============================================================================
// Controller do modo descoberta da Explorar.
//
// stale-while-revalidate como na Início: o último payload bom do cache é
// exibido SINCRONAMENTE (a tela abre com conteúdo, sem esperar rede) e a RPC
// `explore_feed` revalida por baixo. Erro nunca deixa a tela vazia: se existe
// cache, ele permanece com o aviso de desatualização; se não existe, o estado
// de erro explica e oferece "Tentar novamente".
// ============================================================================

enum ExploreStatus { idle, loading, ready, error }

class ExploreState {
  const ExploreState({
    this.feed = const ExploreFeed(),
    this.status = ExploreStatus.idle,
    this.error,
    this.stale = false,
  });

  final ExploreFeed feed;
  final ExploreStatus status;
  final Object? error;

  /// Dados vindos do cache por falha de rede (podem estar desatualizados).
  final bool stale;

  bool get isInitialLoading =>
      status == ExploreStatus.loading && feed.isEmpty && !stale;

  ExploreState copyWith({
    ExploreFeed? feed,
    ExploreStatus? status,
    Object? error,
    bool clearError = false,
    bool? stale,
  }) => ExploreState(
    feed: feed ?? this.feed,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    stale: stale ?? this.stale,
  );
}

final exploreControllerProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);

class ExploreController extends Notifier<ExploreState> {
  int _requestId = 0;

  /// O cache síncrono do `build` já foi revalidado na rede nesta sessão?
  bool _revalidated = false;

  ExploreDiscoveryRepository? get _repo {
    final Object repository = ref.read(catalogRepositoryProvider);
    return repository is ExploreDiscoveryRepository ? repository : null;
  }

  @override
  ExploreState build() {
    // Cache síncrono: conteúdo imediato, revalidação por baixo.
    final ExploreFeed? cached = _repo?.readCachedExploreFeed();
    if (cached != null) {
      return ExploreState(feed: cached, status: ExploreStatus.ready);
    }
    return const ExploreState();
  }

  void ensureLoaded() {
    // Sem cache: primeira carga. Com cache: revalidação em background uma vez
    // por sessão (stale-while-revalidate) — a tela já abriu com conteúdo.
    if (state.status == ExploreStatus.idle || !_revalidated) {
      unawaited(load());
    }
  }

  Future<void> load() async {
    final int requestId = ++_requestId;
    final ExploreDiscoveryRepository? repository = _repo;
    if (repository == null) {
      state = state.copyWith(
        status: ExploreStatus.error,
        error: const AppFailure(FailureKind.server),
      );
      return;
    }
    final bool hadContent = state.feed.isNotEmpty;
    _revalidated = true;
    state = state.copyWith(
      status: ExploreStatus.loading,
      clearError: true,
      stale: hadContent ? state.stale : false,
    );
    try {
      final ExploreFeed feed = await repository.fetchExploreFeed();
      if (requestId != _requestId) {
        return;
      }
      state = ExploreState(feed: feed, status: ExploreStatus.ready);
    } on Object catch (error) {
      if (requestId != _requestId) {
        return;
      }
      // Com cache: mantém o conteúdo e sinaliza desatualização. Sem cache:
      // estado de erro com ação.
      if (state.feed.isNotEmpty) {
        state = state.copyWith(
          status: ExploreStatus.ready,
          error: error,
          stale: true,
        );
      } else {
        state = ExploreState(
          feed: const ExploreFeed(),
          status: ExploreStatus.error,
          error: error,
        );
      }
    }
  }
}
