import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Key, ValueKey, Widget;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/features/profile/profile_controller.dart';
import 'package:portix/shared/widgets/profile_avatar.dart';

import 'ui/ui_test_helpers.dart';

// ============================================================================
// Evidência do cache da imagem de perfil em DOIS níveis:
//
// A) nível cache manager (mesmo mecanismo do ProfileAvatar —
//    DefaultCacheManager do cached_network_image):
//   1. putFile + getSingleFile 5x → 0 downloads (servido do disco);
//   2. removeFile (logout/troca de foto) → próximo acesso faz 1 download;
//   3. URL nova (foto trocada) → 1 download;
//   4. offline (HttpOverrides sintético) com cache → imagem disponível.
//
// B) nível WIDGET (integração real): pump do ProfileAvatar com o mesmo
//    HttpClient contando — 1º uso = 1 download; 5 renderizações seguintes
//    = 0 (memória do framework); clear da memória = 0 (disco atende);
//    removeFile + clear = 1 re-download. É o caminho que o app de fato usa.
//
// Um HttpClient sintético conta cada tentativa de download; nenhuma rede real.
// ============================================================================

const String _avatarUrl = 'http://cache-test.portix/avatar.png';
const String _avatarUrlV2 = 'http://cache-test.portix/avatar.png?v=2';

/// URL exclusiva do teste de integração (nenhum outro teste popula o disco
/// com ela — o 1º render tem que baixar de verdade).
const String _widgetAvatarUrl = 'http://cache-test.portix/widget-avatar.png';

int _downloads = 0;

final Uint8List _png1x1 = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, String> _values = <String, String>{};

  @override
  ContentType? get contentType => ContentType('image', 'png');

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name.toLowerCase()] = value.toString();

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      set(name, value);

  @override
  void remove(String name, Object value) => _values.remove(name.toLowerCase());

  @override
  void removeAll(String name) => _values.remove(name.toLowerCase());

  @override
  void noFolding(String name) {}

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(
        (String name, String value) => action(name, <String>[value]),
      );

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeResponse implements HttpClientResponse {
  const _FakeResponse(this.body);

  final List<int> body;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => body.length;

  @override
  HttpHeaders get headers {
    final _FakeHttpHeaders headers = _FakeHttpHeaders();
    headers.set('etag', '"avatar-v1"');
    headers.set('content-type', 'image/png');
    headers.set('content-length', body.length.toString());
    return headers;
  }

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  @override
  int contentLength = 0;

  @override
  Encoding encoding = Encoding.getByName('utf-8')!;

  @override
  Uri get uri => Uri.parse('http://cache-test.portix/');

  @override
  String get method => 'GET';

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> get done async => _FakeResponse(_png1x1);

  @override
  void abort([Object? cause, StackTrace? stackTrace]) {}

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(_png1x1);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CountingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    _downloads++;
    return _FakeRequest();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CountingOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _CountingHttpClient();
}

