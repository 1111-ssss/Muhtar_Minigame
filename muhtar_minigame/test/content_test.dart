import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/game_content.dart';
import 'package:muhtar_minigame/domain/location.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/domain/quest.dart';
import 'package:muhtar_minigame/game/world/enemy_entity.dart';
import 'package:muhtar_minigame/game/world/map_entity.dart';

void main() {
  test('имя Буберчика меняется по уровням и закрепляется на последнем', () {
    expect(GameContent.playerNameForLevel(1), 'Буберчик');
    expect(GameContent.playerNameForLevel(2), 'Бублик');
    expect(GameContent.playerNameForLevel(6), 'Сержант Буберий');
    expect(GameContent.playerNameForLevel(9), 'Бубзилла');
    expect(GameContent.playerNameForLevel(99), 'Бубзилла');
  });

  test('Ариана говорит стартовую реплику и открывает магазин', () {
    final dialogue = GameContent.dialogueForNpc('ariana')!;
    final greeting = dialogue.nodeById(dialogue.startNodeId)!;

    expect(greeting.text, contains('{playerName}'));
    expect(greeting.text, contains('работы доставщиком'));
    expect(greeting.choices.any((choice) => choice.openShop), isTrue);

    final briefing = dialogue.nodeById('briefing')!;
    final bridge = dialogue.nodeById('bridge')!;
    expect(briefing.text, contains('Шаурмек'));
    expect(briefing.text, contains('Виктор Корнеплод'));
    expect(bridge.text, contains('Копеечку'));
    expect(bridge.text, contains('Мост'));
    expect(
      GameContent.enemyById('shaurmek')!.attackPhrases,
      containsAll(<String>[
        'Вай вай вай, дорогой, шаурма будишь?',
        'Паследни деньга гони',
      ]),
    );
  });

  test('герой имеет редактируемый список боевых фраз', () {
    expect(GameContent.playerAttackPhrases, contains('Очко твоё!'));
    expect(GameContent.playerAttackPhrases, contains('Мы блогеры'));
  });

  test('новые враги имеют архетипы и спавны на Вокзале', () {
    expect(GameContent.enemyById('gopnik')?.name, 'Гопник');
    expect(GameContent.enemyById('shaurmek')?.name, 'Шаурмек');
    expect(GameContent.enemyById('viktor_korneplod')?.name, 'Виктор Корнеплод');
    expect(
      Locations.meadow.enemies.map((spawn) => spawn.enemyId),
      containsAll(<String>['shaurmek', 'viktor_korneplod']),
    );
  });

  test('новые враги получают отдельные виды сущностей карты', () {
    final shaurmek = EnemyEntity(
      enemyId: 'shaurmek',
      col: 1,
      row: 1,
      label: 'Шаурмек',
      spawnKey: 'test:shaurmek',
    );
    final viktor = EnemyEntity(
      enemyId: 'viktor_korneplod',
      col: 1,
      row: 1,
      label: 'Виктор Корнеплод',
      spawnKey: 'test:viktor',
    );

    expect(shaurmek.kind, MapEntityKind.shaurmek);
    expect(viktor.kind, MapEntityKind.viktorKorneplod);
  });

  test('сюжетные задания заменены маршрутом к Мосту и новыми врагами', () {
    final questIds = GameContent.quests.map((quest) => quest.id);

    expect(
      questIds,
      containsAll(<String>['q_bridge', 'q_shaurmek', 'q_viktor_korneplod']),
    );
    expect(questIds, isNot(contains('q_slimes')));
    expect(questIds, isNot(contains('q_goblin')));
  });

  test('новые NPC, квест и товары заведены в контенте', () {
    expect(Locations.cheburechnaya.npcs.single.id, 'baba_galya');
    expect(Locations.kopeechka.npcs.single.id, 'alenka');
    expect(GameContent.dialogueForNpc('baba_galya'), isNotNull);
    expect(GameContent.dialogueForNpc('alenka'), isNotNull);
    expect(GameContent.shopItemsForNpc('baba_galya').single.price, 5);
    expect(
      GameContent.shopItemsForNpc('alenka').map((item) => item.id),
      containsAll(<String>['alenka_bar', 'alpen_gold', 'doctor_pepper']),
    );
    expect(
      GameContent.quests.any((quest) => quest.id == 'q_alpen_gold'),
      isTrue,
    );
    expect(Locations.kopeechka.additionalNpcs.single.id, 'malek');
    expect(Locations.ruins.npcs.single.id, 'ribka');
    expect(Locations.forest.npcs.single.id, 'sofia');
    expect(
      Locations.forest.props.any(
        (prop) => prop.specialItemId == 'sync_async' && prop.searchable,
      ),
      isTrue,
    );
    expect(
      Locations.cheburechnaya.props.any(
        (prop) => prop.kind == LocationPropKind.trashBin && prop.searchable,
      ),
      isTrue,
    );
    expect(GameContent.dialogueForNpc('malek'), isNotNull);
    expect(GameContent.dialogueForNpc('ribka'), isNotNull);
    expect(GameContent.dialogueForNpc('sofia'), isNotNull);
  });

  test(
    'NPC не повторяют имя в начале реплики, а завершённые квесты меняют текст',
    () {
      final baba = GameContent.dialogueForNpc(
        'baba_galya',
      )!.nodeById('greeting')!;
      final alenka = GameContent.dialogueForNpc(
        'alenka',
      )!.nodeById('greeting')!;
      final malek = GameContent.dialogueForNpc('malek')!.nodeById('greeting')!;
      final ribka = GameContent.dialogueForNpc('ribka')!.nodeById('greeting')!;

      expect(baba.text, isNot(contains('Баба Галя')));
      expect(alenka.text, isNot(contains('Алёнка')));
      expect(malek.text, isNot(contains('Малёк')));
      expect(ribka.text, isNot(contains('Рибка')));

      expect(
        ribka.textByQuestState[QuestState.completed],
        startsWith('Молодец, ты справился'),
      );
      expect(
        ribka.textByQuestState[QuestState.claimed],
        startsWith('Молодец, ты справился'),
      );
      expect(malek.textByQuestState[QuestState.completed], contains('Спасибо'));
      expect(
        malek.choices.any((choice) => choice.completeQuestId == 'q_sync_async'),
        isTrue,
      );
    },
  );

  test('гопник не получает скрытое горение и ослаблен', () {
    final gopnik = GameContent.enemyById('gopnik')!;
    expect(gopnik.appliesBurn, isFalse);
    expect(gopnik.burnDamage, 0);
    expect(gopnik.maxHp, 20);
    expect(gopnik.diceFaces, [1, 2, 2, 3, 3, 4]);
  });
}
