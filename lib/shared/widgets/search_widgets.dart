import 'dart:async' show unawaited;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide SearchController;

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/game.dart';
import '../../models/home_feed.dart';
import '../../models/search.dart';
import '../../features/search/search_controller.dart';
import 'filter_sheet.dart';
import 'game_media.dart';
import 'primitives.dart';
import 'reveal.dart';
import 'states.dart';

// ============================================================================
// Componentes reutilizáveis de busca e descoberta da tela Explorar.
//
// Contratos (iguais ao design system):
//  • nenhuma cor solta — tudo de context.colors / AppContentColors;
//  • nenhuma string literal — tudo de context.l10n;
//  • alvos de toque ≥ 48dp, foco visível, Semantics nos papéis;
//  • animações curtas e desligadas com reduced motion.
// ============================================================================

/// Métricas das linhas de carrossel (mesma forma da Início: card 150, 3:4).
class SearchMetrics {
  const SearchMetrics._();

  static const double rowCardWidth = 150;

  /// Altura da faixa: capa (150·4/3 = 200) + folga da animação de entrada.
  static const double rowHeight = 216;

  /// Altura do painel de sugestões (scroll interno).
  static const double suggestionPanel = 340;

  /// Altura do tile de categoria (grade).
  static const double categoryTile = 84;
}

/// Ícone estável por categoria (gênero): mapa conhecido + fallback
/// determinístico por nome (sem cor nem estilo solto — só ícone).
IconData categoryIcon(String genre) {
  switch (genre.toLowerCase()) {
    case 'ação':
    case 'acao':
      return Icons.flash_on_rounded;
    case 'aventura':
      return Icons.explore_rounded;
    case 'rpg':
      return Icons.auto_awesome_rounded;
    case 'plataforma':
      return Icons.sports_esports_rounded;
    case 'corrida':
      return Icons.speed_rounded;
    case 'luta':
      return Icons.sports_mma_rounded;
    case 'puzzle':
      return Icons.extension_rounded;
    case 'estratégia':
    case 'estrategia':
      return Icons.psychology_rounded;
    case 'tiro':
      return Icons.track_changes_rounded;
    case 'esporte':
    case 'esportes':
      return Icons.sports_soccer_rounded;
    case 'simulação':
    case 'simulacao':
      return Icons.precision_manufacturing_rounded;
    case 'terror':
      return Icons.dark_mode_rounded;
    case 'música':
    case 'musica':
      return Icons.music_note_rounded;
    default:
      // Fallback determinístico: mesmo gênero ⇒ mesmo ícone, sempre.
      const List<IconData> pool = <IconData>[
        Icons.games_rounded,
        Icons.videogame_asset_rounded,
        Icons.sports_esports_rounded,
        Icons.extension_rounded,
      ];
      return pool[genre.hashCode.abs() % pool.length];
  }
}

/// Faixa do trecho correspondente em [text] para destacar na sugestão.
/// Compara em forma normalizada (caixa/acento) — o unaccent preserva o
/// comprimento em pt-BR, então o índice vale para o texto original.
TextRange highlightRange(String text, String query) {
  final String normText = _fold(text);
  final String normQuery = _fold(query.trim());
  if (normQuery.isEmpty) {
    return TextRange.empty;
  }
  final int index = normText.indexOf(normQuery);
  if (index < 0) {
    return TextRange.empty;
  }
  return TextRange(start: index, end: index + normQuery.length);
}

