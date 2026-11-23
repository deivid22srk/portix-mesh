import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primitives.dart';

/// Criação da identidade local: nome + @handle.
///
/// Não existe servidor de contas — a identidade vive no aparelho e é o que os
/// outros dispositivos veem na malha.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _handle = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/menu');
    }
  }

  Future<void> _submit() async {
    final L10n l10n = context.l10n;
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.meshNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountProvider.notifier)
          .createIdentity(displayName: name, handle: _handle.text.trim());
      if (mounted) {
        _close();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: AppContentMax(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                GlassCircleButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: l10n.tooltipBack,
                  onTap: _close,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.meshIdentityTitle,
                  style: context.texts.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.meshIdentitySubtitle,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassContainer(
                  radius: AppRadii.lg,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Field(
                        controller: _name,
                        hint: l10n.yourName,
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _Field(
                        controller: _handle,
                        hint: l10n.meshHandleHint,
                        icon: Icons.alternate_email_rounded,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: l10n.meshCreateIdentity,
                        icon: Icons.badge_rounded,
                        isLoading: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: context.colors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              style: context.texts.bodyLarge,
              cursorColor: context.colors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: context.texts.bodyMedium?.copyWith(
                  color: context.colors.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.fieldVertical,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
