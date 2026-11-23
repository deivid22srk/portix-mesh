import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portix/core/providers.dart';
import 'package:portix/features/search/search_controller.dart';
import 'package:portix/shared/widgets/primitives.dart';

import 'ui_test_helpers.dart';

// ============================================================================
// Evidências da iteração 3: destrutivos com confirmação (AppConfirm no
// sistema de vidro) e undo real do histórico de buscas.
// ============================================================================

void main() {
  group('RecentSearchesNotifier.restoreAll', () {
    testWidgets('undo do limpar histórico restaura as buscas', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'search.recent': <String>['mario', 'zelda'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(recentSearchesProvider), <String>[
        'mario',
        'zelda',
      ]);
      container.read(recentSearchesProvider.notifier).clear();
      expect(container.read(recentSearchesProvider), isEmpty);
      container.read(recentSearchesProvider.notifier).restoreAll(<String>[
        'mario',
        'zelda',
      ]);
      expect(container.read(recentSearchesProvider), <String>[
        'mario',
        'zelda',
      ]);
      // Persistido para a próxima sessão.
      expect(prefs.getStringList('search.recent'), <String>['mario', 'zelda']);
    });
  });

  group('showAppConfirm', () {
    testWidgets('confirmar devolve true com o sistema de vidro', (
      WidgetTester tester,
    ) async {
      bool? result;
      await pumpUi(
        tester,
        child: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showAppConfirm(
                context,
                title: 'Sair',
                message: 'Sair da sua conta neste dispositivo?',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Sair'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancelar devolve false', (WidgetTester tester) async {
      bool? result;
      await pumpUi(
        tester,
        child: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showAppConfirm(
                context,
                title: 'Limpar',
                message: 'Apagar tudo?',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