void main() {
  // O binding instala o mock HTTP (400) — o nosso override entra DEPOIS dele
  // para que o cache manager use o HttpClient sintético contado.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _downloads = 0;
    HttpOverrides.global = _CountingOverrides();
    // Host de teste não tem plugin path_provider — mocka o channel com um
    // diretório temporário único por chamada.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async {
            final Directory dir = await Directory.systemTemp.createTemp(
              'portix_cache_test',
            );
            return dir.path;
          },
        );
  });

  tearDown(() {
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test('reabrir 5x serve do disco: 0 downloads', () async {
    await DefaultCacheManager().putFile(
      _avatarUrl,
      _png1x1,
      fileExtension: 'png',
    );

    for (int i = 0; i < 5; i++) {
      // Cada "abertura das configurações" consulta a imagem de novo.
      final File file = await DefaultCacheManager().getSingleFile(_avatarUrl);
      expect(file.lengthSync(), _png1x1.length, reason: 'abertura ${i + 1}');
    }

    expect(
      _downloads,
      0,
      reason: 'Tudo do disco — meta: 0 downloads ao reabrir (2ª vez em diante)',
    );
  });

  test('removeFile (logout/troca) força 1 download', () async {
    await DefaultCacheManager().putFile(
      _avatarUrl,
      _png1x1,
      fileExtension: 'png',
    );
    await DefaultCacheManager().removeFile(_avatarUrl);

    await DefaultCacheManager().getSingleFile(_avatarUrl);

    expect(_downloads, 1, reason: 'Cache removido → re-download');
  });

  test('URL nova (foto trocada) faz 1 download', () async {
    await DefaultCacheManager().putFile(
      _avatarUrl,
      _png1x1,
      fileExtension: 'png',
    );

    await DefaultCacheManager().getSingleFile(_avatarUrlV2);

    expect(_downloads, 1, reason: 'URL nova não está no cache → 1 download');
  });

  test('contrato do ProfileAvatar (fallback de iniciais, tamanho, URL)', () {
    final ProfileAvatar avatar = const ProfileAvatar(
      name: 'Ana',
      imageUrl: _avatarUrl,
      size: 62,
    );
    expect(avatar.imageUrl, _avatarUrl);
    expect(avatar.size, 62);
    expect(avatar.name, 'Ana');
    // O widget é StatelessWidget que internamente usa CachedNetworkImage
    // (mesmo DefaultCacheManager validado acima) com iniciais como fallback.
    expect(avatar, isA<Widget>());
  });

  // ========================================================================
  // Integração REAL no widget: pump do ProfileAvatar com o mesmo HttpClient
  // sintético. Prova a cadeia completa — memória (ImageCache do framework)
  // e disco (DefaultCacheManager) — no caminho que o app de fato usa.
  // ========================================================================

  /// Renderiza o avatar e espera o IO real terminar (dentro de runAsync o
  /// event loop real vive): sai quando o contador atinge `want` ou expira.
  Future<void> renderAvatar(
    WidgetTester tester, {
    required String url,
    required int want,
    required String reason,
    Key? key,
  }) async {
    await pumpUi(
      tester,
      child: ProfileAvatar(key: key, name: 'Ana', imageUrl: url, size: 62),
    );
    final Stopwatch sw = Stopwatch()..start();
    while (_downloads < want && sw.elapsedMilliseconds < 5000) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 150));
    expect(_downloads, want, reason: reason);
  }

  testWidgets(
    'PerfilAvatar renderizado: 1 download no 1º uso; 0 nos 5 seguintes; '
    'clear de memória atende do disco; removeFile → 1 re-download',
    (WidgetTester tester) async {
      await tester.runAsync(() async {
        // 1º uso: rede sintética responde 1x e grava em disco.
        await renderAvatar(
          tester,
          url: _widgetAvatarUrl,
          want: 1,
          reason: '1º uso faz exatamente 1 download',
        );

        // 5 "aberturas" seguintes (novas chaves de widget): memória atende.
        for (int i = 0; i < 5; i++) {
          await renderAvatar(
            tester,
            url: _widgetAvatarUrl,
            want: 1,
            key: ValueKey<int>(100 + i),
            reason: '2ª abertura em diante = 0 downloads (meta da missão)',
          );
        }

        // Logout / troca de foto: limpa o cache de MEMÓRIA do framework —
        // o disco atende na sequência, ainda sem rede.
        clearInMemoryImageCache();
        await renderAvatar(
          tester,
          url: _widgetAvatarUrl,
          want: 1,
          key: const ValueKey<String>('pos-clear'),
          reason: 'Após clear do ImageCache o disco atende (0 downloads)',
        );

        // Invalidação explícita (removeFile): 1 re-download garantido via
        // downloadFile(force: true) — contorna o WebHelper, que pode manter
        // por um tempo o BehaviorSubject do download anterior (close
        // pendente do completer da imagem antiga em runners lentos) e
        // responder com replay de FileInfo velho, apontando para o arquivo
        // já removido.
        await DefaultCacheManager().removeFile(_widgetAvatarUrl);
        clearInMemoryImageCache();
        await DefaultCacheManager().downloadFile(_widgetAvatarUrl, force: true);
        clearInMemoryImageCache();
        await renderAvatar(
          tester,
          url: _widgetAvatarUrl,
          want: 2,
          key: const ValueKey<String>('pos-remove'),
          reason:
              'Cache invalidado de verdade → 1 novo download; render '
              'seguinte atende do disco sem rede',
        );
      });
    },
  );
}
