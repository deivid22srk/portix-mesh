import 'parsing.dart';

enum DownloadStatus {
  queued,
  connecting,
  downloading,
  verifying,
  paused,
  done,
  failed,
}

class DownloadTask {
  const DownloadTask({
    required this.gameId,
    required this.title,
    required this.slug,
    this.coverUrl,
    this.portKey,
    this.portUrl,
    this.platformName,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.startedAt,
    this.nativeId,
    this.apkPath,
    this.releaseTag,
    this.packageName,
    this.versionName,
    this.versionCode,
    this.error,
    this.speedBps = 0,
    this.etaSecs = -1,
    this.doneBytes = 0,
    this.totalBytes = 0,
  });

  final String gameId;
  final String title;
  final String slug;
  final String? coverUrl;
  final String? portKey;
  final String? portUrl;
  final String? platformName;
  final DownloadStatus status;
  final double progress;
  final DateTime? startedAt;

  /// Identificador do download nativo (serviço Android), quando aplicável.
  final int? nativeId;

  /// Caminho do APK baixado, quando concluído pelo motor nativo.
  final String? apkPath;

  /// Tag da release do GitHub de onde o APK veio (para detectar atualizações).
  final String? releaseTag;

  /// Nome do pacote lido do próprio APK baixado.
  final String? packageName;

  /// Versão declarada no APK baixado.
  final String? versionName;

  /// Código de versão declarado no APK baixado.
  final int? versionCode;

  /// Mensagem de erro quando o download falha.
  final String? error;

  /// Velocidade suavizada (bytes/s) reportada pelo motor. Transiente —
  /// não é persistida (ao reabrir o app começa em 0).
  final double speedBps;

  /// ETA em segundos (-1 = desconhecido). Transiente.
  final int etaSecs;

  /// Bytes baixados no instante (para exibir "X de Y"). Transiente.
  final int doneBytes;

  /// Tamanho total conhecido (0 = desconhecido). Transiente.
  final int totalBytes;

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.connecting ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.verifying;

  bool get isDone => status == DownloadStatus.done;

  bool get isTransferring =>
      status == DownloadStatus.connecting ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.verifying;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? portUrl,
    String? platformName,
    String? apkPath,
    String? releaseTag,
    String? packageName,
    String? versionName,
    int? versionCode,
    String? error,
    double? speedBps,
    int? etaSecs,
    int? doneBytes,
    int? totalBytes,
  }) => DownloadTask(
    gameId: gameId,
    title: title,
    slug: slug,
    coverUrl: coverUrl,
    portKey: portKey,
    portUrl: portUrl ?? this.portUrl,
    platformName: platformName ?? this.platformName,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    startedAt: startedAt,
    nativeId: nativeId,
    apkPath: apkPath ?? this.apkPath,
    releaseTag: releaseTag ?? this.releaseTag,
    packageName: packageName ?? this.packageName,
    versionName: versionName ?? this.versionName,
    versionCode: versionCode ?? this.versionCode,
    error: error ?? this.error,
    speedBps: speedBps ?? this.speedBps,
    etaSecs: etaSecs ?? this.etaSecs,
    doneBytes: doneBytes ?? this.doneBytes,
    totalBytes: totalBytes ?? this.totalBytes,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'game_id': gameId,
    'title': title,
    'slug': slug,
    'cover_url': coverUrl,
    'port_key': portKey,
    'port_url': portUrl,
    'platform_name': platformName,
    'status': status.name,
    'progress': progress,
    'started_at': startedAt?.toIso8601String(),
    'native_id': nativeId,
    'apk_path': apkPath,
    'release_tag': releaseTag,
    'package_name': packageName,
    'version_name': versionName,
    'version_code': versionCode,
    'error': error,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> map) {
    final String rawStatus = asTextOr(map['status'], 'paused');
    DownloadStatus status = DownloadStatus.paused;
    for (final DownloadStatus candidate in DownloadStatus.values) {
      if (candidate.name == rawStatus) {
        status = candidate;
      }
    }
    return DownloadTask(
      gameId: asTextOr(map['game_id'], ''),
      title: asTextOr(map['title'], ''),
      slug: asTextOr(map['slug'], ''),
      coverUrl: asText(map['cover_url']),
      portKey: asText(map['port_key']),
      portUrl: asText(map['port_url']),
      platformName: asText(map['platform_name']),
      status: status,
      progress: asDouble(map['progress']),
      startedAt: asDate(map['started_at']),
      nativeId: map['native_id'] == null ? null : asInt(map['native_id']),
      apkPath: asText(map['apk_path']),
      releaseTag: asText(map['release_tag']),
      packageName: asText(map['package_name']),
      versionName: asText(map['version_name']),
      versionCode: map['version_code'] == null
          ? null
          : asInt(map['version_code']),
      error: asText(map['error']),
    );
  }
}
