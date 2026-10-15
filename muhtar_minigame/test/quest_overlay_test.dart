import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/artifact.dart';
import 'package:muhtar_minigame/domain/quest.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/quest/quest_overlay.dart';

void main() {
  late GameState gameState;
  late MuhtarGame game;
  late Directory saveDir;

  /// MuhtarGame вне GameWidget не знает билдеры оверлеев — регистрируем заглушки.
  void registerStubOverlays() {
    for (final name in [
      MuhtarGame.overlayHud,
      MuhtarGame.overlayBattle,
      MuhtarGame.overlayBattleConfirm,
      MuhtarGame.overlayQuests,
      MuhtarGame.overlayDialog,
      MuhtarGame.overlayUpgrade,
      MuhtarGame.overlayInventory,
      MuhtarGame.overlaySettings,
      'notifications',
      MuhtarGame.overlayLocationTransition,
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox.shrink());
    }
  }

  Future<void> pumpQuestOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: QuestOverlay(game))),
    );
    // Завершаем входную анимацию AnimatedOverlay и не оставляем тикер.
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<GameState> saveAndLoad(WidgetTester tester) async {
    late GameState loaded;
    await tester.runAsync(() async {
      await game.saveProgress();
      loaded = GameState();
      expect(await loaded.load(saveDir.path), isTrue);
    });
    return loaded;
  }

  setUp(() {
    gameState = GameState();
    saveDir = Directory.systemTemp.createTempSync('muhtar-quest-overlay-');
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
      saveDirectory: saveDir.path,
    );
    registerStubOverlays();
  });

  tearDown(() async {
    // Все проверки сохранения выполняются внутри runAsync; синхронное
    // удаление не оставляет dart:io Future в fake-async зоне widget-теста.
    saveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'журнал показывает active и completed, а награда выдаётся только по claim',
    (tester) async {
      expect(gameState.activateQuest('q_bridge'), isTrue);
      expect(gameState.activateQuest('q_shaurmek'), isTrue);
      gameState.progressQuests(enemyId: 'shaurmek');

      // Достижение цели лишь переводит квест в completed: награда ещё не
      // должна попасть в состояние игрока.
      expect(gameState.quest('q_shaurmek')!.state, QuestState.completed);
      expect(gameState.coins, 50);
      expect(gameState.xp, 0);
      expect(gameState.caseCount(CaseType.artifact), 0);

      await pumpQuestOverlay(tester);

      expect(find.byKey(const ValueKey('quest-q_bridge')), findsOneWidget);
      expect(find.byKey(const ValueKey('quest-q_shaurmek')), findsOneWidget);
      expect(find.byKey(const ValueKey('claim-q_bridge')), findsNothing);
      expect(find.byKey(const ValueKey('claim-q_shaurmek')), findsOneWidget);
      expect(find.text('Получить награду'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('claim-q_shaurmek')),
      );
      await tester.tap(find.byKey(const ValueKey('claim-q_shaurmek')));
      await tester.pump();

      expect(gameState.quest('q_shaurmek')!.state, QuestState.claimed);
      expect(gameState.coins, 100);
      expect(gameState.xp, 24);
      expect(gameState.caseCount(CaseType.artifact), 1);
      expect(find.byKey(const ValueKey('quest-q_shaurmek')), findsNothing);
      expect(find.byKey(const ValueKey('claim-q_shaurmek')), findsNothing);
      expect(find.byKey(const ValueKey('quest-q_bridge')), findsOneWidget);

      final loaded = await saveAndLoad(tester);
      expect(loaded.quest('q_shaurmek')!.state, QuestState.claimed);
      expect(loaded.quest('q_bridge')!.state, QuestState.active);
      expect(loaded.coins, 100);
      expect(loaded.xp, 24);
      expect(loaded.caseCount(CaseType.artifact), 1);

      // Повторный claim после загрузки не создаёт дубликат награды.
      expect(loaded.claimQuest('q_shaurmek'), isFalse);
      expect(loaded.coins, 100);
      expect(loaded.xp, 24);
      expect(loaded.caseCount(CaseType.artifact), 1);
    },
  );
}
