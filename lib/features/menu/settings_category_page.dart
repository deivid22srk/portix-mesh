import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../features/shell/not_found_page.dart';
import '../../shared/widgets/primitives.dart';
import 'categories/account_settings.dart';
import 'categories/appearance_settings.dart';
import 'categories/data_settings.dart';
import 'categories/language_settings.dart';
import 'categories/notifications_settings.dart';
import 'categories/network_settings.dart';
import 'categories/about_settings.dart';
import 'settings_categories.dart';
import 'settings_hub.dart';

/// Largura da coluna do hub no master-detail (≥768px).
const double _hubColumnWidth = 360;

/// Container de uma categoria de configurações.
///
/// Mobile (<768px): drill-down — tela cheia com voltar + título.
/// Larga (≥768px): master-detail — lista à esquerda, conteúdo à direita,
/// a rota continua sendo a fonte do estado (deep link/back funcionam).
class SettingsCategoryPage extends ConsumerWidget {
  const SettingsCategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsCategory? category = settingsCategoryById(categoryId);
    if (category == null) {
      return const NotFoundPage();
    }

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide =
              constraints.maxWidth >= AppBreakpoints.settingsDetail;
          if (wide) {
            // Mesmo teto de largura do resto do app: nada estica por um
            // monitor inteiro (Linear/Vercel também limitam a largura).
            return AppContentMax(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: _hubColumnWidth,
                    child: SettingsHub(selectedId: categoryId),
                  ),
                  Container(width: 1, color: context.colors.glassBorder),
                  Expanded(
                    child: CategoryContent(
                      category: category,
                      showBack: false,
                      detailMode: true,
                    ),
                  ),
                ],
              ),
            );
          }
          return CategoryContent(category: category, showBack: true);
        },
      ),
    );
  }
}

/// Conteúdo de uma categoria: cabeçalho (voltar + título + descrição) e corpo.
class CategoryContent extends StatelessWidget {
  const CategoryContent({
    super.key,
    required this.category,
    required this.showBack,
    this.detailMode = false,
  });

  final SettingsCategory category;
  final bool showBack;
  final bool detailMode;

  Widget _body(BuildContext context) {
    final L10n l10n = context.l10n;
    return switch (category.id) {
      kSettingsAccount => AccountSettingsBody(l10n: l10n),
      kSettingsAppearance => AppearanceSettingsBody(l10n: l10n),
      kSettingsNotifications => NotificationsSettingsBody(l10n: l10n),
      kSettingsLanguage => LanguageSettingsBody(l10n: l10n),
      kSettingsData => DataSettingsBody(l10n: l10n),
      kSettingsNetwork => NetworkSettingsBody(l10n: l10n),
      kSettingsAbout => AboutSettingsBody(l10n: l10n),
      _ => NotFoundPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final Widget content = AppContentMax(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        // Destrutivo/detail: a navbar de vidro flutua em TODAS as rotas do
        // shell — o conteúdo precisa do espaço dela em ambos os modos.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          context.bottomChromePadding + AppSpacing.sm,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showBack) ...<Widget>[
                _BackButton(),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.title(l10n),
                      style: context.texts.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      category.description(l10n),
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _body(context),
        ],
      ),
    );
    if (detailMode) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: content,
      );
    }
    return content;
  }
}

/// Voltar do drill-down (mobile): além do voltar do sistema.
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    return Tooltip(
      message: l10n.tooltipBack,
      child: Pressable(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/menu');
          }
        },
        scale: 0.94,
        child: Container(
          width: AppSpacing.circleButton,
          height: AppSpacing.circleButton,
          decoration: BoxDecoration(
            color: context.colors.glassStrong,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: context.colors.glassBorder),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
