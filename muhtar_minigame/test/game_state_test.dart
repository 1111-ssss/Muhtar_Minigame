import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/artifact.dart';
import 'package:muhtar_minigame/domain/dice.dart';
import 'package:muhtar_minigame/domain/game_content.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/domain/quest.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value == 0 ? 0 : 0.5;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  group('GameState', () {
    test('стартовое состояние', () {
      final state = GameState();
      expect(state.coins, 50);
      expect(state.level, 1);
      expect(state.dice.length, 1);
      expect(state.dice.first.id, 'd6');
      expect(state.playerHp, 30);
      expect(state.playerMaxHp, 30);
    });

    test('addCoins/spendCoins', () {
      final state = GameState();
      state.addCoins(100);
      expect(state.coins, 150);
      expect(state.spendCoins(50), isTrue);
      expect(state.coins, 100);
      expect(state.spendCoins(1000), isFalse);
      expect(state.coins, 100);
    });

    test('addXp повышает уровень', () {
      final state = GameState();
      // xpToNext = 100 * level.
      state.addXp(100);
      expect(state.level, 2);
      expect(state.xp, 0);
      // 100 (на ур.2) + 200 (на ур.3) = 300, остаток 50.
      state.addXp(250);
      expect(state.level, 3);
      expect(state.xp, 50);
    });

    test('upgradeDice тратит монеты и повышает уровень', () {
      final state = GameState();
      state.addCoins(100);
      final cost = state.dice.first.upgradeCost; // 25
      expect(state.upgradeDice('d6'), isTrue);
      expect(state.dice.first.level, 2);
      expect(state.coins, 150 - cost);
    });

    test('upgradeDice не работает без монет', () {
      final state = GameState();
      state.spendCoins(state.coins); // оставляем 0 монет
      expect(state.upgradeDice('d6'), isFalse);
      expect(state.dice.first.level, 1);
    });

    test('upgradeDice останавливается на maxLevel', () {
      final state = GameState();
      state.addCoins(100000);
      for (var i = 0; i < 10; i++) {
        state.upgradeDice('d6');
      }
      expect(state.dice.first.level, Dice.maxLevel);
    });

    test('боевой набор увеличивается до шести кубиков разных типов', () {
      final state = GameState()..addCoins(10000);
      expect(state.addDiceType('doctor'), isTrue);
      expect(state.dice.last.ability, DiceAbility.doctor);
      expect(state.addDiceType('ember'), isTrue);
      expect(state.addDiceType('guardian'), isTrue);
      expect(state.addDiceType('doctor'), isTrue);
      expect(state.addDiceType('d6'), isTrue);
      expect(state.diceCount, 6);
      expect(state.addDiceType('d6'), isFalse);

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.diceCount, 6);
      expect(loaded.diceTypeCount('doctor'), 2);
      expect(loaded.dice[1].ability, DiceAbility.doctor);
    });

    test(
      'ящик добавляет случайный кубик в инвентарь, а дубликаты объединяются',
      () {
        final state = GameState()..addCoins(1000);
        final before = state.inventoryCount;
        expect(state.buyCase(), isTrue);
        expect(state.inventoryCount, before);
        expect(state.caseCount(CaseType.dice), 1);
        expect(state.openDiceCase(), isNotNull);
        expect(state.inventoryCount, before + 1);

        state.addDice(
          const Dice(
            id: 'merge-a',
            name: 'Атака',
            baseFaces: [1, 2, 3, 4, 5, 6],
            ability: DiceAbility.warrior,
            level: 2,
          ),
        );
        state.addDice(
          const Dice(
            id: 'merge-b',
            name: 'Атака',
            baseFaces: [1, 2, 3, 4, 5, 6],
            ability: DiceAbility.warrior,
            level: 2,
          ),
        );
        final first = state.inventory.length - 2;
        expect(state.mergeDice(first, first + 1), isTrue);
        expect(
          state.inventory.any(
            (dice) => dice.level == 3 && dice.ability == DiceAbility.warrior,
          ),
          isTrue,
        );
      },
    );

    test('ящик костей выдаёт любой тип, но только уровни 1–3', () {
      for (final sample in [
        (random: 0, level: 1),
        (random: 70, level: 2),
        (random: 99, level: 3),
      ]) {
        final state = GameState(random: _FixedRandom(sample.random));
        state.addCoins(100);
        expect(state.buyDiceBox(), isTrue);
        final result = state.openDiceBox();
        expect(result, isNotNull);
        final dice = result!;
        expect(dice.level, sample.level);
        expect(dice.level, lessThanOrEqualTo(GameState.maxDiceBoxLevel));
      }
    });

    test('награда ящика попадает в инвентарь только после завершения прокрутки', () {
      final state = GameState(random: const _FixedRandom(0))..addCoins(100);
      expect(state.buyDiceBox(), isTrue);
      final before = state.inventoryCount;
      final reward = state.beginDiceBoxOpening();

      expect(reward, isNotNull);
      expect(state.inventoryCount, before);
      expect(state.pendingDiceReward, reward);

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.inventoryCount, before);
      expect(loaded.pendingDiceReward, reward);
      expect(loaded.claimPendingDiceReward(), isTrue);
      expect(loaded.inventoryCount, before + 1);
      expect(loaded.pendingDiceReward, isNull);
    });

    test('ящик артефактов показывает модификатор первым и не стакует уникальные', () {
      final state = GameState(random: const _FixedRandom(0));
      state.addArtifactBoxes(1);
      final choices = state.openArtifactBox();

      expect(state.hasPendingModifierChoice, isTrue);
      expect(choices, hasLength(3));
      expect(choices.toSet(), hasLength(3));
      expect(state.chooseArtifact(choices.first), isTrue);
      expect(state.artifacts[choices.first], 1);
      expect(state.hasPendingModifierChoice, isFalse);

      state.addArtifactBoxes(1);
      state.openArtifactBox();
      final modifier = state.rollModifier();
      expect(modifier, isNot(DiceModifier.none));
      final pending = GameState()..fromJson(state.toJson());
      expect(pending.pendingModifier, modifier);
      expect(state.applyPendingModifier(0), isTrue);
      expect(state.dice.first.modifier, modifier);
    });

    test('редкость и нестакуемость артефактов мигрируют из старого сейва', () {
      final state = GameState()
        ..fromJson({
          'cases': {'artifact': 2},
          'artifacts': {'truceSeal': 3, 'ironThread': 3},
        });

      expect(state.boxCount(CaseType.artifact), 2);
      expect(state.artifacts[Artifact.truceSeal], 1);
      expect(state.artifacts[Artifact.ironThread], 1);
      expect(Artifact.truceSeal.stackable, isFalse);
      expect(Artifact.ironThread.rarity, ArtifactRarity.rare);
      expect(Artifact.fieldKit.rarity, ArtifactRarity.veryRare);
    });

    test(
      'два одинаковых экземпляра одного типа можно объединить по индексам',
      () {
        final state = GameState();
        state
          ..addDice(
            const Dice(
              id: 'd6',
              name: 'Клинок',
              baseFaces: [1, 2, 3, 4, 5, 6],
              ability: DiceAbility.warrior,
              level: 2,
            ),
          )
          ..addDice(
            const Dice(
              id: 'd6',
              name: 'Клинок',
              baseFaces: [1, 2, 3, 4, 5, 6],
              ability: DiceAbility.warrior,
              level: 2,
            ),
          );

        expect(state.mergeDice(1, 2), isTrue);
        expect(state.inventory.where((dice) => dice.level == 3), hasLength(1));
      },
    );

    test('прогресс квеста на Шаурмека', () {
      final state = GameState();
      state.activateQuest('q_shaurmek');
      state.progressQuests(enemyId: 'shaurmek');
      expect(state.quest('q_shaurmek')!.progress, 1);
      expect(state.quest('q_shaurmek')!.state, QuestState.completed);

      state.progressQuests(enemyId: 'shaurmek');
      expect(state.quest('q_shaurmek')!.state, QuestState.completed);
    });

    test('квесты других врагов не считаются', () {
      final state = GameState();
      state.activateQuest('q_shaurmek');
      state.progressQuests(enemyId: 'viktor_korneplod');
      expect(state.quest('q_shaurmek')!.progress, 0);
    });

    test('claimQuest выдаёт награду', () {
      final state = GameState();
      state.activateQuest('q_shaurmek');
      final before = state.coins;
      // Не выполнен — награду не получить.
      expect(state.claimQuest('q_shaurmek'), isFalse);
      expect(state.coins, before);

      // Выполняем.
      state.progressQuests(enemyId: 'shaurmek');
      expect(state.claimQuest('q_shaurmek'), isTrue);
      expect(state.coins, before + 50);
      expect(state.quest('q_shaurmek')!.state, QuestState.claimed);

      // Повторно — нельзя.
      expect(state.claimQuest('q_shaurmek'), isFalse);
    });

    test('сохранение и загрузка', () {
      final state = GameState();
      state.spendCoins(state.coins); // 0
      state.addCoins(77);
      state.addXp(100); // уровень 2
      state.upgradeDice('d6'); // 77 - 25 = 52 монеты, кубик 2 уровня

      final json = state.toJson();
      final loaded = GameState();
      loaded.fromJson(json);

      expect(loaded.coins, 52);
      expect(loaded.level, 2);
      expect(loaded.dice.first.level, 2);
    });

    test('хотбар в магазине Арианы улучшается только до трёх мест', () {
      final state = GameState()..addCoins(10000);
      for (var i = 0; i < 5; i++) {
        state.addDiceType('d6');
      }
      for (var i = 0; i < 2; i++) {
        expect(state.upgradeDicePerTurn(), isTrue);
      }
      expect(state.dicePerTurn, GameState.maxDicePerTurn);
      expect(state.dicePerTurn, 3);
      expect(state.upgradeDicePerTurn(), isFalse);

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.dicePerTurn, GameState.maxDicePerTurn);
      expect(loaded.dicePerTurn, 3);

      final oldSave = GameState()..fromJson({'dicePerTurn': 6});
      expect(oldSave.dicePerTurn, 3);
    });

    test('побеждённый враг и HP героя сохраняются', () {
      final state = GameState();
      state.setPlayerHp(12);
      state.markEnemyDefeated('forest:slime:3:2');
      final remaining = state.enemyRespawnRemaining('forest:slime:3:2');

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.playerHp, 12);
      expect(loaded.isEnemyDefeated('forest:slime:3:2'), isTrue);
      expect(remaining, isNotNull);
      expect(remaining!, greaterThan(const Duration(minutes: 4)));
      expect(remaining, lessThanOrEqualTo(GameState.enemyRespawnDelay));
    });

    test('квест нельзя взять повторно и доставку можно завершить один раз', () {
      final state = GameState();
      expect(state.activateQuest('q_alpen_gold', npcId: 'baba_galya'), isTrue);
      expect(state.activateQuest('q_alpen_gold', npcId: 'baba_galya'), isFalse);
      expect(state.buyShopItem('alpen_gold'), isTrue);
      expect(state.hasItem('alpen_gold'), isTrue);
      expect(state.completeDeliveryQuest('q_alpen_gold'), isTrue);
      expect(state.hasItem('alpen_gold'), isFalse);
      expect(state.quest('q_alpen_gold')!.state, QuestState.completed);
      expect(state.completeDeliveryQuest('q_alpen_gold'), isFalse);
    });

    test('шаурму нельзя купить без задания и победы над Шаурмеком', () {
      final state = GameState();
      expect(state.activateQuest('q_shawarma_for_ilya', npcId: 'ilya'), isTrue);
      expect(state.buyShopItem('shaurma'), isFalse);

      state.markEnemyDefeated('doner:shaurmek:6:4');
      expect(state.buyShopItem('shaurma'), isTrue);
      expect(state.hasItem('shaurma'), isTrue);
      expect(state.hasPurchasedShopItem('shaurma'), isTrue);
    });

    test('выбор после покупки шаурмы меняет исход для Ильи', () {
      final delivered = GameState();
      delivered.activateQuest('q_shawarma_for_ilya', npcId: 'ilya');
      delivered.markEnemyDefeated('doner:shaurmek:6:4');
      delivered.buyShopItem('shaurma');
      expect(delivered.resolveShawarmaChoice(eat: false), isTrue);
      expect(delivered.shawarmaOutcome, 'forIlya');
      expect(delivered.completeDeliveryQuest('q_shawarma_for_ilya'), isTrue);
      expect(delivered.shawarmaOutcome, 'delivered');

      final eaten = GameState();
      eaten.activateQuest('q_shawarma_for_ilya', npcId: 'ilya');
      eaten.markEnemyDefeated('doner:shaurmek:6:4');
      eaten.buyShopItem('shaurma');
      expect(eaten.resolveShawarmaChoice(eat: true), isTrue);
      expect(eaten.shawarmaOutcome, 'eaten');
      expect(eaten.hasItem('shaurma'), isFalse);
      expect(eaten.quest('q_shawarma_for_ilya')!.state, QuestState.completed);
    });

    test(
      'картошка на Мосту сохраняется, доставляется и исчезает навсегда',
      () async {
        final state = GameState();
        final potato = Locations.ruins.props.singleWhere(
          (prop) => prop.specialItemId == 'potato',
        );
        state.activateQuest('q_potato_bridge', npcId: 'wb_employee');
        for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
          state.searchProp(potato.id);
        }

        expect(state.hasItem('potato'), isTrue);
        expect(state.searchResult(potato.id)!.itemId, 'potato');
        expect(state.isPropVisible(potato), isFalse);

        final directory = await Directory.systemTemp.createTemp(
          'muhtar-potato-',
        );
        try {
          await state.save(directory.path);
          final loaded = GameState();
          expect(await loaded.load(directory.path), isTrue);
          expect(loaded.itemCount('potato'), 1);
          expect(loaded.searchResult(potato.id)!.completed, isTrue);
          expect(loaded.isPropVisible(potato), isFalse);

          expect(loaded.completeDeliveryQuest('q_potato_bridge'), isTrue);
          expect(loaded.hasItem('potato'), isFalse);
          expect(loaded.isPropVisible(potato), isFalse);
          expect(loaded.quest('q_potato_bridge')!.state, QuestState.completed);

          await loaded.save(directory.path);
          final delivered = GameState();
          expect(await delivered.load(directory.path), isTrue);
          expect(delivered.itemCount('potato'), 0);
          expect(delivered.searchResult(potato.id)!.completed, isTrue);
          expect(delivered.isPropVisible(potato), isFalse);
          expect(delivered.completeDeliveryQuest('q_potato_bridge'), isFalse);
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test(
      'выполненное задание получает награду и больше не показывается активным',
      () {
        final state = GameState();
        state.activateQuest('q_shaurmek');
        state.progressQuests(enemyId: 'shaurmek');

        expect(state.quest('q_shaurmek')!.state, QuestState.completed);
        expect(state.claimCompletedQuests(), 1);
        expect(state.quest('q_shaurmek')!.state, QuestState.claimed);
        expect(state.claimCompletedQuests(), 0);
        expect(state.activeQuests, isEmpty);
      },
    );

    test('состояние задания сохраняется в отдельной сессии', () async {
      final directory = await Directory.systemTemp.createTemp('muhtar-save-');
      try {
        final state = GameState();
        expect(state.activateQuest('q_shaurmek'), isTrue);
        await state.save(directory.path);

        final loaded = GameState();
        expect(await loaded.load(directory.path), isTrue);
        expect(loaded.quest('q_shaurmek')!.state, QuestState.active);
        expect(loaded.activateQuest('q_shaurmek'), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test(
      'после победы восстанавливается 10 процентов максимального HP врага',
      () {
        final state = GameState()..setPlayerHp(10);

        expect(state.healAfterVictory(38), 4);
        expect(state.playerHp, 14);
      },
    );

    test('повреждённое состояние задания не ломает загрузку', () {
      final state = GameState()
        ..fromJson({
          'quests': {
            'q_shaurmek': {'state': 'unknown', 'progress': 999},
          },
        });

      expect(state.quest('q_shaurmek')!.state, QuestState.notStarted);
      expect(state.quest('q_shaurmek')!.progress, 1);
      expect(state.quest('q_viktor_korneplod')!.state, QuestState.notStarted);
    });

    test('одноразовые товары применяют правильные эффекты', () {
      final state = GameState();
      expect(state.buyShopItem('cheburek'), isTrue);
      expect(state.playerMaxHp, 35);
      expect(state.buyShopItem('cheburek'), isFalse);

      final healed = GameState()..setPlayerHp(20);
      expect(healed.buyShopItem('alenka_bar'), isTrue);
      expect(healed.playerHp, 25);
      expect(healed.buyShopItem('alenka_bar'), isFalse);

      final damaged = GameState()..setPlayerHp(20);
      expect(damaged.buyShopItem('doctor_pepper'), isTrue);
      expect(damaged.playerHp, 15);
      expect(damaged.playerMaxHp, 30);
    });

    test('магазины и бонус HP сохраняются', () {
      final state = GameState();
      state.buyShopItem('cheburek');
      state.activateQuest('q_alpen_gold', npcId: 'baba_galya');
      state.buyShopItem('alpen_gold');
      final loaded = GameState()..fromJson(state.toJson());

      expect(loaded.playerMaxHp, 35);
      expect(loaded.hasPurchasedShopItem('cheburek'), isTrue);
      expect(loaded.hasItem('alpen_gold'), isTrue);
      expect(loaded.quest('q_alpen_gold')!.state, QuestState.active);
    });

    test('поиск специального куста выдаёт SyncAsync ровно на десятом тапе', () {
      final state = GameState();
      final prop = Locations.forest.props.firstWhere(
        (candidate) => candidate.specialItemId == 'sync_async',
      );

      for (var tap = 0; tap < 9; tap++) {
        expect(state.searchProp(prop.id).completed, isFalse);
      }
      final result = state.searchProp(prop.id);

      expect(result.completed, isTrue);
      expect(result.itemId, 'sync_async');
      expect(state.itemCount('sync_async'), 1);
      expect(state.searchProp(prop.id).itemId, 'sync_async');
      expect(state.itemCount('sync_async'), 1);
      expect(state.isPropVisible(prop), isFalse);

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.searchProp(prop.id).itemId, 'sync_async');
      expect(loaded.itemCount('sync_async'), 1);
      expect(loaded.isPropVisible(prop), isFalse);
    });

    test('обычный куст даёт маленькую находку или ничего', () {
      final emptyState = GameState(random: const _FixedRandom(0));
      final emptyProp = Locations.horse.props.singleWhere(
        (prop) => prop.searchable,
      );
      for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
        emptyState.searchProp(emptyProp.id);
      }
      final empty = emptyState.searchResult(emptyProp.id)!;
      expect(empty.rewardType, SearchRewardType.none);
      expect(empty.amount, 0);
      expect(emptyState.isPropVisible(emptyProp), isTrue);

      final hpState = GameState(random: const _FixedRandom(1));
      for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
        hpState.searchProp(emptyProp.id);
      }
      expect(
        hpState.searchResult(emptyProp.id)!.amount,
        inInclusiveRange(1, GameState.maxBushHpReward),
      );
      expect(hpState.searchResult(emptyProp.id)!.amount, 2);
      expect(hpState.playerHp, 30);

      final coinState = GameState(random: const _FixedRandom(2));
      for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
        coinState.searchProp(emptyProp.id);
      }
      expect(
        coinState.searchResult(emptyProp.id)!.rewardType,
        SearchRewardType.coins,
      );
      expect(coinState.searchResult(emptyProp.id)!.amount, 5);
      expect(coinState.coins, 55);
    });

    test(
      'передача SyncAsync завершает квест и не повторяется после загрузки',
      () {
        final state = GameState();
        final prop = Locations.forest.props.firstWhere(
          (candidate) => candidate.specialItemId == 'sync_async',
        );
        expect(state.activateQuest('q_sync_async', npcId: 'malek'), isTrue);
        for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
          state.searchProp(prop.id);
        }

        expect(state.completeDeliveryQuest('q_sync_async'), isTrue);
        expect(state.quest('q_sync_async')!.state, QuestState.completed);

        final loaded = GameState()..fromJson(state.toJson());
        expect(loaded.completeDeliveryQuest('q_sync_async'), isFalse);
        expect(loaded.quest('q_sync_async')!.state, QuestState.completed);
      },
    );

    test('песня открывает наградный скин без ящика', () {
      final state = GameState();
      expect(state.activateQuest('q_song', npcId: 'ribka'), isTrue);
      expect(state.completeSongQuest(), isTrue);
      expect(state.completeSongQuest(), isFalse);
      expect(state.claimQuest('q_song'), isTrue);
      expect(state.hasSkin('ribka_reward'), isTrue);
      expect(state.caseCount(CaseType.artifact), 0);
      expect(state.caseCount(CaseType.dice), 0);

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.claimQuest('q_song'), isFalse);
    });

    test('скин сохраняется и по умолчанию виден только открытый каталог', () {
      final state = GameState();
      expect(state.availableSkins.map((skin) => skin.id).toList(), ['default']);
      state.unlockSkin('ribka_reward');
      state.selectSkin('ribka_reward');

      final loaded = GameState()..fromJson(state.toJson());
      expect(loaded.selectedSkinId, 'ribka_reward');
      expect(
        loaded.availableSkins.map((skin) => skin.id).toList(),
        containsAll(<String>['default', 'ribka_reward']),
      );
    });
  });

  group('GameContent', () {
    test('enemyById находит врага', () {
      expect(GameContent.enemyById('slime')?.name, 'Слизень');
      expect(GameContent.enemyById('goblin')?.name, 'Гоблин');
      expect(GameContent.enemyById('nonexistent'), isNull);
    });

    test('стартовая экипировка имеет 3 слота', () {
      expect(GameContent.starterEquipment.length, 3);
    });
  });
}
