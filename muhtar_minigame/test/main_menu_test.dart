import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/ui/main_menu.dart';

void main() {
  testWidgets('shows saved progress and continues the game', (tester) async {
    var started = false;
    final state = GameState();
    state.addCoins(12);

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: state,
          hasSave: true,
          onStart: () async => started = true,
          onNewGame: () async {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('main-menu-title')), findsOneWidget);
    expect(find.text('Продолжить игру'), findsOneWidget);
    expect(find.text('62'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-menu-start')));
    await tester.pumpAndSettle();

    expect(started, isTrue);
  });

  testWidgets('shows a fresh start when there is no save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: GameState(),
          hasSave: false,
          onStart: () async {},
          onNewGame: () async {},
        ),
      ),
    );

    expect(find.text('Начать игру'), findsOneWidget);
    expect(find.text('Новый забег'), findsOneWidget);
  });
}
