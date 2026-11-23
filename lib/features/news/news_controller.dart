import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/news.dart';

enum NewsStatus { idle, loading, loadingMore, ready, empty, error }

class NewsState {
  const NewsState({
    this.items = const <NewsItem>[],
    this.total = 0,
    this.status = NewsStatus.idle,
    this.error,
  });

  final List<NewsItem> items;
  final int total;
  final NewsStatus status;
  final Object? error;

  bool get isInitialLoading => status == NewsStatus.loading && items.isEmpty;
  bool get isLoadingMore => status == NewsStatus.loadingMore;
  bool get hasMore => items.length < total;
}

final newsControllerProvider = NotifierProvider<NewsController, NewsState>(
  NewsController.new,
);

class NewsController extends Notifier<NewsState> {
  static const int _pageSize = 20;
  int _requestId = 0;

  @override
  NewsState build() => const NewsState();

  void ensureLoaded() {
    if (state.status == NewsStatus.idle) {
      unawaited(_fetch(reset: true));
    }
  }

  Future<void> refresh() => _fetch(reset: true);

  Future<void> loadMore() async {
    if (state.status != NewsStatus.ready || !state.hasMore) {
      return;
    }
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final int requestId = ++_requestId;
    final int offset = reset ? 0 : state.items.length;
    state = NewsState(
      items: reset ? const <NewsItem>[] : state.items,
      total: reset ? 0 : state.total,
      status: reset ? NewsStatus.loading : NewsStatus.loadingMore,
    );
    try {
      final NewsPayload payload = await ref
          .read(catalogRepositoryProvider)
          .fetchNews(offset: offset, limit: _pageSize);
      if (requestId != _requestId) {
        return;
      }
      final List<NewsItem> items = reset
          ? payload.items
          : _merge(state.items, payload.items);
      state = NewsState(
        items: items,
        total: payload.total,
        status: items.isEmpty ? NewsStatus.empty : NewsStatus.ready,
      );
    } on Object catch (error) {
      if (requestId != _requestId) {
        return;
      }
      state = NewsState(
        items: reset ? const <NewsItem>[] : state.items,
        total: reset ? 0 : state.total,
        status: reset ? NewsStatus.error : NewsStatus.ready,
        error: error,
      );
    }
  }

  List<NewsItem> _merge(List<NewsItem> current, List<NewsItem> incoming) {
    String keyOf(NewsItem item) => item.id.isNotEmpty ? item.id : item.slug;
    final Set<String> seen = current.map(keyOf).toSet();
    final List<NewsItem> next = <NewsItem>[...current];
    for (final NewsItem item in incoming) {
      if (seen.add(keyOf(item))) {
        next.add(item);
      }
    }
    return next;
  }
}
