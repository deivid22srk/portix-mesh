import 'package:material_ui/material_ui.dart';

export 'themes.dart';

// ============================================================================
// PORTIX — design tokens ("Aurora")
// Único ponto de verdade para raios, espaçamentos, durações, breakpoints e
// SOMBRAS. Cores de tema ficam em themes.dart (AppColorsTheme); cores de
// CONTEÚDO (scrims sobre mídia, marca) ficam aqui — são invariantes de tema.
// Nenhuma tela deve declarar cor/tamanho solto: use estes tokens.
// ============================================================================

/// Raios de canto.
class AppRadii {
  const AppRadii._();

  static const double sm = 12;
  static const double md = 20;
  static const double lg = 24;
  static const double pill = 999;
  static const Radius sheet = Radius.circular(28);
}

/// Escala de espaçamento e medidas de layout.
class AppSpacing {
  const AppSpacing._();

  /// Sub-grade óptica de 2px: separadores e respiros mínimos (ícone-rótulo
  /// apertado, badges). Use só quando 4px fica visivelmente largo.
  static const double hairline = 2;

  /// Entre ícones/rótulos compactos (chips, contadores).
  static const double xxs = 6;

  static const double xs = 4;
  static const double sm = 8;

  /// Respiro interno de controles compactos (chips, filtros).
  static const double compact = 10;

  static const double md = 12;
  static const double lg = 16;

  /// Respiro vertical de campos de texto (inputs).
  static const double fieldVertical = 14;

  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Margem lateral padrão das telas.
  static const double screen = 16;

  /// Espaço entre cards de grade.
  static const double gridGap = 12;

  /// Botões.
  static const double primaryButtonHeight = 52;
  static const double secondaryButtonHeight = 48;
  // 48px: alvo mínimo de toque WCAG 2.2 AA (2.5.8) — antes 46.
  static const double circleButton = 48;
  static const double searchFab = 68;

  /// Altura base da barra de navegação inferior (cresce com a fonte do
  /// sistema, nunca encolhe: o rótulo nunca é espremido).
  static const double navBarHeight = 68;

  /// Largura do rail vertical (ícone + rótulo empilhados).
  static const double navRailWidth = 96;

  /// Altura de um destino no rail/sidebar (alvo de toque ≥48).
  static const double navItemHeight = 56;

  /// Largura da sidebar expandida (ícone + rótulo em linha).
  static const double navSidebarWidth = 264;

  /// Largura da sidebar recolhida (só ícones).
  static const double navSidebarCollapsedWidth = 88;

  /// Ícone dos destinos de navegação.
  static const double navIconSize = 22;

  /// Sigma do desfoque de vidro (mesmo valor em toda a chrome).
  static const double glassBlur = 20;

  /// Reserva do fim das listas sob a barra inferior: a barra (68) + a folga
  /// acima dela e da snackbar. Vale só no modo `bottom`; nos modos laterais a
  /// casca publica uma reserva menor via [AppChromeScope].
  static const double navContentReserve = 140;

  /// Capa compacta na linha de download (proporção ~3:4 de pôster).
  static const double tileCoverWidth = 58;
  static const double tileCoverHeight = 78;

  /// Altura reservada do estado vazio dentro do viewport do Hub.
  static const double emptyStateViewport = 360;

  /// Folga da snackbar flutuante acima da barra de navegação de vidro.
  static const double snackbarBottomGap = 96;

  /// Diâmetro do spinner pequeno em tiles/botões (estado ocupado).
  static const double inlineSpinner = 18;

  /// Intervalo entre blocos do skeleton de detalhes (área de corpo/mídia).
  static const double skeletonBodyGap = 120;
}

/// Durações e curvas de animação.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration indicator = Duration(milliseconds: 250);

  /// Intervalo do autoplay do carrossel de destaques.
  static const Duration autoplay = Duration(seconds: 5);

  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve out = Curves.easeOutCubic;

  /// Duração efetiva de um movimento: zero quando o sistema pede menos
  /// animação (WCAG 2.3.3 / prefers-reduced-motion).
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Breakpoints responsivos (mobile-first). Grades de capas ganham colunas
/// conforme a largura; acima de `contentMax` o conteúdo é centralizado com
/// teto de largura para não esticar capas 3:4 em monitores.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Telefones estreitos: abaixo disto a chrome lateral encolhe a margem
  /// (16 → 8) para nenhum alvo de toque cair abaixo de 44dp.
  static const double narrow = 360;

  /// Tablet / paisagem baixa.
  static const double tablet = 600;

  /// Desktop estreito.
  static const double desktop = 1024;

  /// Telas largas.
  static const double wide = 1440;

  /// Teto de largura do conteúdo de grades em telas largas.
  static const double contentMax = 1200;

  /// Largura a partir da qual as configurações viram master-detail
  /// (lista à esquerda, conteúdo à direita).
  static const double settingsDetail = 768;

  /// A partir daqui a navegação principal vira rail vertical.
  static const double navRail = 768;

  /// A partir daqui a navegação principal vira sidebar recolhível.
  static const double navSidebar = 1200;

  /// Colunas da grade de capas 3:4 conforme a largura disponível.
  static int coverColumns(double width) {
    if (width >= wide) {
      return 6;
    }
    if (width >= desktop) {
      return 5;
    }
    if (width >= tablet) {
      return 3;
    }
    return 2;
  }
}

/// Cores de CONTEÚDO — aparecem sobre mídia (capa, foto, vídeo) e não mudam
/// com o tema: legibilidade sobre imagem é sempre a mesma.
class AppContentColors {
  const AppContentColors._();

  /// Ausência de cor (scrims que começam transparentes).
  static const Color transparent = Color(0x00000000);

  /// Texto/ícone sobre mídia (capa, notícia, vídeo).
  static const Color onMedia = Color(0xFFFFFFFF);

  /// Scrim preto puro — use com `withValues(alpha: …)` para cada caso.
  static const Color scrim = Color(0xFF000000);

  /// Scrim padrão do rodapé de card (gradiente de título).
  static const Color scrimSoft = Color(0x22000000);

  /// Scrim forte de rodapé de card.
  static const Color scrimStrong = Color(0xD9000000);
}

/// Cores da MARCA (logo PORTIX) — invariantes de tema: a identidade não muda
/// com a aparência escolhida.
class AppBrandColors {
  const AppBrandColors._();

  /// Céu claro do gradiente de brilho do logo.
  static const Color skyLight = Color(0xFFCFFAFE);
}

/// Tamanhos ópticos pontuais de tipografia que fogem da escala do tema.
/// Use apenas quando a escala de texto não cobre o caso (ex.: iniciais de
/// avatar mini). Todo o restante deve vir de `context.texts.*`.
class AppTypography {
  const AppTypography._();

  /// Iniciais do avatar mini do chip de desenvolvedor.
  static const double miniInitials = 9;
}
