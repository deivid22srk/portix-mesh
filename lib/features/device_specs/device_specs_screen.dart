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
import 'device_specs_labels.dart';
import 'device_specs_providers.dart';

/// Ficha técnica completa do aparelho (dados públicos do GSMArena).
///
/// Aberta a partir de um relato da comunidade: toque no nome do aparelho →
/// busca → esta tela. Organizada em visão geral, galeria de imagens e grupos
/// de especificações (Tela, Plataforma, Câmeras, Bateria...).
class DeviceSpecsScreen extends ConsumerWidget {
  const DeviceSpecsScreen({super.key, required this.slug});

  final String slug;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<DeviceSpecsDetail> async = ref.watch(
      deviceSpecsDetailProvider(slug),
    );

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeaderBar(
                title: l10n.specsTitle,
                subtitle: async.value?.name ?? l10n.loading,
                showBack: true,
                onBack: () => _back(context),
              ),
              Expanded(
                child: async.value == null
                    ? (async.hasError
                          ? ErrorStateView(
                              message: context.failureText(async.error),
                              retryLabel: l10n.tryAgain,
                              onRetry: () => ref.invalidate(
                                deviceSpecsDetailProvider(slug),
                              ),
                            )
                          : const _DetailSkeleton())
                    : _DetailBody(detail: async.value!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final DeviceSpecsDetail detail;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        context.systemBottomInset + AppSpacing.xxxl,
      ),
      children: <Widget>[
        _HeroCard(detail: detail),
        if (detail.releaseInfo != null ||
            detail.dimensionsInfo != null ||
            detail.osInfo != null ||
            detail.storageInfo != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: l10n.specsOverview,
            child: _OverviewRows(detail: detail),
          ),
        ],
        if (detail.images.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _Gallery(images: detail.images, label: l10n.specsGallery),
        ],
        for (final DeviceSpecGroup group in detail.groups) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: specSectionLabel(l10n, group.title),
            child: _SpecRows(rows: group.rows),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.specsSourceNote,
          textAlign: TextAlign.center,
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Cartão de topo: imagem principal, nome do aparelho e marca.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail});

  final DeviceSpecsDetail detail;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 170,
            width: double.infinity,
            child: detail.thumbnail == null
                ? Icon(
                    Icons.smartphone_rounded,
                    size: AppSpacing.searchFab,
                    color: context.colors.textTertiary,
                  )
                : CachedNetworkImage(
                    imageUrl: detail.thumbnail!,
                    fit: BoxFit.contain,
                    memCacheWidth: 510,
                    fadeInDuration: AppMotion.fast,
                    placeholder: (BuildContext context, String url) =>
                        const SizedBox.expand(),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            Icon(
                              Icons.smartphone_rounded,
                              size: AppSpacing.searchFab,
                              color: context.colors.textTertiary,
                            ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            detail.name,
            textAlign: TextAlign.center,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail.brand.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              detail.brand,
              textAlign: TextAlign.center,
              style: context.texts.labelMedium?.copyWith(
                color: context.colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fatos rápidos: lançamento, dimensões, sistema e armazenamento.
class _OverviewRows extends StatelessWidget {
  const _OverviewRows({required this.detail});

  final DeviceSpecsDetail detail;

  List<Widget> _rows(BuildContext context) {
    final List<(IconData, String?)> facts = <(IconData, String?)>[
      (Icons.event_rounded, detail.releaseInfo),
      (Icons.straighten_rounded, detail.dimensionsInfo),
      (Icons.layers_rounded, detail.osInfo),
      (Icons.storage_rounded, detail.storageInfo),
    ];
    return <Widget>[
      for (final (IconData icon, String? text) in facts)
        if (text != null && text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 16, color: context.colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = _rows(context);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// Galeria oficial: imagens em carrossel horizontal.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.images, required this.label});

  final List<String> images;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  width: 170,
                  color: context.colors.glassStrong,
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    memCacheWidth: 510,
                    fadeInDuration: AppMotion.fast,
                    placeholder: (BuildContext context, String url) =>
                        const SizedBox.expand(),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            Icon(
                              Icons.image_not_supported_rounded,
                              size: AppSpacing.xxl,
                              color: context.colors.textTertiary,
                            ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Cartão de uma seção da ficha (mesma linguagem do relato da comunidade).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: context.colors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Linhas chave → valores dentro da seção, com divisórias finas.
class _SpecRows extends StatelessWidget {
  const _SpecRows({required this.rows});

  final List<DeviceSpecRow> rows;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = context.l10n;
    final List<Widget> children = <Widget>[];
    for (int index = 0; index < rows.length; index += 1) {
      final DeviceSpecRow row = rows[index];
      final String values = row.values.join('\n');
      if (values.isEmpty) {
        continue;
      }
      if (children.isNotEmpty) {
        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            height: 1,
            color: context.colors.glassBorder,
          ),
        );
      }
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              specRowLabel(l10n, row.key),
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.hairline),
            Text(
              values,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Skeleton da ficha enquanto a API responde.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        children: <Widget>[
          GlassContainer(
            radius: AppRadii.lg,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: <Widget>[
                SkeletonBox(
                  width: double.infinity,
                  height: 170,
                  radius: AppRadii.md,
                ),
                const SizedBox(height: AppSpacing.lg),
                SkeletonBox(width: 200, height: 16),
                const SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            radius: AppRadii.md,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 130, height: 11),
                const SizedBox(height: AppSpacing.md),
                SkeletonBox(width: double.infinity, height: 12),
                const SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 220, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
