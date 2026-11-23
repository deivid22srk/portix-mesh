import '../../../core/env.dart';
import 'device_specs_api.dart';
import 'device_specs_models.dart';

/// Regras de busca da ficha técnica.
///
/// Estratégia em duas camadas:
/// 1. Endpoint de busca da API (quando disponível na instância);
/// 2. Fallback determinístico por marca: resolve a marca pelo texto (com
///    apelidos — Poco/Redmi → Xiaomi, Galaxy → Samsung, iPhone → Apple...),
///    carrega as páginas da marca em paralelo (concorrência limitada) e
///    pontua os nomes normalizados localmente.
///
/// Tudo é cacheado em memória por sessão: pesquisar de novo pela mesma marca
/// ou abrir a mesma ficha não gera novas requisições.
class DeviceSpecsRepository {
  DeviceSpecsRepository({DeviceSpecsApi? api}) : _api = api ?? DeviceSpecsApi();

  final DeviceSpecsApi _api;

  List<DeviceSpecsBrand>? _brands;
  final Map<String, DeviceSpecsDetail> _details = <String, DeviceSpecsDetail>{};
  final Map<String, List<DeviceSpecsSummary>> _brandDevices =
      <String, List<DeviceSpecsSummary>>{};
  bool? _directSearchHealthy;

  /// Máximo de páginas por marca (pior caso observado: 16 páginas).
  static const int _maxPagesPerBrand = 20;

  /// Requisições paralelas por busca de marca (cortesia com a instância
  /// gratuita; 50 aparelhos por página ≈ 300 dispositivos por lote).
  static const int _concurrency = 6;

  Future<List<DeviceSpecsBrand>> brands() async {
    final List<DeviceSpecsBrand>? cached = _brands;
    if (cached != null) {
      return cached;
    }
    final List<DeviceSpecsBrand> fetched = await _api.brands();
    _brands = fetched;
    return fetched;
  }

  /// Ficha técnica completa por slug, cacheada em memória.
  Future<DeviceSpecsDetail> device(String slug) async {
    final DeviceSpecsDetail? cached = _details[slug];
    if (cached != null) {
      return cached;
    }
    final DeviceSpecsDetail detail = await _api.device(slug);
    _details[slug] = detail;
    return detail;
  }

  /// Busca aparelhos por texto livre. Nunca lança por “não achou”: retorna
  /// lista vazia (a tela mostra o estado vazio).
  Future<List<DeviceSpecsSummary>> search(
    String query, {
    String? brandHint,
  }) async {
    final String term = query.trim();
    if (term.isEmpty) {
      return const <DeviceSpecsSummary>[];
    }

    // 1) Busca direta da API, se estiver saudável nesta sessão.
    if (_directSearchHealthy != false) {
      try {
        final List<DeviceSpecsSummary> direct = await _api.search(term);
        _directSearchHealthy = true;
        final List<DeviceSpecsSummary> ranked = _rank(direct, term, brandHint);
        if (ranked.isNotEmpty) {
          return ranked;
        }
      } on AppFailure {
        // Endpoint de busca indisponível (ex.: navegador ausente na
        // instância): marca como não saudável e segue para o fallback.
        _directSearchHealthy = false;
      }
    }

    // 2) Fallback por marca.
    final DeviceSpecsBrand? brand = await _resolveBrand(term, brandHint);
    if (brand == null) {
      return const <DeviceSpecsSummary>[];
    }
    final List<DeviceSpecsSummary> devices = await _brandDevicesOf(brand.slug);
    return _rank(devices, term, brandHint);
  }

  /// Resolve a marca do texto: apelidos conhecidos primeiro (Poco, Redmi,
  /// Galaxy, iPhone...), depois o texto informado no relato e por fim o
  /// início da própria busca.
  Future<DeviceSpecsBrand?> _resolveBrand(
    String term,
    String? brandHint,
  ) async {
    final List<DeviceSpecsBrand> all = await brands();
    final Map<String, DeviceSpecsBrand> byName = <String, DeviceSpecsBrand>{
      for (final DeviceSpecsBrand b in all) normalize(b.name): b,
    };

    for (final String candidate in <String>[
      ?brandHint,
      _firstBrandWord(term),
      term,
    ]) {
      final String norm = normalize(candidate);
      if (norm.isEmpty) {
        continue;
      }
      final DeviceSpecsBrand? direct = byName[norm];
      if (direct != null) {
        return direct;
      }
      final String? alias = _brandAliases[norm];
      if (alias != null) {
        return byName[normalize(alias)];
      }
    }
    return null;
  }

  /// Primeira palavra útil do texto (nome de marca geralmente abre a busca).
  String _firstBrandWord(String term) => _words(term).firstOrNull ?? term;

