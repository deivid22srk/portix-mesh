import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/home_feed.dart';
import '../../models/search.dart';
import 'primitives.dart';

/// Rótulo do critério de ordenação.
String filterSortLabel(L10n l10n, String sort) {
  switch (sort) {
    case 'recent':
      return l10n.sortRecent;
    case 'rating':
      return l10n.sortRating;
    case 'relevance':
      return l10n.sortRelevance;
    case 'az':
      return l10n.sortAz;
    case 'year':
      return l10n.sortYear;
    case 'trending':
    default:
      // Popularidade = downloads/visitas (métrica real do catálogo).
      return l10n.sortDownloads;
  }
}

/// Notas avaliáveis no filtro de avaliação mínima (existe `rating_avg` real).
const List<double> kRatingFilterOptions = <double>[3, 4, 4.5];

/// Rótulo do chip de nota mínima: "3+", "4+", "4.5+".
String ratingFilterLabel(double rating) {
  final bool whole = rating == rating.truncateToDouble();
  return '${rating.toStringAsFixed(whole ? 0 : 1)}+';
}

/// Abre o painel de filtros (vidro) e devolve o resultado aplicado.
/// Mobile: bottom sheet. Telas largas (≥768px): PAINEL LATERAL fixo ancorado
/// à direita, conteúdo até 90% da altura (padrão Play Store desktop).
Future<SearchFilters?> showFilterSheet(
  BuildContext context, {
  required SearchFilters initial,
  required CatalogFacets facets,
}) {
  final double width = MediaQuery.sizeOf(context).width;
  final bool wide = width >= AppBreakpoints.settingsDetail;
  if (wide) {
    return showDialog<SearchFilters>(
      context: context,
      barrierColor: AppContentColors.scrim.withValues(alpha: 0.6),
      builder: (BuildContext dialogContext) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppContentColors.transparent,
          child: Container(
            key: const ValueKey<String>('filter_side_panel'),
            width: (AppBreakpoints.settingsDetail / 2).clamp(320.0, 420.0),
            decoration: BoxDecoration(
              color: dialogContext.colors.bgElevated,
              borderRadius: const BorderRadius.horizontal(left: AppRadii.sheet),
              border: Border(
                left: BorderSide(color: dialogContext.colors.glassBorder),
              ),
            ),
            child: _FilterSheet(
              initial: initial,
              facets: facets,
              floating: true,
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppContentColors.transparent,
    barrierColor: AppContentColors.scrim.withValues(alpha: 0.6),
    builder: (BuildContext context) => KeyedSubtree(
      key: const ValueKey<String>('filter_bottom_sheet'),
      child: _FilterSheet(initial: initial, facets: facets),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  _FilterSheet({
    required this.initial,
    required this.facets,
    this.floating = false,
  });

  final SearchFilters initial;
  final CatalogFacets facets;

  /// Painel flutuante (telas largas): raio completo em vez de sheet de topo.
  final bool floating;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _filters = widget.initial;

  void _apply() => Navigator.of(context).pop(_filters);

  void _reset() => setState(() => _filters = const SearchFilters());

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final double maxHeight = MediaQuery.of(context).size.height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.bgElevated,
          borderRadius: widget.floating
              ? BorderRadius.circular(AppRadii.lg)
              : const BorderRadius.vertical(top: AppRadii.sheet),
          border: widget.floating
              ? Border.all(color: context.colors.glassBorder)
              : Border(top: BorderSide(color: context.colors.glassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              10,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.textTertiary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.filters,
                        style: context.texts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SecondaryButton(
                      label: l10n.reset,
                      expand: false,
                      onPressed: _reset,
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SheetLabel(l10n.filterPlatform),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            AppPill(
                              label: l10n.all,
                              dense: true,
                              selected: _filters.platform == null,
                              onTap: () => setState(
                                () => _filters = _filters.copyWith(
                                  clearPlatform: true,
                                ),
                              ),
                            ),
                            for (final PlatformInfo platform
                                in widget.facets.platforms)
                              AppPill(
                                label: platform.name,
                                dense: true,
                                selected: _filters.platform == platform.slug,
                                onTap: () => setState(() {
                                  _filters = _filters.platform == platform.slug
                                      ? _filters.copyWith(clearPlatform: true)
                                      : _filters.copyWith(
                                          platform: platform.slug,
                                        );
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _SheetLabel(l10n.filterGenre),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            AppPill(
                              label: l10n.all,
                              dense: true,
                              selected: _filters.genre == null,
                              onTap: () => setState(
                                () => _filters = _filters.copyWith(
                                  clearGenre: true,
                                ),
                              ),
                            ),
                            for (final GenreInfo genre in widget.facets.genres)
                              AppPill(
                                label: genre.name,
                                dense: true,
                                selected: _filters.genre == genre.name,
                                onTap: () => setState(() {
                                  _filters = _filters.genre == genre.name
                                      ? _filters.copyWith(clearGenre: true)
                                      : _filters.copyWith(genre: genre.name);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _SheetLabel(l10n.sortLabel),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            for (final String sort in kSearchSorts)
                              AppPill(
                                label: filterSortLabel(l10n, sort),
                                dense: true,
                                selected: _filters.sort == sort,
                                onTap: () => setState(
                                  () =>
                                      _filters = _filters.copyWith(sort: sort),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _SheetLabel(l10n.filterMinRating),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            AppPill(
                              label: l10n.all,
                              dense: true,
                              selected: _filters.minRating == null,
                              onTap: () => setState(
                                () => _filters = _filters.copyWith(
                                  clearMinRating: true,
                                ),
                              ),
                            ),
                            for (final double rating in kRatingFilterOptions)
                              AppPill(
                                label: ratingFilterLabel(rating),
                                dense: true,
                                selected: _filters.minRating == rating,
                                onTap: () => setState(() {
                                  _filters = _filters.minRating == rating
                                      ? _filters.copyWith(clearMinRating: true)
                                      : _filters.copyWith(minRating: rating);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ToggleRow(
                          title: l10n.filterFree,
                          value: _filters.freeOnly,
                          onChanged: (bool value) => setState(
                            () => _filters = _filters.copyWith(freeOnly: value),
                          ),
                        ),
                        _ToggleRow(
                          title: l10n.filterRom,
                          value: _filters.needsRom,
                          onChanged: (bool value) => setState(
                            () => _filters = _filters.copyWith(needsRom: value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.apply,
                  icon: Icons.check_rounded,
                  onPressed: _apply,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.colors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: context.texts.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AppToggle(value: value, semanticLabel: title, onChanged: onChanged),
        ],
      ),
    );
  }
}
