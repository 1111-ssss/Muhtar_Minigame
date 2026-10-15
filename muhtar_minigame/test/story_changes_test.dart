import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game/world/enemy_entity.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/battle/pre_battle_overlay.dart';
import 'package:muhtar_minigame/ui/search/search_overlay.dart';

void main() {
  late GameState gameState;
  late MuhtarGame game;

  void registerStubOverlays() {
    for (final name in [
      MuhtarGame.overlayHud,
      MuhtarGame.overlayBattle,
      MuhtarGame.overlayBattleConfirm,
      MuhtarGame.overlayPreBattle,
      MuhtarGame.overlaySearch,
      MuhtarGame.overlayDialog,
      'notifications',
      MuhtarGame.overlayLocationTransition,
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox.shrink());
    }
  }

  setUp(() {
    gameState = GameState();
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
    );
    registerStubOverlays();
  });

  tearDown(() {
    game.audio.dispose();
  });

  test(
    'Виктор сначала требует подтверждение, а отмена не открывает заставку',
    () {
      final enemy = EnemyEntity(
        enemyId: 'viktor_korneplod',
        col: 1,
        row: 1,
        label: 'Виктор Корнеплод',
        spawnKey: 'story-viktor-cancel',
      );

      game.world_.onBattleStart(enemy);

      expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isTrue);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);
      game.cancelBattle();

      expect(game.pendingBattleEnemy, isNull);
      expect(game.battle, isNull);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);
    },
  );

  testWidgets(
    'подтверждение Виктора открывает заставку, пропуск сразу начинает бой',
    (tester) async {
      final enemy = EnemyEntity(
        enemyId: 'viktor_korneplod',
        col: 1,
        row: 1,
        label: 'Виктор Корнеплод',
        spawnKey: 'story-viktor-skip',
      );
      game.world_.onBattleStart(enemy);
      game.confirmBattle();

      expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isFalse);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isTrue);
      expect(game.pendingBattleEnemy, same(enemy));
      expect(game.battle, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreBattleOverlay(game, onContinue: game.confirmBattle),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pre-battle-skip')));
      await tester.pump();

      final startedBattle = game.battle;
      expect(startedBattle, isNotNull);
      expect(game.pendingBattleEnemy, isNull);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);

      game.confirmBattle();
      expect(identical(game.battle, startedBattle), isTrue);
    },
  );

  testWidgets('повторно открытый куст показывает только пустой результат', (
    tester,
  ) async {
    final state = GameState();
    final prop = Locations.forest.props.firstWhere(
      (candidate) => candidate.specialItemId == 'sync_async',
    );
    for (var tap = 0; tap < 10; tap++) {
      state.searchProp(prop.id);
    }

    final loaded = GameState()..fromJson(state.toJson());
    final itemCountBefore = loaded.itemCount('sync_async');
    await tester.pumpWidget(
      MaterialApp(
        home: SearchOverlay(game: loaded, prop: prop, onClose: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Здесь ничего нет...'), findsOneWidget);
    expect(find.text('Тщательный поиск'), findsNothing);
    expect(find.text('Проверить объект'), findsNothing);
    expect(find.text('Находка обнаружена'), findsNothing);
    expect(find.text('Забрать находку'), findsNothing);

    await tester.tap(find.text('Закрыть'));
    expect(loaded.itemCount('sync_async'), itemCountBefore);
  });
}
