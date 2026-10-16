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

  Fighter enemy({bool first = false, int burnDamage = 0}) => Fighter(
    name: 'Враг',
    maxHp: 30,
    attackFaces: const [4],
    actsFirst: first,
    burnDamage: burnDamage,
    baseShield: 2,
    appearance: 'goblin',
  );

  test('новый бросок выбирает случайную грань от уровня до 6', () {
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

    expect(battle.hotbar.single!.value, inInclusiveRange(4, 6));
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
    expect(battle.removeDie(4), isTrue);
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
      expect(battle.playerIntent.heal, 12);

      battle.endTurn();

      expect(battle.player.hp, 22);
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

      expect(battle.board[1]!.value, 6);
      expect(battle.effectiveValueAt(1), 18);
      expect(battle.playerIntent.attack, 18);
    },
  );

  test('статы врага показывают его ожидаемую атаку', () {
    final battle = BattleEngine(player: player(), enemy: enemy())..startTurn();
    final preview = battle.previewFor(battle.player);
    expect(preview.incomingDamage, 4);
    expect(preview.blockedDamage, 0);
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

      expect(battle.hotbar.single!.value, 6);
      expect(battle.placeDie(0, 4), isTrue);
      expect(battle.playerIntent.heal, 6);
      expect(battle.previewFor(battle.player).healing, 6);

      battle.endTurn();

      expect(battle.player.hp, 16);
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
    expect(battle.playerIntent.heal, 8);
    expect(battle.previewFor(battle.player).healing, 8);

    battle.endTurn();

    expect(battle.player.hp, 18);

    final cappedBattle = doctorBattle(29);
    expect(cappedBattle.placeDie(0, 4), isTrue);
    expect(cappedBattle.playerIntent.heal, 8);
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

  test('корни Виктора блокируют пять случайных клеток на раунд', () {
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

    expect(battle.rootedCells, hasLength(5));
    expect(battle.rootedCells, everyElement(inInclusiveRange(0, 8)));
    for (final cell in battle.rootedCells) {
      expect(battle.placeDie(0, cell), isFalse);
    }
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
    final firstRoundRoots = battle.rootedCells;
    var releasedCell = -1;

    for (var round = 0; round < 10; round++) {
      battle.endTurn();
      for (final cell in firstRoundRoots) {
        if (!battle.isCellRooted(cell)) {
          releasedCell = cell;
          break;
        }
      }
      if (releasedCell >= 0) break;
    }

    expect(releasedCell, greaterThanOrEqualTo(0));
    expect(battle.isCellRooted(releasedCell), isFalse);
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

  test('каждая копия железной нити добавляет два щита', () {
    final battle = BattleEngine(
      player: player(),
      enemy: enemy(),
      artifacts: const {Artifact.ironThread: 2},
    )..startTurn();

    expect(battle.playerIntent.shield, 4);
  });
}
