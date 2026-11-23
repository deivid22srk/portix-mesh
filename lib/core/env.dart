import 'package:flutter/widgets.dart';

import '../app/app_strings.dart';

/// Versão exibida/comparada com os avisos de atualização.
const String kAppVersion = '1.3.0';

/// Landing page pública do PORTIX (GitHub Pages), com os APKs nas releases.
const String kLandingUrl = 'https://deivid22srk.github.io/portix-landing/';
const String kReleasesUrl =
    'https://github.com/deivid22srk/portix-landing/releases/latest';

/// Documentos legais publicados na landing page.
const String kTermsUrl = '${kLandingUrl}termos.html';
const String kPrivacyUrl = '${kLandingUrl}privacidade.html';

class Env {
  const Env._();

  /// Sem backend central: o app não depende de nenhuma configuração de build
  /// obrigatória. A malha usa `--dart-define=PORTIX_RELAYS` (opcional) e aceita
  /// relays adicionados em runtime.
  static const bool isConfigured = true;
}

enum FailureKind {
  config,
  network,
  server,
  auth,
  notFound,
  rateLimited,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, {this.detail, this.code});

  final FailureKind kind;
  final String? detail;

  /// Código estável da origem (PostgREST: `PGRST202` = função ausente, 429 =
  /// limite de requisições). Permite fallbacks precisos na camada de dados.
  final String? code;

  @override
  String toString() =>
      'AppFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}

String describeFailure(Object? error, L10n l10n) {
  if (error is AppFailure) {
    switch (error.kind) {
      case FailureKind.config:
        return l10n.configBody;
      case FailureKind.network:
        return l10n.errorNetwork;
      case FailureKind.server:
        return l10n.errorServer;
      case FailureKind.auth:
        return l10n.errorAuth;
      case FailureKind.notFound:
        return l10n.errorNotFound;
      case FailureKind.rateLimited:
        return l10n.errorRateLimited;
      case FailureKind.unknown:
        return l10n.errorGeneric;
    }
  }
  return l10n.errorGeneric;
}

extension FailureContext on BuildContext {
  String failureText(Object? error) => describeFailure(error, l10n);
}
