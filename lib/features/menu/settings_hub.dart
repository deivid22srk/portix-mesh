import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import 'settings_categories.dart';
import 'settings_profile_header.dart';
import '../../shared/widgets/primitives.dart';

/// Termo de busca das configurações — fora do widget para sobreviver às
/// trocas de rota do master-detail (a lista é recriada por categoria).
final settingsSearchProvider = NotifierProvider<SettingsSearchNotifier, String>(
  SettingsSearchNotifier.new,
);

class SettingsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Hub de configurações: título + perfil resumido + busca + lista de
/// categorias. Usado no /menu e como coluna esquerda do master-detail (≥768px).
class SettingsHub extends ConsumerStatefulWidget {
  const SettingsHub({super.key, this.selectedId, this.scrollController});

  /// Categoria destacada quando a página abre em master-detail.
  final String? selectedId;

  /// Controlador da aba Menu (só a instância da raiz da aba o recebe): é ele
  /// que devolve a lista ao topo no re-toque. O master-detail da categoria
  /// monta outra instância com `null` — dois scroll views no mesmo
  /// controlador lançariam erro.
  final ScrollController? scrollController;

  @override
  ConsumerState<SettingsHub> createState() => _SettingsHubState();
}

class _SettingsHubState extends ConsumerState<SettingsHub> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Semeia o campo com o termo já pesquisado (o estado sobrevive às trocas
    // de rota do master-detail — a lista é recriada por categoria).
    _search = TextEditingController(text: ref.read(settingsSearchProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(SettingsCategory category, L10n l10n) {
    final String needle = ref
        .watch(settingsSearchProvider)
        .trim()
        .toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return category.title(l10n).toLowerCase().contains(needle) ||
        category.description(l10n).toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final List<SettingsCategory> visible = kSettingsCategories
        .where((SettingsCategory category) => _matches(category, l10n))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.screen,
            right: AppSpacing.screen,
            top: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.settingsTitle,
                style: context.texts.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.settingsSubtitle,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: SettingsProfileHeader(selectedId: widget.selectedId),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: _SettingsSearchField(
            controller: _search,
            onChanged: (String value) =>
                ref.read(settingsSearchProvider.notifier).set(value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: visible.isEmpty
              ? _SettingsEmptySearch(l10n: l10n)
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    context.bottomChromePadding,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final SettingsCategory category = visible[index];
                    return SettingsCategoryCard(
                      category: category,
                      selected: widget.selectedId == category.id,
                      onTap: () => context.go('/menu/${category.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Campo de busca dentro das configurações: filtra categorias por título e
/// descrição (client-side, sem rede).
class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, _) {
          return Row(
            children: <Widget>[
              Icon(
                Icons.search_rounded,
                size: 20,
                color: context.colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    // Label explícito para leitores de tela; visual idêntico
                    // ao hint (nunca flutua — comportamento de placeholder).
                    labelText: l10n.settingsSearchHint,
                    labelStyle: context.texts.bodyMedium?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: context.texts.bodyMedium,
                ),
              ),
              if (value.text.isNotEmpty)
                Tooltip(
                  message: l10n.settingsSearchClear,
                  child: Pressable(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    scale: 0.9,
                    // Alvo de toque do padrão do app (48dp) mesmo com ícone
                    // pequeno — área maior que o desenho.
                    child: SizedBox(
                      width: AppSpacing.circleButton,
                      height: AppSpacing.circleButton,
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Estado vazio da busca: nada casa com o termo digitado.
class _SettingsEmptySearch extends StatelessWidget {
  const _SettingsEmptySearch({required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: context.colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.settingsSearchEmpty,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de categoria: ícone em vidro com brilho da marca, título,
/// descrição curta e chevron. Alvo de toque ≥ 48dp, Semantics de botão.
class SettingsCategoryCard extends ConsumerWidget {
  const SettingsCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
  });

  final SettingsCategory category;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;

    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.base,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? context.colors.glassStrong : context.colors.glass,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected
                  ? context.colors.accent
                  : context.colors.glassBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: AppSpacing.circleButton,
                height: AppSpacing.circleButton,
                decoration: BoxDecoration(
                  gradient: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(
                  category.icon,
                  size: 22,
                  color: context.colors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.title(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? context.colors.accent
                            : context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      category.description(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