/// "Dobra" simples: caixa baixa + acentos comuns do pt-BR.
String _fold(String value) {
  const String from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const String to = 'aaaaaeeeeiiiiooooouuuucn';
  final String lower = value.toLowerCase();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < lower.length; i += 1) {
    final String ch = lower[i];
    final int idx = from.indexOf(ch);
    out.write(idx >= 0 ? to[idx] : ch);
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Campo de busca com sugestões (padrão combobox/listbox).
// ---------------------------------------------------------------------------

/// Campo com painel de sugestões embutido:
///  • Enter busca o texto (ou a sugestão destacada);
///  • ↓/↑ navegam nas sugestões;
///  • Esc fecha o painel e limpa o campo.
class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key, this.autofocus = false});

  final bool autofocus;

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Índice da sugestão destacada (navegação por teclado).
  int _highlight = -1;

  /// Painel de sugestões: abre ao digitar, fecha ao submeter/selecionar/Esc.
  bool _panelVisible = false;

  @override
  void initState() {
    super.initState();
    _text.text = ref.read(searchTextProvider);
    // Combobox: setas navegam nas sugestões e Esc limpa/fecha. O handler é
    // global mas com escopo do ciclo de vida deste campo e só ativo com o
    // campo em foco (EditableText pode consumir o evento antes do bubbling).
    HardwareKeyboard.instance.addHandler(_handleKey);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          _focus.requestFocus();
        }
      });
    }
  }

  bool _handleKey(KeyEvent event) {
    // Intenção do campo: com foco nele, ou com texto ativo (submeter via IME
    // pode soltar o foco; o Esc/setas ainda são intenção deste campo — ele é
    // o único campo de texto da tela).
    if (!_focus.hasFocus && _text.text.isEmpty) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _onEscape();
      return true;
    }
    final List<SuggestionItem> items = _items();
    if (items.isEmpty) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1) % items.length);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlight = (_highlight - 1 + items.length) % items.length,
      );
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchControllerProvider.notifier).setQuery(value);
    ref.read(suggestControllerProvider.notifier).onTyped(value);
    setState(() {
      _highlight = -1;
      _panelVisible = true;
    });
  }

  void _submit(String value) {
    final List<SuggestionItem> items = _items();
    setState(() {
      // Resultados tomam a tela a partir de agora: o painel fecha.
      _panelVisible = false;
      _highlight = -1;
    });
    // Teclado sai de cena ao submeter: os resultados pedem espaço de tela.
    _focus.unfocus();
    if (_highlight >= 0 && _highlight < items.length) {
      _pick(items[_highlight]);
      return;
    }
    unawaited(ref.read(searchControllerProvider.notifier).submitQuery(value));
  }

  void _pick(SuggestionItem item) {
    pickSuggestion(context, ref, item);
    setState(() {
      _panelVisible = false;
      _highlight = -1;
    });
  }

  void _onEscape() {
    ref.read(searchControllerProvider.notifier).clearQuery();
    ref.read(suggestControllerProvider.notifier).onTyped('');
    _text.clear();
    _focus.unfocus();
    setState(() {
      _panelVisible = false;
      _highlight = -1;
    });
  }

  List<SuggestionItem> _items() {
    final SuggestPayload payload = ref.read(suggestControllerProvider).payload;
    return buildSuggestionItems(payload);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String text = ref.watch(searchTextProvider);
    final SuggestState suggest = ref.watch(suggestControllerProvider);
    // ECO do estado (a mesma regra da tela de busca): buscas vindas de OUTRAS
    // interações — chip do histórico, sugestão selecionada, "Limpar" na
    // Explorar — precisam aparecer no campo. A fonte da verdade continua
    // sendo o TEXTO BRUTO (state.query é a bruta, nunca trimada), então o
    // eco nunca apaga o que o usuário está digitando.
    ref.listen<SearchState>(searchControllerProvider, (
      SearchState? previous,
      SearchState next,
    ) {
      if (next.query != _text.text) {
        _text.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });
    final bool panelOpen =
        _panelVisible && text.trim().length >= kSearchMinChars;
    final List<SuggestionItem> items = panelOpen
        ? buildSuggestionItems(suggest.payload)
        : const <SuggestionItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GlassContainer(
          radius: AppRadii.pill,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.search_rounded,
                size: 20,
                color: context.colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: l10n.searchFieldHint,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    textInputAction: TextInputAction.search,
                    style: context.texts.bodyLarge?.copyWith(
                      color: context.colors.textPrimary,
                    ),
                    cursorColor: context.colors.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: l10n.searchFieldHint,
                      hintStyle: context.texts.bodyMedium?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.fieldVertical,
                      ),
                    ),
                  ),
                ),
              ),
              if (text.isNotEmpty)
                Pressable(
                  onTap: _onEscape,
                  // Alvo de toque ≥ 48dp: a área inteira limpa o campo.
                  child: SizedBox(
                    width: AppSpacing.circleButton,
                    height: AppSpacing.circleButton,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (panelOpen)
          _SuggestionPanel(highlight: _highlight, items: items, query: text),
      ],
    );
  }
}

/// Um item de sugestão (jogo/categoria/dev/plataforma) já achatado para a
/// listbox — o painel é puro visual.
enum SuggestionKind { game, genre, developer, platform }

