import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../app/theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/theme_selector.dart';

/// Categoria "Aparência e Temas": seletor com miniaturas reais, troca
/// instantânea e animada. Todos os temas passam por contraste AA (teste).
class AppearanceSettingsBody extends ConsumerWidget {
  const AppearanceSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.theme,
          style: context.texts.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.themeHint,
          style: context.texts.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const ThemeSelector(),
      ],
    );
  }
}
