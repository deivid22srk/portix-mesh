import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:portix/models/game.dart';
import 'package:portix/shared/widgets/app_mark.dart';
import 'package:portix/shared/widgets/game_media.dart';
import 'package:portix/shared/widgets/primitives.dart';
import 'package:portix/shared/widgets/states.dart';

void main() {
  testWidgets('GameCard mostra capa procedural e título', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: GameCard(
                game: Game(
                  id: 'game-1',
                  slug: 'super-mario-64',
                  title: 'Super Mario 64',
                  year: 1996,
                  genre: 'Platformer',
                  platforms: <String>['Nintendo 64'],
                  portCount: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Super Mario 64'), findsOneWidget);
    expect(find.text('SM'), findsOneWidget);
  });

  testWidgets('StatBadge mostra nota em porcentagem', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: StatBadge(rating: 4.5, downloads: 1200)),
        ),
      ),
    );

    expect(find.text('90%'), findsOneWidget);
    expect(find.text('1,2k'), findsOneWidget);
  });

  testWidgets('PrimaryButton dispara a ação', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: PrimaryButton(
              label: 'Instalar',
              expand: false,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Instalar'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('EmptyState dispara a ação principal', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nada por aqui',
            body: 'Tente outra busca.',
            actionLabel: 'Explorar',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Nada por aqui'), findsOneWidget);
    await tester.tap(find.text('Explorar'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('PortixMark desenha sem erros', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PortixMark(size: 120))),
      ),
    );

    expect(find.byType(PortixMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
