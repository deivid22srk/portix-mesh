import 'package:flutter_test/flutter_test.dart';

import 'package:portix/features/downloads/download_filter.dart';
import 'package:portix/models/download_task.dart';

DownloadTask _t(DownloadStatus status) => DownloadTask(
  gameId: 'g-$status',
  title: 'Jogo $status',
  slug: 'jogo-$status',
  status: status,
);

void main() {
  final List<DownloadTask> queue = <DownloadTask>[
    _t(DownloadStatus.queued),
    _t(DownloadStatus.connecting),
    _t(DownloadStatus.downloading),
    _t(DownloadStatus.verifying),
    _t(DownloadStatus.paused),
    _t(DownloadStatus.done),
    _t(DownloadStatus.done),
    _t(DownloadStatus.failed),
  ];

  test('Filtro all devolve a fila inteira na ordem', () {
    expect(filterDownloadTasks(queue, DownloadFilter.all), same(queue));
  });

  test('Filtro active inclui fila/conectando/baixando/verificando/pausado', () {
    final List<DownloadTask> result = filterDownloadTasks(
      queue,
      DownloadFilter.active,
    );
    expect(result, hasLength(5));
    expect(
      result.map((DownloadTask t) => t.status),
      everyElement(
        anyOf(
          DownloadStatus.queued,
          DownloadStatus.connecting,
          DownloadStatus.downloading,
          DownloadStatus.verifying,
          DownloadStatus.paused,
        ),
      ),
    );
  });

  test('Filtro done e failed separam os terminais', () {
    expect(filterDownloadTasks(queue, DownloadFilter.done), hasLength(2));
    expect(
      filterDownloadTasks(queue, DownloadFilter.done),
      everyElement((DownloadTask t) => t.status == DownloadStatus.done),
    );
    expect(filterDownloadTasks(queue, DownloadFilter.failed), hasLength(1));
  });

  test(
    'Fila vazia: qualquer filtro devolve vazia (Hub mostra estado vazio)',
    () {
      expect(
        filterDownloadTasks(const <DownloadTask>[], DownloadFilter.done),
        isEmpty,
      );
    },
  );
}
