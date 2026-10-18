import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/artifact.dart';
import 'package:muhtar_minigame/domain/dice.dart';
import 'package:muhtar_minigame/game_logic/battle_engine.dart';

class _MaxRandom implements Random {
  const _MaxRandom();

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999999;

  @override
  int nextInt(int max) => max - 1;
}

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
  Fighter player({List<Dice>? dice, int hp = 30}) => Fighter(
    name: 'Игрок',
    maxHp: 30,
    initialHp: hp,
    dice:
        dice ??
        const [
          Dice(
            id: 'warrior',
            name: 'Удар',
            baseFaces: [1, 2, 3, 4, 5, 6],
            ability: DiceAbility.warrior,
          ),
        ],
    isPlayer: true,
  );

  Fighter enemy({
    bool first = false,
    int burnDamage = 0,
    int baseHealing = 0,
    double healingChance = 0,
    int hp = 30,
  }) => Fighter(
    name: 'Враг',
    maxHp: 30,
    initialHp: hp,
    attackFaces: const [4],
    actsFirst: first,
    burnDamage: burnDamage,
    baseHealing: baseHealing,
    healingChance: healingChance,
    baseShield: 0,
    appearance: 'goblin',
  );

  test('новый бросок выбирает случайную грань от 1 до уровня', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'd', name: 'd', baseFaces: [1], level: 4),
        ],
      ),
      enemy: enemy(),
      playerDiceCount: 1,
      random: Random(1),
    )..startTurn();

    expect(battle.hotbar.single!.value, inInclusiveRange(1, 4));
  });

  test('хотбар не содержит два броска из одного источника', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'shared', name: 'Общий источник', baseFaces: [1]),
          Dice(id: 'shared', name: 'Общий источник', baseFaces: [1]),
          Dice(id: 'unique', name: 'Уникальный источник', baseFaces: [1]),
        ],
      ),
      enemy: enemy(),
      playerDiceCount: 3,
      random: const _MaxRandom(),
    )..startTurn();

    final sourceIds = [
      for (final die in battle.hotbar)
        if (die != null) die.dice.id,
    ];
    expect(sourceIds, hasLength(2));
    expect(sourceIds.toSet(), hasLength(sourceIds.length));
  });

  test('лечение врага появляется в preview в конце раунда', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(baseHealing: 5, healingChance: 1, hp: 25),
      playerDiceCount: 1,
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.previewFor(battle.enemy).healing, 5);
  });

  test('боевой движок не принимает больше трёх слотов хотбара', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(),
      playerDiceCount: 6,
    );

    expect(battle.hotbar, hasLength(3));
    expect(battle.hotbarSize, 3);
  });

  test('начало боя безопасно заполняет хотбар при пустых слотах', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'one', name: 'Одна', baseFaces: [1]),
          Dice(id: 'two', name: 'Две', baseFaces: [1]),
          Dice(id: 'three', name: 'Три', baseFaces: [1]),
        ],
      ),
      enemy: enemy(),
      playerDiceCount: 3,
    )..startTurn();

    expect(battle.hotbar, hasLength(3));
    expect(battle.hotbar.whereType<RolledDie>(), hasLength(3));
  });

  test('энергия ограничивает размещение двумя костями и сбрасывается до двух', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'a', name: 'Атака 1', baseFaces: [1]),
          Dice(id: 'b', name: 'Атака 2', baseFaces: [1]),
          Dice(id: 'c', name: 'Атака 3', baseFaces: [1]),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      playerDiceCount: 3,
    )..startTurn();

    expect(battle.energy, BattleEngine.maxEnergy);
    expect(battle.placeDie(0, 0), isTrue);
    expect(battle.energy, 1);
    expect(battle.placeDie(1, 1), isTrue);
    expect(battle.energy, 0);
    expect(battle.placeDie(2, 2), isFalse);

    battle.endTurn();
    expect(battle.energy, BattleEngine.maxEnergy);
  });

  test('Легкий не тратит энергию, Тяжелый нельзя снять и он теряет уровни', () {
    final lightBattle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'a', name: 'Атака 1', baseFaces: [1]),
          Dice(
            id: 'light',
            name: 'Легкая атака',
            baseFaces: [1],
            modifier: DiceModifier.light,
          ),
          Dice(id: 'c', name: 'Атака 3', baseFaces: [1]),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      playerDiceCount: 3,
      random: const _MaxRandom(),
    )..startTurn();
    expect(lightBattle.placeDie(0, 0), isTrue);
    expect(lightBattle.placeDie(1, 1), isTrue);
    expect(lightBattle.energy, 1);
    expect(lightBattle.placeDie(2, 2), isTrue);
    expect(lightBattle.energy, 0);

    final heavy = Dice(
      id: 'heavy',
      name: 'Тяжелая атака',
      baseFaces: [2],
      level: 2,
      modifier: DiceModifier.heavy,
    );
    final heavyBattle = BattleEngine(
      player: player(dice: [heavy]),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
    )..startTurn();
    expect(heavyBattle.placeDie(0, 4), isTrue);
    expect(heavyBattle.removeDie(4), isFalse);
    expect(heavyBattle.moveDie(4, 1), isFalse);
    heavyBattle.endTurn();
    expect(heavyBattle.board[4]!.dice.level, 1);
    expect(heavyBattle.player.dice.single.level, 1);
    heavyBattle.endTurn();
    expect(heavyBattle.board[4], isNull);
    expect(heavyBattle.player.dice, isEmpty);
  });

  test('Стекло применяет эффект с учетом клетки и больше не выпадает', () {
    const glassUpgrade = Dice(
      id: 'glass-upgrade',
      name: 'Стеклянное улучшение',
      baseFaces: [2],
      ability: DiceAbility.upgrade,
      modifier: DiceModifier.glass,
    );
    const attack = Dice(
      id: 'attack',
      name: 'Атака',
      baseFaces: [3],
      ability: DiceAbility.warrior,
    );
    final battle = BattleEngine(
      player: player(dice: const [glassUpgrade, attack]),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      playerDiceCount: 2,
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.placeDie(0, 1), isTrue);
    expect(battle.placeDie(1, 4), isTrue);
    expect(battle.board[4], isNull);
    expect(battle.player.dice, hasLength(1));
    expect(battle.playerIntent.attack, 2);
  });

  test('кость лечения выпадает только один раз за бой', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(
            id: 'doctor',
            name: 'Доктор',
            baseFaces: [1],
            ability: DiceAbility.doctor,
          ),
          Dice(id: 'warrior', name: 'Атака', baseFaces: [1]),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      playerDiceCount: 2,
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.healingDieDrawn, isTrue);
    expect(
      battle.hotbar.where((die) => die?.dice.ability == DiceAbility.doctor),
      hasLength(1),
    );
    battle.placeDie(0, 0);
    battle.placeDie(1, 1);
    battle.endTurn();

    expect(
      battle.hotbar.where((die) => die?.dice.ability == DiceAbility.doctor),
      isEmpty,
    );
    expect(
      battle.player.dice.where((die) => die.ability == DiceAbility.doctor),
      hasLength(1),
    );
  });

  test('враг выбирает только одно действие за ход', () {
    BattleEngine build({
      required Random random,
      int baseShield = 0,
      double shieldChance = 1,
      int baseHealing = 5,
    }) =>
        BattleEngine(
          player: player(dice: const []),
          enemy: Fighter(
            name: 'Враг',
            maxHp: 30,
            attackFaces: const [4],
            baseShield: baseShield,
            shieldChance: shieldChance,
            baseHealing: baseHealing,
            healingChance: 1,
          ),
          random: random,
        )..startTurn();

    final attack = build(random: const _MinRandom()).enemyIntent;
    expect(
      [attack.attack > 0, attack.shield > 0, attack.heal > 0]
          .where((action) => action)
          .length,
      1,
    );

    final shield = build(
      random: const _MaxRandom(),
      baseShield: 2,
      shieldChance: 1,
      baseHealing: 0,
    ).enemyIntent;
    expect(shield.attack, 0);
    expect(shield.shield, 2);
    expect(shield.heal, 0);

    final heal = build(random: const _MaxRandom()).enemyIntent;
    expect(heal.attack, 0);
    expect(heal.shield, 0);
    expect(heal.heal, 5);

    final lessFrequentShield = build(
      random: const _MaxRandom(),
      baseShield: 2,
      shieldChance: .35,
      baseHealing: 0,
    ).enemyIntent;
    expect(lessFrequentShield.attack, 4);
    expect(lessFrequentShield.shield, 0);
  });

  test('щит врага не превышает восемь единиц', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Бронированный враг',
        maxHp: 30,
        attackFaces: const [4],
        baseShield: 20,
        shieldChance: 1,
      ),
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.enemyIntent.shield, maxEnemyShield);
    expect(battle.previewFor(battle.enemy).availableShield, maxEnemyShield);
    battle.endTurn();
    expect(battle.enemy.shield, maxEnemyShield);

    final nearlyFull = BattleEngine(
      player: player(dice: const []),
      enemy: Fighter(
        name: 'Почти полный щит',
        maxHp: 30,
        initialShield: maxEnemyShield - 1,
        attackFaces: const [0],
        baseShield: 20,
        shieldChance: 1,
      ),
      random: const _MaxRandom(),
    )..startTurn();

    expect(nearlyFull.enemyIntent.shield, 1);
    nearlyFull.endTurn();
    expect(nearlyFull.enemy.shield, maxEnemyShield);
  });

  test('враг получает реплику текущего раунда до атаки', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Шаурмек',
        maxHp: 30,
        attackFaces: const [1],
        attackPhrases: const ['Вай вай вай!', 'Паследни деньга гони'],
      ),
    )..startTurn();

    expect(battle.enemy.attackPhrase, 'Вай вай вай!');
    battle.endTurn();
    expect(battle.enemy.attackPhrase, 'Паследни деньга гони');
  });

  test('доска пустая, установка расходует кубик хотбара', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(),
      playerDiceCount: 1,
    )..startTurn();

    expect(battle.board.every((cell) => cell == null), isTrue);
    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.board[4], isNotNull);
    expect(battle.hotbar[0], isNull);
  });

  test('можно снять кость с доски и вернуть её в свободный слот', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(id: 'a', name: 'Атака', baseFaces: [4]),
          Dice(id: 'b', name: 'Вторая', baseFaces: [2]),
        ],
      ),
      enemy: enemy(),
      playerDiceCount: 2,
    )..startTurn();

    final placed = battle.hotbar[1]!;
    expect(battle.placeDie(1, 4), isTrue);
    expect(battle.energy, 1);
    expect(battle.removeDie(4), isTrue);
    expect(battle.energy, BattleEngine.maxEnergy);
    expect(battle.board[4], isNull);
    expect(battle.hotbar[1], same(placed));
  });

  test(
    'свободный кубик сохраняется, установленный заменяется в новом раунде',
    () {
      final battle = BattleEngine(
        player: player(
          dice: const [
            Dice(id: 'd', name: 'd', baseFaces: [3]),
          ],
        ),
        enemy: enemy(),
        playerDiceCount: 2,
      )..startTurn();
      final untouched = battle.hotbar[1];
      battle.placeDie(0, 0);
      battle.endTurn();

      expect(battle.hotbar[0], isNotNull);
      expect(battle.hotbar[1], same(untouched));
      expect(battle.board.every((cell) => cell == null), isTrue);
    },
  );

  test('реролл меняет свободный кубик и расходует попытку', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(),
      playerDiceCount: 1,
      playerRerollsPerRound: 2,
      random: Random(1),
    )..startTurn();
    expect(battle.rerollsRemaining, 2);
    expect(battle.rerollDie(0), isTrue);
    expect(battle.rerollsRemaining, 1);
  });

  test(
    'куб улучшения усиливает выбранные клетки и сужает зону на уровне 6',
    () {
      const upgrade = Dice(
        id: 'u',
        name: 'Улучшение',
        baseFaces: [2],
        level: 1,
        ability: DiceAbility.upgrade,
      );
      const attack = Dice(
        id: 'a',
        name: 'Атака',
        baseFaces: [3],
        ability: DiceAbility.warrior,
      );
      final battle = BattleEngine(
        player: player(dice: const [upgrade, attack]),
        enemy: enemy(),
        playerDiceCount: 2,
      )..startTurn();
      final upgradeIndex = battle.hotbar.indexWhere(
        (die) => die?.dice.ability == DiceAbility.upgrade,
      );
      final attackIndex = battle.hotbar.indexWhere(
        (die) => die?.dice.ability == DiceAbility.warrior,
      );
      battle.placeDie(upgradeIndex, 4);
      battle.placeDie(attackIndex, 1);
      expect(
        battle.effectiveValueAt(1),
        battle.board[1]!.value + battle.board[4]!.value,
      );
      expect(battle.effectiveLevelAt(1), battle.board[1]!.dice.level);
      expect(
        battle.previewFor(battle.player).outgoingDamage,
        battle.playerIntent.attack,
      );
      expect(BattleEngine.upgradeTargets(4, 1), hasLength(8));
      expect(BattleEngine.upgradeTargets(4, 6), hasLength(1));
    },
  );

  test(
    'upgrade меняет выпавшее значение doctor, а не его постоянный уровень',
    () {
      const upgrade = Dice(
        id: 'upgrade',
        name: 'Улучшение',
        baseFaces: [6],
        ability: DiceAbility.upgrade,
      );
      const doctor = Dice(
        id: 'doctor-3',
        name: 'Доктор',
        baseFaces: [1, 2, 3, 4, 5, 6],
        level: 3,
        ability: DiceAbility.doctor,
      );
      final battle = BattleEngine(
        player: player(hp: 10, dice: const [upgrade, doctor]),
        enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
        random: const _MaxRandom(),
        playerDiceCount: 2,
      )..startTurn();

      // _MaxRandom draws the doctor first and the upgrade second. Cell 4's
      // level-1 zone includes cell 1.
      expect(battle.placeDie(1, 4), isTrue);
      expect(battle.placeDie(0, 1), isTrue);
      expect(battle.board[1]!.dice.level, 3);
      expect(battle.effectiveLevelAt(1), 3);
      expect(battle.playerIntent.heal, 4);

      battle.endTurn();

      expect(battle.player.hp, 14);
    },
  );

  test(
    'несколько костей улучшения складываются на одной ячейке без капа 6',
    () {
      const upgradeOne = Dice(
        id: 'upgrade-one',
        name: 'Улучшение',
        baseFaces: [1, 2, 3, 4, 5, 6],
        ability: DiceAbility.upgrade,
      );
      const upgradeTwo = Dice(
        id: 'upgrade-two',
        name: 'Улучшение',
        baseFaces: [1, 2, 3, 4, 5, 6],
        ability: DiceAbility.upgrade,
        modifier: DiceModifier.light,
      );
      const attack = Dice(
        id: 'attack',
        name: 'Атака',
        baseFaces: [1, 2, 3, 4, 5, 6],
        ability: DiceAbility.warrior,
      );
      final battle = BattleEngine(
        player: player(dice: const [upgradeOne, upgradeTwo, attack]),
        enemy: enemy(),
        playerDiceCount: 3,
        random: const _MaxRandom(),
      )..startTurn();

      final upgradeIndexes = [
        for (var index = 0; index < battle.hotbar.length; index++)
          if (battle.hotbar[index]?.dice.ability == DiceAbility.upgrade) index,
      ];
      final attackIndex = battle.hotbar.indexWhere(
        (die) => die?.dice.ability == DiceAbility.warrior,
      );
      expect(upgradeIndexes, hasLength(2));
      expect(battle.placeDie(attackIndex, 1), isTrue);
      expect(battle.placeDie(upgradeIndexes[0], 4), isTrue);
      expect(battle.placeDie(upgradeIndexes[1], 0), isTrue);

      expect(battle.board[1]!.value, 1);
      expect(battle.effectiveValueAt(1), 3);
      expect(battle.playerIntent.attack, 3);
    },
  );

  test('статы врага показывают его ожидаемую атаку', () {
    final battle = BattleEngine(player: player(), enemy: enemy())..startTurn();
    final preview = battle.previewFor(battle.player);
    expect(preview.incomingDamage, 4);
    expect(preview.blockedDamage, 0);
  });

  test('многоударная атака сохраняет урон за удар и количество попаданий', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Враг',
        maxHp: 30,
        attackFaces: const [2],
        attackHits: 3,
      ),
    )..startTurn();

    final preview = battle.previewFor(battle.player);
    expect(preview.incomingDamage, 6);
    expect(preview.incomingDamagePerHit, 2);
    expect(preview.incomingHits, 3);

    battle.endTurn();
    final attack = battle.lastEvents.firstWhere(
      (event) =>
          event.source == BattleSide.enemy &&
          event.type == BattleEventType.attack,
    );
    expect(attack.amount, 2);
    expect(attack.hits, 3);
    expect(battle.player.hp, 24);
  });

  test(
    'кость doctor использует текущее выпавшее значение, а preview совпадает с фактом',
    () {
      final battle = BattleEngine(
        player: player(
          hp: 10,
          dice: const [
            Dice(
              id: 'doctor-3',
              name: 'Доктор',
              baseFaces: [1, 2, 3, 4, 5, 6],
              level: 3,
              ability: DiceAbility.doctor,
            ),
          ],
        ),
        enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
        random: const _MaxRandom(),
      )..startTurn();

      expect(battle.hotbar.single!.value, 3);
      expect(battle.placeDie(0, 4), isTrue);
      expect(battle.playerIntent.heal, 3);
      expect(battle.previewFor(battle.player).healing, 3);

      battle.endTurn();

      expect(battle.player.hp, 13);
    },
  );

  test('кость doctor уровня 5 учитывает fieldKit и ограничивается max HP', () {
    BattleEngine doctorBattle(int hp) => BattleEngine(
      player: player(
        hp: hp,
        dice: const [
          Dice(
            id: 'doctor-5',
            name: 'Доктор',
            baseFaces: [1, 2, 3, 4, 5, 6],
            level: 5,
            ability: DiceAbility.doctor,
          ),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      artifacts: const {Artifact.fieldKit: 1},
      random: const _MaxRandom(),
    )..startTurn();

    final battle = doctorBattle(10);
    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.playerIntent.heal, 7);
    expect(battle.previewFor(battle.player).healing, 7);

    battle.endTurn();

    expect(battle.player.hp, 17);

    final cappedBattle = doctorBattle(29);
    expect(cappedBattle.placeDie(0, 4), isTrue);
    expect(cappedBattle.playerIntent.heal, 7);
    expect(cappedBattle.previewFor(cappedBattle.player).healing, 1);

    cappedBattle.endTurn();

    expect(cappedBattle.player.hp, 30);
  });

  test('раунд публикует последовательность действий для анимации', () {
    final battle = BattleEngine(
      player: player(hp: 10),
      enemy: enemy(),
      playerDiceCount: 1,
    )..startTurn();
    battle.placeDie(0, 4);
    battle.endTurn();

    expect(
      battle.lastEvents.map((event) => event.type),
      containsAllInOrder(<BattleEventType>[
        BattleEventType.attack,
        BattleEventType.damage,
      ]),
    );
    expect(battle.lastEvents.every((event) => event.amount > 0), isTrue);
  });

  test('враг с инициативой атакует первым, огонь учитывается', () {
    final battle = BattleEngine(
      player: player(hp: 10),
      enemy: enemy(first: true, burnDamage: 3),
    )..startTurn();
    battle.placeDie(0, 4);
    battle.endTurn();

    expect(battle.player.hp, lessThan(10));
    expect(battle.player.burn, 3);
  });

  test('горение Шаурмека не проходит сквозь щит', () {
    final battle = BattleEngine(
      player: Fighter(
        name: 'Игрок',
        maxHp: 30,
        initialHp: 20,
        initialShield: 3,
        dice: const [],
        isPlayer: true,
      ),
      enemy: Fighter(
        name: 'Шаурмек',
        maxHp: 32,
        attackFaces: const [0],
        actsFirst: true,
        burnDamage: 3,
      ),
    )..startTurn();

    battle.endTurn();
    expect(battle.player.burn, 3);
    expect(battle.player.shield, 3);

    battle.endTurn();

    expect(battle.player.hp, 20);
    expect(battle.player.shield, 0);
  });

  test('корни Виктора выбирают клетки после завершения расстановки', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Виктор Корнеплод',
        maxHp: 30,
        attackFaces: const [1],
        rootCells: 5,
      ),
      random: Random(4),
    )..startTurn();

    expect(battle.rootedCells, isEmpty);
    battle.prepareEndTurn();
    expect(battle.rootedCells, hasLength(5));
    expect(battle.rootedCells, everyElement(inInclusiveRange(0, 8)));
    for (final cell in battle.rootedCells) {
      expect(battle.placeDie(0, cell), isFalse);
    }
  });

  test('занятая корнями клетка отменяет кость до разрешения раунда', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Виктор Корнеплод',
        maxHp: 30,
        attackFaces: const [1],
        rootCells: 9,
      ),
    )..startTurn();

    expect(battle.placeDie(0, 4), isTrue);
    battle.prepareEndTurn();

    expect(battle.isCellCancelled(4), isTrue);
    expect(battle.playerIntent.attack, 0);
    expect(battle.endTurn(), isFalse);
    expect(battle.lastEnemyDamage, 0);
  });

  test('освободившаяся клетка снова доступна в следующем раунде', () {
    final battle = BattleEngine(
      player: player(),
      enemy: Fighter(
        name: 'Виктор Корнеплод',
        maxHp: 30,
        attackFaces: const [1],
        rootCells: 1,
      ),
      random: Random(4),
    )..startTurn();
    expect(battle.rootedCells, isEmpty);
    final firstRoundRoots = battle.prepareEndTurn();
    expect(firstRoundRoots, hasLength(1));
    battle.endTurn();
    expect(battle.rootedCells, isEmpty);

    var releasedCell = -1;
    for (final cell in firstRoundRoots) {
      if (!battle.isCellRooted(cell)) {
        releasedCell = cell;
        break;
      }
    }

    expect(releasedCell, greaterThanOrEqualTo(0));
    expect(battle.isCellRooted(releasedCell), isFalse);
    battle.prepareEndTurn();
    expect(battle.rootedCells, hasLength(1));
  });

  test('железная нить не теряется в отображаемой сумме щита', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(
            id: 'guardian',
            name: 'Щит',
            baseFaces: [6],
            level: 6,
            ability: DiceAbility.guardian,
          ),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [6]),
      artifacts: const {Artifact.ironThread: 1},
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.playerIntent.shield, 8);
    expect(battle.previewFor(battle.player).shield, 8);
    expect(
      battle.previewFor(battle.player).blockedDamage,
      6,
      reason: 'заблокированный урон не равен полному щиту',
    );
  });

  test('остаток щита переносится между раундами и принимает новый щит', () {
    final battle = BattleEngine(
      player: Fighter(
        name: 'Игрок',
        maxHp: 30,
        initialShield: 1,
        dice: const [
          Dice(
            id: 'guardian',
            name: 'Щит',
            baseFaces: [3],
            level: 3,
            ability: DiceAbility.guardian,
          ),
        ],
        isPlayer: true,
      ),
      enemy: Fighter(name: 'Враг', maxHp: 50, attackFaces: const [0]),
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.previewFor(battle.player).availableShield, 4);
    battle.endTurn();

    expect(battle.player.shield, 4);
    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.previewFor(battle.player).availableShield, 7);
  });

  test('урон уменьшает накопленный щит, а излишек проходит в HP', () {
    final battle = BattleEngine(
      player: Fighter(
        name: 'Игрок',
        maxHp: 30,
        initialHp: 20,
        initialShield: 5,
        dice: const [],
        isPlayer: true,
      ),
      enemy: Fighter(
        name: 'Враг',
        maxHp: 50,
        attackFaces: const [8],
        actsFirst: true,
      ),
    )..startTurn();

    battle.endTurn();

    expect(battle.player.shield, 0);
    expect(battle.player.hp, 17);
  });

  test('железная нить не складывается даже при старом количестве копий', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(),
      artifacts: const {Artifact.ironThread: 2},
    )..startTurn();

    expect(battle.playerIntent.shield, 2);
  });

  test('железная нить не срабатывает, если щит уже есть в начале хода', () {
    final battle = BattleEngine(
      player: Fighter(
        name: 'Игрок',
        maxHp: 30,
        initialShield: 1,
        dice: const [
          Dice(
            id: 'guardian',
            name: 'Щит',
            baseFaces: [6],
            level: 6,
            ability: DiceAbility.guardian,
          ),
        ],
        isPlayer: true,
      ),
      enemy: enemy(),
      artifacts: const {Artifact.ironThread: 1},
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.placeDie(0, 4), isTrue);
    expect(battle.playerIntent.shield, 6);
  });

  test('защита игрока складывается без ограничения восемью', () {
    final battle = BattleEngine(
      player: player(
        dice: const [
          Dice(
            id: 'guardian-one',
            name: 'Щит 1',
            baseFaces: [6],
            level: 6,
            ability: DiceAbility.guardian,
          ),
          Dice(
            id: 'guardian-two',
            name: 'Щит 2',
            baseFaces: [6],
            level: 6,
            ability: DiceAbility.guardian,
          ),
        ],
      ),
      enemy: Fighter(name: 'Враг', maxHp: 30, attackFaces: const [0]),
      playerDiceCount: 2,
      random: const _MaxRandom(),
    )..startTurn();

    expect(battle.placeDie(0, 0), isTrue);
    expect(battle.placeDie(1, 1), isTrue);
    expect(battle.playerIntent.shield, 12);
    expect(battle.previewFor(battle.player).availableShield, 12);
    battle.endTurn();
    expect(battle.player.shield, 12);
  });
}
