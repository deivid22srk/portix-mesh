import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';
import 'data/device_specs_models.dart';
import 'device_specs_providers.dart';

/// Busca de aparelhos para abrir a ficha técnica.
///
/// A partir de um relato da comunidade, o nome do aparelho abre esta tela já
/// com o termo preenchido; com um único resultado, salta direto para a ficha.
class DeviceSpecsSearchScreen extends ConsumerStatefulWidget {
  const DeviceSpecsSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<DeviceSpecsSearchScreen> createState() =>
      _DeviceSpecsSearchScreenState();
}

class _DeviceSpecsSearchScreenState
    extends ConsumerState<DeviceSpecsSearchScreen> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initialQuery,
  );
  late String _activeQuery = widget.initialQuery.trim();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onFieldChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      setState(() => _activeQuery = value.trim());
    });
  }

  void _submitNow() {
    _debounce?.cancel();
    setState(() => _activeQuery = _field.text.trim());
  }

  void _openDetail(String slug) {
    context.push<Object?>('/specs/$slug');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeaderBar(
                title: l10n.specsSearchTitle,
                showBack: true,
                onBack: _back,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: GlassContainer(
                  radius: AppRadii.pill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.smartphone_rounded,
                        size: AppSpacing.inlineSpinner,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _field,
                          onChanged: _onFieldChanged,
                          onSubmitted: (_) => _submitNow(),
                          textInputAction: TextInputAction.search,
                          style: context.texts.bodyLarge,
                          cursorColor: context.colors.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: l10n.specsSearchHint,
                            hintStyle: context.texts.bodyMedium?.copyWith(
                              color: context.colors.textTertiary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.fieldVertical,
                            ),
                          ),
                        ),
                      ),
                      if (_field.text.isNotEmpty)
                        Pressable(
                          onTap: () {
                            _field.clear();
                            _submitNow();
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: AppSpacing.inlineSpinner,
                            color: context.colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _ResultsList(
                  query: _activeQuery,
                  initialQuery: widget.initialQuery,
                  onOpen: _openDetail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends ConsumerStatefulWidget {
  const _ResultsList({
    required this.query,
    required this.initialQuery,
    required this.onOpen,
  });

  final String query;
  final String initialQuery;
  final void Function(String slug) onOpen;

  @override
  ConsumerState<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends ConsumerState<_ResultsList> {
  bool _autoNavigated = false;

  /// Um único resultado para a busca inicial do relato: abre a ficha direto.
  void _maybeAutoNavigate(List<DeviceSpecsSummary> results) {
    if (_autoNavigated || widget.query.isEmpty) {
      return;
    }
    if (widget.query != widget.initialQuery.trim()) {
      return;
    }
    if (results.length != 1) {
      return;
    }
    _autoNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onOpen(results.single.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final AsyncValue<List<DeviceSpecsSummary>> async = ref.watch(
      deviceSpecsSearchProvider(widget.query),
    );
    final List<DeviceSpecsSummary> results =
        async.value ?? const <DeviceSpecsSummary>[];

    if (widget.query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (async.isLoading && results.isEmpty) {
      return const _SearchSkeleton();
    }
    if (async.hasError && results.isEmpty) {
      return ErrorStateView(
        message: context.failureText(async.error),
        retryLabel: l10n.tryAgain,
        onRetry: () => ref.invalidate(deviceSpecsSearchProvider(widget.query)),
      );
    }
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.devices_other_rounded,
        title: l10n.specsSearchEmptyTitle,
        body: l10n.specsSearchEmptyBody,
      );
    }

    _maybeAutoNavigate(results);

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        context.systemBottomInset + AppSpacing.xxxl,
      ),
      itemCount: results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final DeviceSpecsSummary device = results[index];
        return _DeviceResultRow(
          device: device,
          onTap: () => widget.onOpen(device.slug),
        );
      },
    );
  }
}

class _DeviceResultRow extends StatelessWidget {
  const _DeviceResultRow({required this.device, required this.onTap});

  final DeviceSpecsSummary device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? brand = device.brand;

    return Pressable(
      onTap: onTap,
      child: GlassContainer(
        radius: AppRadii.md,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ColoredBox(
                  color: context.colors.glassStrong,
                  child: device.imageUrl == null
                      ? Icon(
                          Icons.smartphone_rounded,
                          size: AppSpacing.xxl,
                          color: context.colors.textTertiary,
                        )
                      : CachedNetworkImage(
                          imageUrl: device.imageUrl!,
                          fit: BoxFit.contain,
                          memCacheWidth: 168,
                          fadeInDuration: AppMotion.fast,
                          placeholder: (BuildContext context, String url) =>
                              const SizedBox.expand(),
                          errorWidget:
                              (
                                BuildContext context,
                                String url,
                                Object error,
                              ) => Icon(
                                Icons.smartphone_rounded,
                                size: AppSpacing.xxl,
                                color: context.colors.textTertiary,
                              ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (brand != null && brand.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      brand.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < 4; i += 1) ...<Widget>[
              GlassContainer(
                radius: AppRadii.md,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    SkeletonBox(width: 56, height: 56, radius: AppRadii.sm),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SkeletonBox(width: double.infinity, height: 14),
                          const SizedBox(height: AppSpacing.sm),
                          SkeletonBox(width: 110, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
