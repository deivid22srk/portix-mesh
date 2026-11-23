import 'package:material_ui/material_ui.dart';

// ============================================================================
// Chrome de navegação — modo (barra inferior / rail / sidebar) decidido pela
// largura da janela e publicado para as telas reservarem o espaço exato no fim
// do próprio scroll. Nenhuma tela adivinha altura de barra: ela pergunta.
// ============================================================================

/// Forma da navegação principal na largura atual.
enum AppNavMode {
  /// Telefone (<768): barra de vidro flutuante no rodapé.
  bottom,

  /// Tablet (768–1199): rail vertical com ícone + rótulo empilhados.
  rail,

  /// Desktop (≥1200): sidebar recolhível (marca, destinos, conta).
  sidebar,
}

/// Publica os insets da chrome para a árvore de telas.
///
/// A casca é a única fonte de verdade: quando a navegação está na lateral o
/// conteúdo não precisa da reserva de 140 da barra inferior — só da folga da
/// snackbar. Assim nenhuma tela cobre conteúdo nem sobra espaço morto.
class AppChromeScope extends InheritedWidget {
  const AppChromeScope({
    super.key,
    required this.navMode,
    required this.bottomPadding,
    required super.child,
  });

  final AppNavMode navMode;

  /// Espaço que o fim de qualquer lista deve reservar.
  final double bottomPadding;

  static AppChromeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppChromeScope>();

  @override
  bool updateShouldNotify(AppChromeScope oldWidget) =>
      navMode != oldWidget.navMode || bottomPadding != oldWidget.bottomPadding;
}