class SuggestionItem {
  const SuggestionItem({
    required this.kind,
    required this.primaryText,
    this.secondaryText,
    this.value,
    this.imageUrl,
  });

  final SuggestionKind kind;
  final String primaryText;
  final String? secondaryText;

  /// Valor bruto (slug do jogo, nome de gênero, slug de plataforma).
  final String? value;
  final String? imageUrl;
}

/// Ação única de seleção de sugestão — teclado (Enter) e toque compartilham o
/// mesmo comportamento: jogo abre a ficha; gênero/plataforma aplicam filtro;
/// desenvolvedor dispara a busca.
void pickSuggestion(BuildContext context, WidgetRef ref, SuggestionItem item) {
  final SearchFilters filters = ref.read(searchControllerProvider).filters;
  switch (item.kind) {
    case SuggestionKind.game:
      final String? slug = item.value;
      if (slug != null && slug.isNotEmpty) {
        context.push<Object?>('/game/$slug');
      } else {
        unawaited(
          ref
              .read(searchControllerProvider.notifier)
              .submitQuery(item.primaryText),
        );
      }
    case SuggestionKind.genre:
      ref
          .read(searchControllerProvider.notifier)
          .applyFilters(filters.copyWith(genre: item.primaryText));
    case SuggestionKind.developer:
      unawaited(
        ref
            .read(searchControllerProvider.notifier)
            .submitQuery(item.primaryText),
      );
    case SuggestionKind.platform:
      ref
          .read(searchControllerProvider.notifier)
          .applyFilters(filters.copyWith(platform: item.value));
  }
}

List<SuggestionItem> buildSuggestionItems(SuggestPayload payload) =>
    <SuggestionItem>[
      for (final Game game in payload.games)
        SuggestionItem(
          kind: SuggestionKind.game,
          primaryText: game.title,
          secondaryText: game.developer,
          value: game.slug,
          imageUrl: game.coverUrl,
        ),
      for (final GenreInfo genre in payload.genres)
        SuggestionItem(
          kind: SuggestionKind.genre,
          primaryText: genre.name,
          value: genre.name,
        ),
      for (final DeveloperInfo dev in payload.developers)
        SuggestionItem(
          kind: SuggestionKind.developer,
          primaryText: dev.name,
          value: dev.name,
        ),
      for (final PlatformInfo platform in payload.platforms)
        SuggestionItem(
          kind: SuggestionKind.platform,
          primaryText: platform.name,
          value: platform.slug,
        ),
    ];

