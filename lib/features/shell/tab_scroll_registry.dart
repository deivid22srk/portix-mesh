import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

// ============================================================================
// Registro de scroll por aba.
//
// Duas garantias de uma vez:
//  1. estado preservado — cada aba tem o seu controlador, então a posição de
//      rolagem sobrevive à troca de aba (o IndexedStack mantém a árvore viva);
//  2. re-toque na aba ativa volta ao topo, sem a casca precisar conhecer a
//      tela: ela pergunta o controlador pelo destino.
// ============================================================================

/// Abas principais, na mesma ordem dos destinos do [MainShell].
enum AppTab { home, explore, news, hub, menu }

/// Guarda um [ScrollController] por aba.
class TabScrollRegistry {
  final Map<AppTab, ScrollController> _controllers =
      <AppTab, ScrollController>{};

  /// Controlador da aba (criado na primeira chamada).
  ScrollController controllerFor(AppTab tab) =>
      _controllers.putIfAbsent(tab, ScrollController.new);

  /// Volta a aba ao topo. Sem cliente (aba nunca montada) não faz nada.
  void toTop(AppTab tab, {Duration duration = AppMotion.base}) {
    final ScrollController? controller = _controllers[tab];
    if (controller == null || !controller.hasClients) {
      return;
    }
    if (controller.offset <= 0) {
      return;
    }
    controller.animateTo(0, duration: duration, curve: AppMotion.out);
  }

  void dispose() {
    for (final ScrollController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}

final tabScrollRegistryProvider = Provider<TabScrollRegistry>((Ref ref) {
  final TabScrollRegistry registry = TabScrollRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

/// Expõe o registro de scroll às telas das abas.
///
/// A casca publica; a tela raiz de cada aba pega o SEU controlador. Só assim o
/// re-toque na aba ativa tem para onde voltar — a casca não conhece os
/// scroll views de dentro das telas e as telas não conhecem a casca.
class TabScrollScope extends InheritedWidget {
  const TabScrollScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final TabScrollRegistry registry;

  /// Controlador estável da aba (null fora da casca, ex.: em testes isolados).
  static ScrollController? controllerOf(BuildContext context, AppTab tab) =>
      context
          .dependOnInheritedWidgetOfExactType<TabScrollScope>()
          ?.registry
          .controllerFor(tab);

  @override
  bool updateShouldNotify(TabScrollScope oldWidget) =>
      oldWidget.registry != registry;
}
