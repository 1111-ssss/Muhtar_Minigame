import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/dice.dart';
import 'package:muhtar_minigame/domain/equipment.dart';
import 'package:muhtar_minigame/domain/game_content.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game/world/enemy_entity.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/battle_engine.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/battle/battle_confirm_overlay.dart';
import 'package:muhtar_minigame/ui/battle/battle_overlay.dart';
import 'package:muhtar_minigame/ui/battle/pre_battle_overlay.dart';

class _MinRandom implements Random {
  const _MinRandom();

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

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
      MuhtarGame.overlayPreBattle,
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

  BattleEngine buildBattle({
    int rootCells = 0,
    int enemyAttack = 3,
    int enemyAttackHits = 1,
    List<Dice>? dice,
    List<EquipmentSlot>? equipment,
    int playerDiceCount = 1,
  }) {
    final engine = BattleEngine(
      player: Fighter(
        name: 'Герой',
        maxHp: 30,
        dice: dice ?? [GameContent.starterDice],
        isPlayer: true,
        attackPhrases: const ['Фраза героя один', 'Фраза героя два'],
      ),
      enemy: Fighter(
        name: 'Гопник',
        maxHp: 30,
        attackFaces: [enemyAttack],
        attackHits: enemyAttackHits,
        attackPhrases: const ['Фраза врага один', 'Фраза врага два'],
        rootCells: rootCells,
        equipment: equipment ?? const [],
        appearance: 'gopnik',
      ),
      playerDiceCount: playerDiceCount,
      random: rootCells == 0 ? null : Random(4),
    );
    game.battle = engine;
    return engine;
  }