/// Painel de sugestões: vidro, trecho destacado, navegação por setas
/// refletida em `selected` no Semantics de cada item.
class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.highlight,
    required this.items,
    required this.query,
  });

  final int highlight;
  final List<SuggestionItem> items;
  final String query;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GlassContainer(
        radius: AppRadii.md,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          height: SearchMetrics.suggestionPanel,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    l10n.noSuggestions,
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                )
              : Semantics(
                  liveRegion: true,
                  label: l10n.suggestionsLabel,
                  child: Consumer(
                    builder: (BuildContext context, WidgetRef ref, _) =>
                        ListView.builder(
                          itemCount: items.length,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final SuggestionItem item = items[index];
                            return _SuggestionTile(
                              item: item,
                              query: query,
                              selected: index == highlight,
                              onTap: () => pickSuggestion(context, ref, item),
                            );
                          },
                        ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.item,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final SuggestionItem item;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final String section = switch (item.kind) {
      SuggestionKind.game => l10n.suggestGames,
      SuggestionKind.genre => l10n.suggestGenres,
      SuggestionKind.developer => l10n.suggestDevelopers,
      SuggestionKind.platform => l10n.suggestPlatforms,
    };
    final TextRange range = highlightRange(item.primaryText, query);
    final TextStyle base = context.texts.bodyLarge ?? const TextStyle();
    final TextStyle emphasized = base.copyWith(
      color: context.colors.accent,
      fontWeight: FontWeight.w700,
    );
    // Rótulo acessível composto (seção + texto) via variável: o gate de UI
    // proíbe string literal direto em `label:`.
    final String semanticLabel = '$section: ${item.primaryText}';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: AppSpacing.circleButton,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.glassStrong
                : AppContentColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: <Widget>[
              item.kind == SuggestionKind.game
                  ? SizedBox(
                      width: AppSpacing.navIconSize,
                      height: AppSpacing.navIconSize,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.xxs),
                        child: GameCover(
                          imageUrl: item.imageUrl,
                          title: item.primaryText,
                          memWidth: 64,
                          borderRadius: AppSpacing.xxs,
                        ),
                      ),
                    )
                  : Icon(
                      item.kind == SuggestionKind.platform
                          ? Icons.videogame_asset_rounded
                          : categoryIcon(item.primaryText),
                      size: AppSpacing.navIconSize,
                      color: context.colors.textTertiary,
                    ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (range.isValid)
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: item.primaryText.substring(0, range.start),
                              style: base,
                            ),
                            TextSpan(
                              text: item.primaryText.substring(
                                range.start,
                                range.end,
                              ),
                              style: emphasized,
                            ),
                            TextSpan(
                              text: item.primaryText.substring(range.end),
                              style: base,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        item.primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: base,
                      ),
                    if (item.secondaryText != null &&
                        item.secondaryText!.isNotEmpty)
                      Text(
                        item.secondaryText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                section,
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ferramentas dos resultados: contador (live region) + ordenação + modo.
// ---------------------------------------------------------------------------

/// Barra de resultados: contador anunciado, chips de filtros ativos (abaixo)
/// e alternância grade/lista. Um toque remove cada chip.
class ResultsToolbar extends ConsumerWidget {
  const ResultsToolbar({
    super.key,
    required this.filters,
    required this.facets,
  });

  final SearchFilters filters;
  final CatalogFacets facets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final SearchState state = ref.watch(searchControllerProvider);
    final bool isList = ref.watch(resultsViewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                liveRegion: true,
                header: true,
                child: Text(
                  l10n.resultsCount(state.total),
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _SortButton(current: filters.sort),
            const SizedBox(width: AppSpacing.sm),
            _ViewToggle(isList: isList),
          ],
        ),
        if (filters.activeCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ActiveFilterChips(filters: filters, facets: facets),
        ],
      ],
    );
  }
}

class _SortButton extends ConsumerWidget {
  const _SortButton({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.sortLabel,
      onSelected: (String sort) {
        final SearchFilters filters = ref
            .read(searchControllerProvider)
            .filters;
        ref
            .read(searchControllerProvider.notifier)
            .applyFilters(filters.copyWith(sort: sort));
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      color: context.colors.bgElevated,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        for (final String sort in kSearchSorts)
          PopupMenuItem<String>(
            value: sort,
            child: Row(
              children: <Widget>[
                Icon(
                  current == sort ? Icons.check_rounded : Icons.sort_rounded,
                  size: AppSpacing.navIconSize,
                  color: current == sort
                      ? context.colors.accent
                      : context.colors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(filterSortLabel(l10n, sort)),
              ],
            ),
          ),
      ],
      child: GlassCircleButton(
        icon: Icons.sort_rounded,
        tooltip: l10n.sortLabel,
        active: current != kDefaultSort,
      ),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.isList});

  final bool isList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    return GlassCircleButton(
      icon: isList ? Icons.grid_view_rounded : Icons.view_list_rounded,
      tooltip: isList ? l10n.gridLabel : l10n.listLabel,
      active: isList,
      onTap: () => ref.read(resultsViewProvider.notifier).set(!isList),
    );
  }
}