  /// Todos os aparelhos de uma marca (todas as páginas), cacheados.
  Future<List<DeviceSpecsSummary>> _brandDevicesOf(String brandSlug) async {
    final List<DeviceSpecsSummary>? cached = _brandDevices[brandSlug];
    if (cached != null) {
      return cached;
    }
    final DeviceSpecsBrandPage first = await _api.brandPage(brandSlug, 1);
    final List<DeviceSpecsSummary> devices = first.phones.toList();
    final int lastPage = first.lastPage.clamp(1, _maxPagesPerBrand);

    if (lastPage > 1) {
      final List<Future<List<DeviceSpecsSummary>?> Function()> pending =
          <Future<List<DeviceSpecsSummary>?> Function()>[
            for (int page = 2; page <= lastPage; page += 1)
              () async {
                try {
                  return (await _api.brandPage(brandSlug, page)).phones;
                } on AppFailure {
                  return null; // Página falhou: busca segue com as demais.
                }
              },
          ];
      final List<List<DeviceSpecsSummary>?> pages = await _pool(
        pending,
        _concurrency,
      );
      for (final List<DeviceSpecsSummary>? page in pages) {
        if (page != null) {
          devices.addAll(page);
        }
      }
    }

    _brandDevices[brandSlug] = devices;
    return devices;
  }

  /// Executa tarefas com concorrência limitada (ordem de conclusão).
  static Future<List<T>> _pool<T>(
    List<Future<T> Function()> tasks,
    int limit,
  ) async {
    final List<T> results = <T>[];
    final List<Future<T> Function()> queue = List.of(tasks);
    final int workers = limit.clamp(1, tasks.isEmpty ? 1 : tasks.length);
    await Future.wait(<Future<void>>[
      for (int i = 0; i < workers; i += 1)
        () async {
          while (queue.isNotEmpty) {
            final Future<T> task = queue.removeAt(0)();
            results.add(await task);
          }
        }(),
    ]);
    return results;
  }

  /// Pontua os aparelhos contra o termo buscado.
  List<DeviceSpecsSummary> _rank(
    List<DeviceSpecsSummary> devices,
    String term,
    String? brandHint,
  ) {
    final List<String> queryWords = _words(term);
    // Palavras de marca já contidas no nome de muitos modelos (ex.: “Poco X6
    // Pro”, “Galaxy S24”): descontá-las evita exigir presença dupla.
    final Set<String> brandWords = <String>{
      ..._words(brandHint ?? ''),
      ..._brandAliasWordsFor(term),
    };
    final List<String> modelWords = queryWords
        .where((String w) => !brandWords.contains(w))
        .toList(growable: false);
    final List<String> effectiveWords = modelWords.isEmpty
        ? queryWords
        : modelWords;

    final List<(DeviceSpecsSummary, int)> scored =
        <(DeviceSpecsSummary, int)>[];
    for (final DeviceSpecsSummary device in devices) {
      final int score = _score(device, effectiveWords, queryWords);
      if (score > 0) {
        scored.add((device, score));
      }
    }
    scored.sort((a, b) {
      final int byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) {
        return byScore;
      }
      return a.$1.name.length.compareTo(b.$1.name.length);
    });
    return <DeviceSpecsSummary>[
      for (final (DeviceSpecsSummary device, int _) in scored.take(24)) device,
    ];
  }

  int _score(
    DeviceSpecsSummary device,
    List<String> words,
    List<String> allWords,
  ) {
    final String name = device.name.toLowerCase();
    final Set<String> nameWords = _words(name).toSet();
    final Set<String> haystackWords = <String>{
      ...nameWords,
      ..._words(device.brand ?? ''),
    };
    final String compact = name.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // 100 — nome completo igual; 80 — começa com o termo; 60 — contém o termo.
    final String joined = words.join(' ');
    final String compactQuery = joined.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact == compactQuery) {
      return 100;
    }
    if (compactQuery.length >= 5 && compact.startsWith(compactQuery)) {
      return 80;
    }
    if (compactQuery.length >= 5 && compact.contains(compactQuery)) {
      return 60;
    }

    // Todas as palavras presentes → 60; uma a uma → 10 por palavra.
    final int present = words.where(haystackWords.contains).length;
    if (words.isNotEmpty && present == words.length) {
      return 60;
    }
    if (compactQuery.length >= 5 && compact.contains(compactQuery)) {
      return 55;
    }
    return present == allWords.length ? 55 : present * 10;
  }

  static const Map<String, String> _brandAliases = <String, String>{
    'poco': 'Xiaomi',
    'redmi': 'Xiaomi',
    'galaxy': 'Samsung',
    'iphone': 'Apple',
    'ipad': 'Apple',
    'pixel': 'Google',
    'moto': 'Motorola',
    'rog': 'Asus',
    'zenfone': 'Asus',
    'hmd': 'HMD',
  };

  Set<String> _brandAliasWordsFor(String term) {
    final Set<String> words = <String>{};
    for (final String word in _words(term)) {
      final String? alias = _brandAliases[word];
      if (alias != null) {
        words.addAll(_words(alias.toLowerCase()));
        words.add(word);
      }
    }
    return words;
  }

  /// Normaliza texto para comparação (minúsculas, só letras e números).
  static String normalize(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Palavras normalizadas (minúsculas, só letras/números; números e termos
  /// com 2+ letras contam — “X6”, “5G” e “Pro” são sinais fortes).
  static List<String> _words(String input) {
    final RegExp token = RegExp(r'[a-z0-9]+');
    return token
        .allMatches(input.toLowerCase())
        .map((RegExpMatch match) => match.group(0))
        .whereType<String>()
        .toList(growable: false);
  }
}
