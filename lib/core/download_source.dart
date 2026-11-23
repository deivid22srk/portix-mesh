// Classificação de links do catálogo: a maioria é página de destino de port
// (GitHub repo, Telegram, Drive, MediaFire...), não um APK direto. Só tentamos
// baixar/instalar quando há um arquivo direto; caso contrário, abrimos a fonte.

bool isDirectApkUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final String host = uri.host.toLowerCase();
  final String path = uri.path.toLowerCase();

  if (path.endsWith('.apk')) {
    return true;
  }
  if (host == 'raw.githubusercontent.com') {
    return true;
  }
  if (host.endsWith('github.com') && path.contains('/releases/download/')) {
    return true;
  }
  if (host.endsWith('archive.org') && path.contains('/download/')) {
    return true;
  }
  if (host.endsWith('sourceforge.net') && path.contains('/download')) {
    return true;
  }
  return false;
}

/// Normaliza links conhecidos para um download direto quando possível.
String resolveDirectUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return url;
  }
  final String host = uri.host.toLowerCase();

  if (host.endsWith('drive.google.com')) {
    final RegExpMatch? match = RegExp(
      r'/file/d/([A-Za-z0-9_-]+)',
    ).firstMatch(uri.path);
    final String? id = match?.group(1) ?? uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$id';
    }
  }
  if (host.endsWith('dropbox.com')) {
    return uri
        .replace(
          queryParameters: <String, String>{...uri.queryParameters, 'dl': '1'},
        )
        .toString();
  }
  return url;
}