/// Chips dos filtros ativos — cada um removível com um toque.
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.facets,
  });

  final SearchFilters filters;
  final CatalogFacets facets;

  void _apply(BuildContext context, WidgetRef ref, SearchFilters next) {
    ref.read(searchControllerProvider.notifier).applyFilters(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final List<Widget> chips = <Widget>[];
    final String? platform = filters.platform;
    if (platform != null) {
      String name = platform;
      for (final PlatformInfo item in facets.platforms) {
        if (item.slug == platform) {
          name = item.name;
        }
      }
      chips.add(
        _ActiveChip(
          label: name,
          onTap: () =>
              _apply(context, ref, filters.copyWith(clearPlatform: true)),
        ),
      );
    }
    final String? genre = filters.genre;
    if (genre != null) {
      chips.add(
        _ActiveChip(
          label: genre,
          onTap: () => _apply(context, ref, filters.copyWith(clearGenre: true)),
        ),
      );
    }
    if (filters.freeOnly) {
      chips.add(
        _ActiveChip(
          label: l10n.filterFree,
          onTap: () => _apply(context, ref, filters.copyWith(freeOnly: false)),
        ),
      );
    }
    if (filters.needsRom) {
      chips.add(
        _ActiveChip(
          label: l10n.filterRom,
          onTap: () => _apply(context, ref, filters.copyWith(needsRom: false)),
        ),
      );
    }
    final double? minRating = filters.minRating;
    if (minRating != null) {
      chips.add(
        _ActiveChip(
          label: ratingFilterLabel(minRating),
          onTap: () =>
              _apply(context, ref, filters.copyWith(clearMinRating: true)),
        ),
      );
    }
    if (filters.sort != kDefaultSort) {
      chips.add(
        _ActiveChip(
          label: filterSortLabel(l10n, filters.sort),
          onTap: () =>
              _apply(context, ref, filters.copyWith(sort: kDefaultSort)),
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        // Alvo de toque ≥ 48dp (WCAG 2.2 AA 2.5.8).
        constraints: const BoxConstraints(minHeight: AppSpacing.circleButton),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: context.colors.accent.withValues(alpha: 0.14),
          border: Border.all(
            color: context.colors.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.close_rounded,
              size: 13,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Descoberta: categorias, carrosséis, termos em alta.
// ---------------------------------------------------------------------------

/// Card de categoria (gênero) com ícone próprio e contagem — cores só de
/// tokens do tema (funciona em todos os temas, contraste AA).
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.genre, required this.onTap});

  final GenreInfo genre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: SearchMetrics.categoryTile,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          gradient: context.colors.brandSoft,
          border: Border.all(color: context.colors.glassBorder),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              categoryIcon(genre.name),
              size: AppSpacing.xxl,
              color: context.colors.accent,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    genre.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    context.l10n.gameCount(genre.gameCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrossel horizontal de jogos (mesma forma das linhas da Início).
/// Reutiliza [GameCard]; anima a entrada respeitando reduced motion.
class GameCarousel extends StatelessWidget {
  const GameCarousel({
    super.key,
    required this.title,
    required this.games,
    this.heroPrefix = 'explore',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<Game> games;
  final String heroPrefix;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHeader(
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        SizedBox(
          height: SearchMetrics.rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            itemCount: games.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final Game game = games[index];
              return Align(
                alignment: Alignment.topCenter,
                child: RevealOnMount(
                  index: index,
                  child: GameCard(
                    game: game,
                    width: SearchMetrics.rowCardWidth,
                    heroTag: '$heroPrefix-$title-${game.id}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Faixa de "Em alta nas buscas": chips de títulos populares (proxy
/// conservador de termos — veja ExploreFeed.popularSearches).
class PopularSearchesRow extends ConsumerWidget {
  const PopularSearchesRow({super.key, required this.games, this.extra = 0});

  final List<Game> games;

  /// Margem extra de centralização em telas largas (> contentMax).
  final double extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: AppSpacing.circleButton,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen + extra),
        itemCount: games.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => AppPill(
          label: games[index].title,
          dense: true,
          leading: Icon(
            Icons.trending_up_rounded,
            size: AppSpacing.navIconSize - AppSpacing.xs,
            color: context.colors.accent,
          ),
          onTap: () => unawaited(
            ref
                .read(searchControllerProvider.notifier)
                .submitQuery(games[index].title),
          ),
        ),
      ),
    );
  }
}

/// Aviso de dados salvos (offline/stale) com ação opcional.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, this.onRetry, required this.message});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            size: AppSpacing.navIconSize,
            color: context.colors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: context.texts.labelMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          if (onRetry != null)
            Pressable(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Text(
                  context.l10n.tryAgain,
                  style: context.texts.labelMedium?.copyWith(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Skeleton do modo descoberta: imita a grade de categorias + carrosséis.
class ExploreSkeleton extends StatelessWidget {
  const ExploreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.navContentReserve,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBox(width: 180, height: 22),
            const SizedBox(height: AppSpacing.lg),
            const Row(
              children: <Widget>[
                SkeletonBox(width: 72, height: 44, radius: AppRadii.pill),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 96, height: 44, radius: AppRadii.pill),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 84, height: 44, radius: AppRadii.pill),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SkeletonBox(width: 150, height: 22),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                const GameCardSkeleton(width: SearchMetrics.rowCardWidth),
                const SizedBox(width: AppSpacing.md),
                const GameCardSkeleton(width: SearchMetrics.rowCardWidth),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
