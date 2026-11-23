import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/user_avatar_action.dart';
import '../shell/tab_scroll_registry.dart';
import 'settings_hub.dart';

/// Largura da coluna do hub no master-detail (≥768px).
const double _hubColumnWidth = 360;

/// Aba Menu — hub de configurações. Cada categoria abre sua própria rota
/// (`/menu/<id>`), ver settings_category_page.dart.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          AppHeaderBar(
            title: l10n.menuTitle,
            trailing: const UserAvatarAction(),
          ),
          Expanded(
            child: AppContentMax(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide =
                      constraints.maxWidth >= AppBreakpoints.settingsDetail;
                  if (wide) {
                    // Master-detail sem categoria aberta: painel de orientação.
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: _hubColumnWidth,
                          child: SettingsHub(
                            scrollController: TabScrollScope.controllerOf(
                              context,
                              AppTab.menu,
                            ),
                          ),
                        ),
                        Container(width: 1, color: context.colors.glassBorder),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 40,
                                    color: context.colors.textTertiary,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    l10n.settingsSelectHint,
                                    textAlign: TextAlign.center,
                                    style: context.texts.bodyMedium?.copyWith(
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return SettingsHub(
                    scrollController: TabScrollScope.controllerOf(
                      context,
                      AppTab.menu,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
