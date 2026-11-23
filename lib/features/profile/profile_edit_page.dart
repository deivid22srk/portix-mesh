import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../models/profile.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/game_media.dart';
import '../../shared/widgets/primitives.dart';
import 'profile_controller.dart';

/// Edição de perfil: nome + URL da capa (opcional).
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _handle = TextEditingController();
  final TextEditingController _cover = TextEditingController();
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _cover.dispose();
    super.dispose();
  }

  void _snack(String message) {
    // Padrão único do app — ver showAppSnackBar (app_snackbar.dart).
    showAppSnackBar(context, message: message);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/menu');
    }
  }

  Future<void> _save() async {
    final L10n l10n = context.l10n;
    setState(() => _busy = true);
    try {
      // Cache da foto anterior: se a URL continuar a mesma (reupload no mesmo
      // caminho), o arquivo precisa sair do cache para a nova imagem aparecer.
      final String? oldCover = ref.read(profileProvider).value?.coverUrl;
      await ref
          .read(catalogRepositoryProvider)
          .updateProfile(displayName: _name.text, coverUrl: _cover.text);
      try {
        await ref
            .read(catalogRepositoryProvider)
            .setHandle(_handle.text.trim());
      } on Object catch (error) {
        final String text = error.toString();
        if (!mounted) {
          return;
        }
        setState(() => _busy = false);
        _snack(
          text.contains('HANDLE_TAKEN') ? l10n.handleTaken : l10n.handleInvalid,
        );
        return;
      }
      // Trocou a foto = cache invalidado (chave é a URL; conteúdo novo no
      // mesmo endereço exige remoção explícita do arquivo em disco).
      await _invalidateCover(oldCover);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, message: context.l10n.profileSaved);
      _close();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Remove do cache de imagem o arquivo da capa antiga/trocada (disco) e
  /// limpa o cache de memória do framework — reupload na MESMA URL não pode
  /// exibir o avatar antigo enquanto o ImageCache tiver a imagem decodificada.
  /// A seguir revalida o perfil (o SWR traz o novo valor sem loading).
  Future<void> _invalidateCover(String? oldCover) async {
    final List<String> targets = <String>[
      if (oldCover != null && oldCover.isNotEmpty) oldCover,
      if (_cover.text.trim().isNotEmpty) _cover.text.trim(),
    ];
    for (final String url in targets) {
      try {
        await DefaultCacheManager().removeFile(url);
      } on Object {
        // Sem arquivo em cache (ou falha local): refetch resolve na revalida.
      }
    }
    clearInMemoryImageCache();
    await ref.read(profileProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final bool signedIn = ref.watch(accountProvider).isSignedIn;
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);

    if (!_initialized && profile.hasValue) {
      _name.text = profile.requireValue.displayName;
      _handle.text = profile.requireValue.handle ?? '';
      _cover.text = profile.requireValue.coverUrl ?? '';
      _initialized = true;
    }

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
                  tooltip: context.l10n.tooltipBack,
                  onTap: _close,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.editProfile,
                  style: context.texts.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!signedIn)
                  GlassContainer(
                    radius: AppRadii.lg,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.loginRequired,
                          style: context.texts.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: l10n.signIn,
                          icon: Icons.login_rounded,
                          onPressed: () => context.push<Object?>('/auth'),
                        ),
                      ],
                    ),
                  )
                else
                  GlassContainer(
                    radius: AppRadii.lg,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              child: GameCover(
                                title: _name.text.isEmpty
                                    ? l10n.guestLabel
                                    : _name.text,
                                imageUrl: _cover.text.trim().isEmpty
                                    ? null
                                    : _cover.text.trim(),
                                memWidth: 240,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _Label(l10n.yourName),
                        const SizedBox(height: AppSpacing.sm),
                        _Input(controller: _name, hint: l10n.yourName),
                        const SizedBox(height: AppSpacing.lg),
                        _Label(l10n.handleLabel),
                        const SizedBox(height: AppSpacing.sm),
                        _Input(controller: _handle, hint: l10n.handleHint),
                        const SizedBox(height: AppSpacing.lg),
                        _Label(l10n.coverUrlLabel),
                        const SizedBox(height: AppSpacing.sm),
                        _Input(controller: _cover, hint: l10n.coverHint),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          label: l10n.saveChanges,
                          icon: Icons.check_rounded,
                          isLoading: _busy,
                          onPressed: _save,
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.texts.labelMedium?.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
    );
  }
}
