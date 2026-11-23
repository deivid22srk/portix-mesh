import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_strings.dart';
import '../../app/theme.dart';
import '../../core/device_info.dart';
import '../../core/env.dart';
import '../../core/theme/tokens.dart';
import '../../models/compat_report.dart';
import '../../models/game_detail.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/feedback_report_row.dart';
import '../../shared/widgets/primitives.dart';
import '../../shared/widgets/states.dart';
import 'game_detail_page.dart';

/// Tela com todos os relatos de um jogo (todos os aparelhos), com busca.
class GameReportsPage extends ConsumerStatefulWidget {
  const GameReportsPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<GameReportsPage> createState() => _GameReportsPageState();
}

class _GameReportsPageState extends ConsumerState<GameReportsPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
    final AsyncValue<GameDetail> detail = ref.watch(
      gameDetailProvider(widget.slug),
    );

    return Scaffold(
      backgroundColor: AppContentColors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeaderBar(
                title: l10n.reportsTitle,
                subtitle: detail.value?.game.title ?? l10n.loading,
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
                        Icons.search_rounded,
                        size: 18,
                        color: context.colors.textTertiary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          onChanged: (String _) => setState(() {}),
                          style: context.texts.bodyLarge,
                          cursorColor: context.colors.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: l10n.reportsSearchHint,
                            hintStyle: context.texts.bodyMedium?.copyWith(
                              color: context.colors.textTertiary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_query.text.isNotEmpty)
                        Pressable(
                          onTap: () {
                            _query.clear();
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: context.colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Expanded(
                child: detail.value == null
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
                    : _ReportsList(
                        gameId: detail.value!.game.id,
                        query: _query.text,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsList extends ConsumerWidget {
  _ReportsList({required this.gameId, required this.query});

  final String gameId;
  final String query;

  List<CompatReport> _filter(List<CompatReport> all) {
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return all;
    }
    return all
        .where((CompatReport report) {
          final String haystack = <String>[
            report.author,
            report.brand ?? '',
            report.model ?? '',
            report.soc ?? '',
            report.gpu ?? '',
            report.body,
            report.status,
            report.fps?.toString() ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(term);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = context.l10n;
    final AsyncValue<List<CompatReport>> async = ref.watch(
      gameCompatReportsProvider(gameId),
    );
    final List<CompatReport> reports = async.value ?? const <CompatReport>[];

    if (async.isLoading && reports.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.accent,
          ),
        ),
      );
    }
    if (async.hasError && reports.isEmpty) {
      return ErrorStateView(
        message: context.failureText(async.error),
        retryLabel: l10n.tryAgain,
        onRetry: () => ref.invalidate(gameCompatReportsProvider(gameId)),
      );
    }

    final List<CompatReport> filtered = _filter(reports);
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: reports.isEmpty ? l10n.compatNoReports : l10n.noResultsTitle,
        body: reports.isEmpty ? '' : l10n.noResultsBody,
      );
    }

    return FutureBuilder<DeviceSpecs>(
      future: DeviceInfo.load(),
      builder: (BuildContext context, AsyncSnapshot<DeviceSpecs> snapshot) {
        final String? soc = snapshot.data?.soc;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            context.systemBottomInset + AppSpacing.xxl,
          ),
          itemCount: filtered.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final CompatReport report = filtered[index];
            return FeedbackReportRow(
              report: report,
              sameSoc: soc != null && soc.isNotEmpty && report.soc == soc,
            );
          },
        );
      },
    );
  }
}
