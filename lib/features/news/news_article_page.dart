import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../models/news.dart';
import '../../shared/widgets/news_media.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';

/// Artigo completo de uma notícia (ou `null` se não existir).
final newsArticleProvider = FutureProvider.family<NewsItem?, String>(
  (ref, String slug) =>
      ref.watch(catalogRepositoryProvider).fetchNewsArticle(slug),
);

class NewsArticlePage extends ConsumerWidget {
  const NewsArticlePage({super.key, required this.slug, this.initial});

  final String slug;

  /// Item já carregado pelo feed, exibido de imediato enquanto atualiza.
  final NewsItem? initial;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/news');
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Sem app/navegador disponível: ignora silenciosamente.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<NewsItem?> async = ref.watch(newsArticleProvider(slug));
    final NewsItem? item = async.value ?? initial;

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: AppContentMax(
            child: item == null
                ? _MissingArticle(
                    loading: async.isLoading,
                    message: async.hasError
                        ? context.failureText(async.error)
                        : l10n.newsEmpty,
                    retryLabel: l10n.tryAgain,
                    onRetry: () => ref.invalidate(newsArticleProvider(slug)),
                    onBack: () => _back(context),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.md,
                      AppSpacing.screen,
                      context.systemBottomInset + AppSpacing.xxl,
                    ),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GlassCircleButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: context.l10n.tooltipBack,
                          onTap: () => _back(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: NewsCover(item: item, memWidth: 1400),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        item.category.toUpperCase(),
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.title,
                        style: context.texts.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      if (item.titleOriginal != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.titleOriginal!,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _ArticleMeta(item: item, l10n: l10n),
                      if (item.summary.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          item.summary,
                          style: context.texts.bodyLarge?.copyWith(
                            color: context.colors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                      if (item.keyPoints.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        GlassContainer(
                          radius: AppRadii.lg,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.keyPointsTitle,
                                style: context.texts.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              for (final String point in item.keyPoints)
                                _KeyPoint(text: point),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (item.sourceUrl != null)
                        PrimaryButton(
                          label: l10n.readOnSource,
                          icon: Icons.open_in_new_rounded,
                          onPressed: () => _open(item.sourceUrl),
                        ),
                      if (item.projectUrl != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: l10n.viewProject,
                          icon: Icons.code_rounded,
                          onPressed: () => _open(item.projectUrl),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ArticleMeta extends StatelessWidget {
  _ArticleMeta({required this.item, required this.l10n});

  final NewsItem item;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = <String>[
      if (item.author != null) '${l10n.byAuthor} ${item.author}',
      if (item.sourceName != null) item.sourceName!,
      if (item.publishedAt != null) formatDate(item.publishedAt, en: l10n.isEn),
    ];
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join('  ·  '),
      style: context.texts.bodySmall?.copyWith(
        color: context.colors.textTertiary,
      ),
    );
  }
}

class _KeyPoint extends StatelessWidget {
  _KeyPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.colors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingArticle extends StatelessWidget {
  _MissingArticle({
    required this.loading,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.onBack,
  });

  final bool loading;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GlassCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: context.l10n.tooltipBack,
              onTap: onBack,
            ),
          ),
        ),
        Expanded(
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.accent,
                    ),
                  ),
                )
              : ErrorStateView(
                  message: message,
                  retryLabel: retryLabel,
                  onRetry: onRetry,
                ),
        ),
      ],
    );
  }
}
