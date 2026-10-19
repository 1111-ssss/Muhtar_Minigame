import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/artifact.dart';
import 'package:muhtar_minigame/domain/dice.dart';
import 'package:muhtar_minigame/domain/game_content.dart';
import 'package:muhtar_minigame/ui/upgrade/case_opening_dialog.dart';

void main() {
  testWidgets('dice case can skip the reel and shows the fixed reward', (
    tester,
  ) async {
    final result = GameContent.diceCatalog.first.copyWith(level: 3);
    await tester.pumpWidget(MaterialApp(home: DiceCaseDialog(result: result)));

    expect(find.text('Ящик костей'), findsOneWidget);
    expect(find.text('Открываем…'), findsOneWidget);
    await tester.tap(find.text('Пропустить прокрутку'));
    await tester.pump();

    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('${result.name} · уровень 3'), findsOneWidget);
  });

  testWidgets('artifact case exposes modifier and artifact choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArtifactCaseDialog(
          choices: const [Artifact.fieldKit, Artifact.emberHeart],
        ),
      ),
    );

    expect(find.text('Ящик артефактов'), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-modifier')), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-fieldKit')), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-emberHeart')), findsOneWidget);
    expect(find.text('Походная аптечка'), findsOneWidget);
    expect(find.text('Сердце углей'), findsOneWidget);
  });

  testWidgets('modifier target dialog shows available dice and empty state', (
    tester,
  ) async {
    const dice = [
      Dice(id: 'plain', name: 'Клинок', baseFaces: [1, 2, 3, 4, 5, 6]),
      Dice(
        id: 'heavy',
        name: 'Тяжёлая кость',
        baseFaces: [1, 2, 3, 4, 5, 6],
        modifier: DiceModifier.heavy,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiceModifierTargetDialog(
          dice: dice,
          modifier: DiceModifier.glass,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('apply-modifier-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('apply-modifier-1')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: DiceModifierTargetDialog(
          dice: [
            Dice(
              id: 'glass',
              name: 'Стеклянная кость',
              baseFaces: [1, 2, 3, 4, 5, 6],
              modifier: DiceModifier.glass,
            ),
          ],
          modifier: DiceModifier.glass,
        ),
      ),
    );

    expect(find.textContaining('Свободных костей нет'), findsOneWidget);
  });
}
