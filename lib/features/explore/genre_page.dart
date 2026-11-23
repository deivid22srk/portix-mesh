import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import '../../models/search.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/states.dart';
import '../home/feed_sections.dart';
import '../search/search_controller.dart' show SearchStatus;

// ============================================================================
// Tela de categoria (gênero): abre ao tocar um card de "Categorias" na
// Explorar e lista os jogos daquele gênero, com paginação por cursor.
//
// O estado é PRÓPRIO da página (nada de provider global de busca): compartilhar
// estado entre telas foi a causa do bug em que a Explorar derrubava a tela de
// busca. Cada visita à categoria carrega a lista dela; voltar e reabrir
// recarrega com os dados frescos do catálogo.
// ============================================================================

class GenrePage extends ConsumerStatefulWidget {
  const GenrePage({super.key, required this.genre});

  final String genre;

  @override
  ConsumerState<GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends ConsumerState<GenrePage> {
  final ScrollController _scroll = ScrollController();

  SearchStatus _status = SearchStatus.idle;
  Object? _error;
  List<Game> _items = const <Game>[];
  int _total = 0;
  Map<String, dynamic>? _cursor;
  bool _loadingMore = false;
  int _requestId = 0;

  bool get _isInitialLoading =>
      _status == SearchStatus.loading && _items.isEmpty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && _status == SearchStatus.idle) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() {
      _status = SearchStatus.loading;
      _error = null;
    });
    try {
      final SearchPayload payload = await ref
          .read(catalogRepositoryProvider)
          .search(
            SearchRequest(
              query: '',
              filters: SearchFilters(genre: widget.genre, sort: kDefaultSort),
            ),
          );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _items = payload.items;
        _total = payload.total;
        _cursor = payload.cursor;
        _status = payload.items.isEmpty
            ? SearchStatus.empty
            : SearchStatus.ready;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _status = SearchStatus.error;
        _error = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_status != SearchStatus.ready || _cursor == null || _loadingMore) {
      return;
    }
    final int requestId = ++_requestId;
    setState(() => _loadingMore = true);
    try {
      final SearchPayload payload = await ref
          .read(catalogRepositoryProvider)
          .search(
            SearchRequest(
              query: '',
              filters: SearchFilters(genre: widget.genre, sort: kDefaultSort),
              cursor: _cursor,
            ),
          );
      if (!mounted || requestId != _requestId) {
        return;
      }
      final Set<String> seen = _items.map((Game g) => g.id).toSet();
      setState(() {
        _items = <Game>[
          ..._items,
          for (final Game game in payload.items)
            if (seen.add(game.id)) game,
        ];
        _cursor = payload.cursor;
        _loadingMore = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      // Mantém os itens já visíveis; o rodapé oferece "Tentar de novo".
      setState(() {
        _loadingMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.colors.accent,
            backgroundColor: context.colors.glassStrong,
            onRefresh: _load,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: AppHeaderSearchBar(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/explore');
                      }
                    },
                    field: Semantics(
                      header: true,
                      child: Text(
                        widget.genre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isInitialLoading)
                  const SliverToBoxAdapter(child: SearchSkeleton())
                else if (_status == SearchStatus.error && _items.isEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      // +xxxl: o conteúdo do EmptyState precisa do mesmo
                      // folga extra usada na Explorar — só o viewport
                      // estoura 8px na largura de telefone.
                      height: AppSpacing.emptyStateViewport + AppSpacing.xxxl,
                      child: FeedErrorState(error: _error, onRetry: _load),
                    ),
                  )
                else if (_items.isEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppSpacing.emptyStateViewport + AppSpacing.xxxl,
                      child: EmptyState(
                        icon: Icons.category_rounded,
                        title: l10n.genreEmptyTitle,
                        body: l10n.genreEmptyBody,
                      ),
                    ),
                  )
                else ...<Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.md,
                        AppSpacing.screen,
                        AppSpacing.md,
                      ),
                      child: Text(
                        l10n.resultsCount(_total),
                        style: context.texts.labelMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  ResponsiveCoverGrid(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      0,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final Game game = _items[index];
                      return RevealOnMount(
                        index: index,
                        child: GameCard(
                          game: game,
                          heroTag: 'genre-${widget.genre}-${game.id}',
                        ),
                      );
                    },
                    itemCount: _items.length,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.xl,
                        AppSpacing.screen,
                        context.bottomChromePadding,
                      ),
                      child: Center(
                        child: _loadingMore
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.accent,
                                ),
                              )
                            : (_error != null
                                  ? SecondaryButton(
                                      label: l10n.tryAgain,
                                      icon: Icons.refresh_rounded,
                                      expand: false,
                                      onPressed: _loadMore,
                                    )
                                  : (_cursor != null
                                        ? SecondaryButton(
                                            label: l10n.seeAll,
                                            icon: Icons.expand_more_rounded,
                                            expand: false,
                                            onPressed: _loadMore,
                                          )
                                        : const SizedBox.shrink())),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
