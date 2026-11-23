import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_strings.dart';
import '../../../app/settings.dart';
import '../../../app/theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/primitives.dart';

/// Categoria "Idioma e Região": Português (BR) ou English, troca instantânea.
class LanguageSettingsBody extends ConsumerWidget {
  const LanguageSettingsBody({super.key, required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    return GlassContainer(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.language,
            style: context.texts.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedControl<String>(
            items: <SegmentItem<String>>[
              SegmentItem<String>(value: 'pt', label: l10n.languagePtBr),
              SegmentItem<String>(value: 'en', label: l10n.languageEn),
            ],
            value: settings.locale.languageCode,
            onChanged: (String code) => ref
                .read(settingsProvider.notifier)
                .setLocale(
                  code == 'en' ? const Locale('en') : const Locale('pt', 'BR'),
                ),
          ),
        ],
      ),
    );
  }
}
