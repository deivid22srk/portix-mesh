import '../../app/app_strings.dart';
import '../../models/download_task.dart';

/// Filtro da fila de downloads no Hub (peça central do loop v2).
enum DownloadFilter { all, active, done, failed }

extension DownloadFilterLabel on DownloadFilter {
  String label(L10n l10n) {
    switch (this) {
      case DownloadFilter.all:
        return l10n.filterAll;
      case DownloadFilter.active:
        return l10n.filterActive;
      case DownloadFilter.done:
        return l10n.filterDone;
      case DownloadFilter.failed:
        return l10n.filterFailed;
    }
  }
}

/// Filtra a fila. `active` = estados transitivos (fila/conectando/baixando/
/// verificando/pausado); `done` e `failed` são terminais.
List<DownloadTask> filterDownloadTasks(
  List<DownloadTask> tasks,
  DownloadFilter filter,
) {
  switch (filter) {
    case DownloadFilter.all:
      return tasks;
    case DownloadFilter.active:
      return tasks
          .where(
            (DownloadTask t) => t.isActive || t.status == DownloadStatus.paused,
          )
          .toList();
    case DownloadFilter.done:
      return tasks.where((DownloadTask t) => t.isDone).toList();
    case DownloadFilter.failed:
      return tasks
          .where((DownloadTask t) => t.status == DownloadStatus.failed)
          .toList();
  }
}
