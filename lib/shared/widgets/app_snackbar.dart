import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/theme/tokens.dart';

/// SnackBar padronizada do app: vidro elevado, raio do tema, ação opcional
/// (ex.: desfazer). Nenhuma tela deve montar `SnackBar` na mão — sempre por
/// aqui, para garantir posição (acima da barra flutuante), cor e duração.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        backgroundColor: context.colors.bgElevated,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        // Flutuante acima da barra de navegação de vidro.
        margin: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewPaddingOf(context).bottom +
              AppSpacing.snackbarBottomGap,
        ),
        duration: const Duration(milliseconds: 4000),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: context.colors.accent,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}