  Future<void> pumpBattle(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BattleOverlay(game))),
    );
    // startTurn + первый кадр ввода фраз.
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() {
    gameState = GameState();
    saveDir = Directory.systemTemp.createTempSync('muhtar_test');
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
      saveDirectory: saveDir.path,
    );
    registerStubOverlays();
  });

  tearDown(() {
    saveDir.deleteSync(recursive: true);
  });

  testWidgets('реплики бойцов остаются на экране во время розыгрыша хода', (
    tester,
  ) async {
    final battle = buildBattle();
    await pumpBattle(tester);
    // Печатная машинка успевает набрать обе реплики целиком.
    await tester.pump(const Duration(milliseconds: 800));
    final enemyPhraseBefore = battle.enemy.attackPhrase;
    final playerPhraseBefore = battle.player.attackPhrase;
    expect(enemyPhraseBefore, isNotEmpty);
    expect(playerPhraseBefore, isNotEmpty);

    // Реплика рисуется дважды: невидимый заполнитель layout + печатная машинка.
    expect(find.text(enemyPhraseBefore), findsNWidgets(2));
    expect(find.text(playerPhraseBefore), findsNWidgets(2));

    // Кость на доске гарантирует реальные события атаки в розыгрыше.
    expect(battle.placeDie(0, 4), isTrue);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('end-turn')));
    // Середина розыгрыша: удары ещё идут, но реплики уже должны висеть.
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text(enemyPhraseBefore),
      findsNWidgets(2),
      reason: 'реплика врага не должна пропадать во время атаки',
    );
    expect(
      find.text(playerPhraseBefore),
      findsNWidgets(2),
      reason: 'реплика героя не должна пропадать во время атаки',
    );

    await tester.pump(const Duration(seconds: 4));
    expect(battle.round, 2, reason: 'ход должен разыграться до конца');
  });

  testWidgets('атака игрока показывается над врагом, не над игроком', (
    tester,
  ) async {
    final battle = buildBattle(enemyAttack: 2, enemyAttackHits: 3);
    await pumpBattle(tester);

    expect(find.byKey(const ValueKey('attack')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hero-panel')),
        matching: find.byKey(const ValueKey('attack')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('enemy-panel')),
        matching: find.byKey(const ValueKey('attack')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hero-panel')),
        matching: find.byKey(const ValueKey('incoming')),
      ),
      findsNothing,
    );
    expect(find.text('2 x3'), findsOneWidget);
    expect(battle.previewFor(battle.player).incomingHits, 3);
  });

  testWidgets('способность врага открывает подсказку по нажатию', (
    tester,
  ) async {
    buildBattle(equipment: GameContent.gopnik.equipment);
    await pumpBattle(tester);

    final badge = find.byKey(const ValueKey('enemy-ability-gopnik_push'));
    expect(badge, findsOneWidget);
    await tester.tap(badge);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Толчок'), findsOneWidget);
    expect(find.textContaining('Обычная'), findsOneWidget);
    expect(
      find.textContaining('Резко толкает героя и наносит один удар.'),
      findsOneWidget,
    );
  });

  testWidgets('недоступная после расхода энергии кость затемняет только себя', (
    tester,
  ) async {
    final battle = buildBattle(
      playerDiceCount: 3,
      dice: [
        GameContent.starterDice,
        GameContent.emberDice,
        GameContent.guardianDice,
      ],
    );
    await pumpBattle(tester);

    expect(battle.placeDie(0, 0), isTrue);
    expect(battle.placeDie(1, 1), isTrue);
    await tester.pump();

    expect(battle.energy, 0);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('battle-hotbar')),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('battle-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-energy')), findsOneWidget);
  });

  testWidgets('кость можно перетащить с доски обратно в хотбар', (
    tester,
  ) async {
    final battle = buildBattle();
    await pumpBattle(tester);

    expect(battle.placeDie(0, 4), isTrue);
    await tester.pump();

    final boardCenter = tester.getCenter(
      find.byKey(const ValueKey('board-cell-4')),
    );
    final hotbarCenter = tester.getCenter(
      find.byKey(const ValueKey('battle-hotbar')),
    );
    await tester.dragFrom(boardCenter, hotbarCenter - boardCenter);
    await tester.pump();

    expect(battle.board[4], isNull);
    expect(battle.hotbar.whereType<RolledDie>(), hasLength(1));
  });

  testWidgets('после победы Enter закрывает окно боя', (tester) async {
    final battle = buildBattle();
    await pumpBattle(tester);

    // Готовим мгновенную победу: кость на доске добивает врага с 1 HP.
    battle.enemy.hp = 1;
    expect(battle.placeDie(0, 4), isTrue);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('end-turn')));
    await tester.pump(const Duration(seconds: 4));
    expect(battle.isOver, isTrue);
    expect(find.text('Победа!'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Как в игре: Flame доставляет клавиши через onKeyEvent у самой игры,
    // а бой в этот момент блокирует ввод (оверлей активен).
    game.overlays.add(MuhtarGame.overlayBattle);
    var handled = KeyEventResult.ignored;
    await tester.runAsync(() async {
      handled = game.onKeyEvent(
        KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.enter},
      );
      // endBattle асинхронно пишет сейв — даём реальному IO завершиться.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(handled, KeyEventResult.handled);
    expect(game.battle, isNull, reason: 'Enter должен закрывать бой');
  });

  testWidgets('заблокированные клетки имеют замок, подпись и обновляются', (
    tester,
  ) async {
    final battle = buildBattle(rootCells: 3, enemyAttack: 0);
    await pumpBattle(tester);

    expect(battle.rootedCells, isEmpty);
    battle.prepareEndTurn();
    await tester.pump();
    final firstRoundRoots = Set<int>.of(battle.rootedCells);
    expect(find.byKey(const ValueKey('rooted-legend')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
    expect(find.text('КОРНИ'), findsNWidgets(firstRoundRoots.length));

    battle.endTurn();
    await tester.pump();
    final releasedCell = firstRoundRoots.first;

    expect(releasedCell, greaterThanOrEqualTo(0));
    final releasedCellFinder = find.byKey(ValueKey('board-cell-$releasedCell'));
    expect(
      find.descendant(of: releasedCellFinder, matching: find.text('КОРНИ')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: releasedCellFinder,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
    expect(find.text('КОРНИ'), findsNothing);
  });

  testWidgets('корни появляются на end round и отменяют занятую клетку', (
    tester,
  ) async {
    final battle = buildBattle(rootCells: 9, enemyAttack: 0);
    await pumpBattle(tester);
    expect(battle.placeDie(0, 4), isTrue);

    await tester.tap(find.byKey(const ValueKey('end-turn')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(battle.rootedCells, hasLength(9));
    expect(battle.cancelledCells, contains(4));
    expect(find.byKey(const ValueKey('cancelled-die-4')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(battle.round, 2);
    expect(battle.lastEnemyDamage, 0);
  });

  testWidgets(
    'усиленное значение не показывает уровень и не переполняет клетку',
    (tester) async {
      final battle = BattleEngine(
        player: Fighter(
          name: 'Герой',
          maxHp: 30,
          dice: const [
            Dice(
              id: 'upgrade-ui',
              name: 'Улучшение',
              baseFaces: [2],
              ability: DiceAbility.upgrade,
            ),
            Dice(
              id: 'doctor-ui',
              name: 'Доктор',
              baseFaces: [1, 2, 3, 4, 5, 6],
              level: 3,
              ability: DiceAbility.doctor,
            ),
          ],
          isPlayer: true,
        ),
        enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
        playerDiceCount: 2,
        random: const _MinRandom(),
      );
      game.battle = battle;
      await pumpBattle(tester);

      final upgradeIndex = battle.hotbar.indexWhere(
        (die) => die?.dice.ability == DiceAbility.upgrade,
      );
      final doctorIndex = battle.hotbar.indexWhere(
        (die) => die?.dice.ability == DiceAbility.doctor,
      );
      expect(battle.placeDie(upgradeIndex, 4), isTrue);
      expect(battle.placeDie(doctorIndex, 1), isTrue);
      await tester.pump();

      expect(find.text('знач. 1 → 2'), findsOneWidget);
      expect(find.textContaining('ур.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('подтверждение боя срабатывает с пробела', (tester) async {
    game.overlays.add(MuhtarGame.overlayBattleConfirm);
    game.setPendingBattleEnemyForTest(
      EnemyEntity(
        enemyId: 'gopnik',
        col: 1,
        row: 1,
        label: 'Гопник',
        spawnKey: 'k',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BattleConfirmOverlay(game))),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(game.pendingBattleEnemy, isNull);
    expect(game.battle, isNotNull, reason: 'пробел должен начинать бой');
  });

  test('подтверждение Виктора открывает заставку и откладывает бой', () {
    final enemy = EnemyEntity(
      enemyId: 'viktor_korneplod',
      col: 1,
      row: 1,
      label: 'Виктор Корнеплод',
      spawnKey: 'viktor',
    );

    game.world_.onBattleStart(enemy);

    expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isTrue);
    expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);
    game.confirmBattle();
    expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isTrue);
    expect(game.battle, isNull);

    game.confirmBattle();
    final startedBattle = game.battle;
    expect(startedBattle, isNotNull);
    expect(
      startedBattle!.player.appearance,
      gameState.selectedSkin.portraitKey,
    );
    expect(
      startedBattle.enemy.rootCells,
      GameContent.viktorKorneplod.rootCells,
    );

    // Повторный callback заставки не должен создать второй engine.
    game.confirmBattle();
    expect(identical(game.battle, startedBattle), isTrue);
  });

  testWidgets('пропуск заставки Виктора начинает бой один раз', (tester) async {
    final enemy = EnemyEntity(
      enemyId: 'viktor_korneplod',
      col: 1,
      row: 1,
      label: 'Виктор Корнеплод',
      spawnKey: 'viktor-skip',
    );
    game.world_.onBattleStart(enemy);
    expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isTrue);
    game.confirmBattle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreBattleOverlay(
            game,
            onContinue: game.confirmBattle,
            onSkip: game.confirmBattle,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pre-battle-skip')));
    await tester.pump();

    final startedBattle = game.battle;
    expect(startedBattle, isNotNull);
    game.confirmBattle();
    expect(identical(game.battle, startedBattle), isTrue);
  });

  test('отмена обычного подтверждения не создаёт BattleEngine', () {
    final enemy = EnemyEntity(
      enemyId: 'gopnik',
      col: 1,
      row: 1,
      label: 'Гопник',
      spawnKey: 'gopnik-cancel',
    );
    game.world_.onBattleStart(enemy);

    expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isTrue);
    game.cancelBattle();

    expect(game.pendingBattleEnemy, isNull);
    expect(game.battle, isNull);
    expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isFalse);
  });

  test('отступление сохраняет оставшийся HP и записывает его в сейв', () async {
    gameState.setPlayerHp(20);
    final battle = BattleEngine(
      player: Fighter(
        name: 'Герой',
        maxHp: gameState.playerMaxHp,
        initialHp: gameState.playerHp,
        dice: [GameContent.starterDice],
        isPlayer: true,
      ),
      enemy: Fighter(name: 'Гопник', maxHp: 30, attackFaces: const [3]),
    );
    game.battle = battle;
    battle.player.hp = 13;

    game.retreatBattle();
    // Явно дожидаемся очереди записи после unawaited-сохранения в игре.
    await game.saveProgress();

    expect(gameState.playerHp, 13);
    expect(battle.player.hp, 0, reason: 'временный боец должен завершиться');
    expect(game.battle, isNull);

    final loaded = GameState();
    expect(await loaded.load(saveDir.path), isTrue);
    expect(loaded.playerHp, 13);
  });
}
