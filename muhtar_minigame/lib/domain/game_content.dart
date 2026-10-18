import '../domain/dice.dart';
import '../domain/dialogue.dart';
import '../domain/equipment.dart';
import '../domain/enemy.dart';
import '../domain/quest.dart';
import '../domain/player_skin.dart';
import '../domain/shop_item.dart';

/// Стартовый набор игрока.
///
/// TODO(контент): наполняется новыми костями, экипировкой, врагами и квестами
/// по мере разработки сюжета.
class GameContent {
  static const List<PlayerSkin> skinCatalog = PlayerSkin.catalog;
  static const List<PlayerSkin> playerSkins = skinCatalog;
  static const List<PlayerSkin> skins = skinCatalog;

  static PlayerSkin? skinById(String id) {
    for (final skin in skinCatalog) {
      if (skin.id == id || skin.portraitKey == id) return skin;
    }
    return null;
  }

  /// Фразы героя для боя. Их можно менять прямо здесь: каждая новая строка
  /// появляется в следующем раунде по очереди.
  static const List<String> playerAttackPhrases = [
    'Очко твоё!',
    'Пукни пукни',
    '*молчит*',
    'Дай в долг',
    'Что делать если забыл я заюыл почту которая для сброса?',
    'В мой аккаунт зашел мошенник, поскорее избавьтесь от него пока он мне аккаунт не снес',
    'Я не помню логин, но это мой аккаунт, к нему получил доступ мошенник',
    'Папочка сасим!',
    'Здравствуйте, меня взломали и мне надо удалить аккаунт',
    'Якорные драги!',
    'Скоуп полапа',
    'Мы блогеры',
    'У меня суперэго',
    'Я как берсерк но мне 13 лет',
    'Надеюсь я не буду дарить веронике',
    'я тебя подовлю',
    'я тебя придушу',
    'я тебя обоссу',
    'Я тебя унижу на весь колледж',
    'Тебе конец, ты получишь за гнилой базар',
    'я уже подучил кондишонал',
    'стрегите мне полубокс',
    'только не полубокс!',
    'protected это доступ по паролю',
    'я собираюсь в ломбард',
    '117 iq. как вам показатель? первый самый лучший в России',
    'Я тебя могну',
  ];

  static const List<ShopItem> shopItems = [
    ShopItem(
      id: 'cheburek',
      npcId: 'baba_galya',
      title: 'Чебурек',
      description: '+5 к максимальному HP. Можно купить один раз.',
      price: 5,
      effect: ShopEffect.increaseMaxHp,
      amount: 5,
    ),
    ShopItem(
      id: 'alenka_bar',
      npcId: 'alenka',
      title: 'Шоколадка Алёнка',
      description: '+5 HP. Продаётся один раз.',
      price: 30,
      effect: ShopEffect.heal,
      amount: 5,
    ),
    ShopItem(
      id: 'alpen_gold',
      npcId: 'alenka',
      title: 'ШОКОЛАДКА АЛЬПЕН ГОЛЬД',
      description: 'Нужна Бабе Гале для задания. Продаётся один раз.',
      price: 25,
      effect: ShopEffect.addItem,
      itemId: 'alpen_gold',
      requiredQuestId: 'q_alpen_gold',
    ),
    ShopItem(
      id: 'doctor_pepper',
      npcId: 'alenka',
      title: 'Доктор Пеппер',
      description: '???',
      price: 10,
      effect: ShopEffect.damage,
      amount: 5,
    ),
    ShopItem(
      id: 'shaurma',
      npcId: 'shaurmek',
      title: 'Шаурма',
      description:
          'Свежая шаурма от поверженного Шаурмека. Доступна только по заданию Ильи.',
      price: 20,
      effect: ShopEffect.addItem,
      itemId: 'shaurma',
      requiredQuestId: 'q_shawarma_for_ilya',
      requiredEnemyId: 'shaurmek',
      requiredLocationId: 'doner',
    ),
  ];

  static ShopItem? shopItemById(String id) {
    for (final item in shopItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<ShopItem> shopItemsForNpc(String npcId) =>
      shopItems.where((item) => item.npcId == npcId).toList(growable: false);

  /// Имя героя меняется вместе с уровнем. Первый уровень намеренно начинается
  /// с имени, которое дал игрок: Буберчик.
  static String playerNameForLevel(int level) {
    const names = [
      'Буберчик',
      'Бублик',
      'Бубрсрун',
      'Бубер',
      'Бубердос',
      'Сержант Буберий',
      'Бабай',
      'Хайзенбубер',
      'Бубзилла',
    ];
    return names[level.clamp(1, names.length).toInt() - 1];
  }

  static const Dice starterDice = Dice(
    id: 'd6',
    name: 'Боевая кость',
    baseFaces: [1, 2, 3, 4, 5, 6],
    ability: DiceAbility.warrior,
    visualKey: 'blade',
  );

  static const Dice doctorDice = Dice(
    id: 'doctor',
    name: 'Кость доктора',
    baseFaces: [1, 2, 3, 4, 5, 6],
    ability: DiceAbility.doctor,
    visualKey: 'doctor',
  );

  static const Dice emberDice = Dice(
    id: 'ember',
    name: 'Кость искры',
    baseFaces: [1, 1, 2, 3, 4, 6],
    ability: DiceAbility.ember,
    visualKey: 'ember',
  );

  static const Dice guardianDice = Dice(
    id: 'guardian',
    name: 'Кость стража',
    baseFaces: [1, 2, 2, 4, 5, 6],
    ability: DiceAbility.guardian,
    visualKey: 'guardian',
  );

  static const Dice upgradeDice = Dice(
    id: 'upgrade',
    name: 'Кость улучшения',
    baseFaces: [1, 2, 3, 4, 5, 6],
    ability: DiceAbility.upgrade,
    visualKey: 'upgrade',
  );

  /// Кости, с которыми начинается новая игра. Каждый источник представлен
  /// ровно один раз: атака, доктор и улучшение.
  static const List<Dice> starterInventory = [
    starterDice,
    doctorDice,
    upgradeDice,
  ];

  /// Архетипы, которые могут выпасть из ящика костей.
  static const List<Dice> diceCatalog = [
    starterDice,
    doctorDice,
    emberDice,
    guardianDice,
    upgradeDice,
  ];

  static Dice? diceById(String id) {
    for (final dice in diceCatalog) {
      if (dice.id == id) return dice;
    }
    return null;
  }

  /// Стартовая экипировка: меч, щит и зелье.
  static const List<EquipmentSlot> starterEquipment = [
    EquipmentSlot(
      id: 'sword',
      name: 'Меч',
      effect: SlotEffect.damage,
      rule: SlotRule.any,
    ),
    EquipmentSlot(
      id: 'shield',
      name: 'Щит',
      effect: SlotEffect.shield,
      rule: SlotRule.even,
    ),
    EquipmentSlot(
      id: 'potion',
      name: 'Зелье',
      effect: SlotEffect.heal,
      rule: SlotRule.minValue,
      minValue: 4,
    ),
  ];

  /// Девять пустых клеток доски. Эффект определяется установленной костью,
  /// а не позицией клетки.
  static final List<EquipmentSlot> battleBoard = [
    for (var index = 0; index < 9; index++)
      EquipmentSlot(
        id: 'board_$index',
        name: '',
        effect: SlotEffect.upgrade,
        rule: SlotRule.any,
      ),
  ];

  /// Тестовые враги.
  static const EnemyArchetype slime = EnemyArchetype(
    id: 'slime',
    name: 'Слизень',
    maxHp: 18,
    diceFaces: [1, 1, 2, 2, 3, 4],
    coins: 8,
    xp: 6,
    appliesBurn: true,
    burnDamage: 2,
    attackPhrases: ['Буль-буль!'],
    equipment: [
      EquipmentSlot(
        id: 'slime_bump',
        name: 'Удар',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Бросается вперёд и наносит урон герою.',
      ),
    ],
  );

  static const EnemyArchetype goblin = EnemyArchetype(
    id: 'goblin',
    name: 'Гоблин',
    maxHp: 26,
    diceFaces: [1, 2, 2, 3, 4, 5],
    coins: 15,
    xp: 12,
    actsFirst: true,
    startingShield: 2,
    attackPhrases: ['Грр, держи дубиной!', 'Не уйдёшь от моей шайки!'],
    equipment: [
      EquipmentSlot(
        id: 'goblin_club',
        name: 'Дубина',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Тяжёлый удар дубиной по герою.',
      ),
      EquipmentSlot(
        id: 'goblin_block',
        name: 'Прикрытие',
        effect: SlotEffect.shield,
        rule: SlotRule.even,
        description: 'Поднимает щит, если на кости выпало чётное значение.',
        rarity: AbilityRarity.rare,
      ),
    ],
  );

  static const EnemyArchetype gopnik = EnemyArchetype(
    id: 'gopnik',
    name: 'Гопник',
    maxHp: 10,
    diceFaces: [1, 2, 2, 3, 3, 4],
    coins: 18,
    xp: 15,
    actsFirst: true,
    attackPhrases: ['Э, слышь, кошелёк на стол!', 'Район не проходной!'],
    equipment: [
      EquipmentSlot(
        id: 'gopnik_push',
        name: 'Толчок',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Резко толкает героя и наносит один удар.',
      ),
    ],
  );

  static const EnemyArchetype shaurmek = EnemyArchetype(
    id: 'shaurmek',
    name: 'Шаурмек',
    maxHp: 32,
    diceFaces: [2, 2, 3, 4, 5, 6],
    coins: 24,
    xp: 20,
    appliesBurn: true,
    burnDamage: 3,
    coinStealChance: 1 / 3,
    healingAmount: 5,
    healingChance: 1 / 3,
    attackPhrases: [
      'Вай вай вай, дорогой, шаурма будишь?',
      'Паследни деньга гони',
      'Радной, я дабавлю твоя фирменного соуса!',
      'Студент?',
      'С сабой или на места?',
    ],
    equipment: [
      EquipmentSlot(
        id: 'shaurmek_skewer',
        name: 'Шампур',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Прокалывает героя шампуром и наносит урон.',
      ),
      EquipmentSlot(
        id: 'shaurmek_sauce',
        name: 'Острый соус',
        effect: SlotEffect.burn,
        rule: SlotRule.minValue,
        minValue: 4,
        description: 'Ожог соусом накладывает горение при значении от 4.',
        rarity: AbilityRarity.rare,
      ),
    ],
  );

  static const EnemyArchetype viktorKorneplod = EnemyArchetype(
    id: 'viktor_korneplod',
    name: 'Виктор Корнеплод',
    maxHp: 38,
    diceFaces: [1, 3, 3, 4, 5, 6],
    coins: 30,
    xp: 26,
    startingShield: 3,
    shieldChance: .35,
    rootCells: 4,
    attackPhrases: [
      'Я Виктор Корнеплод, меня так просто не выкопать!',
      'Корни крепкие, а удар будет ещё крепче!',
    ],
    equipment: [
      EquipmentSlot(
        id: 'viktor_root',
        name: 'Корнеплодный удар',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Удар корнем, после которого Виктор атакует первым.',
      ),
      EquipmentSlot(
        id: 'viktor_bark',
        name: 'Корневая броня',
        effect: SlotEffect.shield,
        rule: SlotRule.even,
        description: 'Покрывает Виктора корой и даёт щит на чётной кости.',
        rarity: AbilityRarity.rare,
      ),
    ],
  );

  static const EnemyArchetype sofia = EnemyArchetype(
    id: 'sofia',
    name: 'София',
    maxHp: 34,
    diceFaces: [1, 2, 2, 3, 5, 6],
    coins: 28,
    xp: 24,
    healingAmount: 5,
    healingChance: .40,
    hideStats: true,
    attackPhrases: [
      'витя умнее меня во многих сферах',
      'я вас ненавижу и не скрываю этого',
      'вы все пешки моего фанфика',
    ],
    equipment: [
      EquipmentSlot(
        id: 'sofia_fiction',
        name: 'Фанфик',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
        description: 'Запутывает героя в сюжете и наносит неожиданный урон.',
        rarity: AbilityRarity.epic,
      ),
    ],
  );

  static const List<EnemyArchetype> enemies = [
    slime,
    goblin,
    gopnik,
    shaurmek,
    viktorKorneplod,
    sofia,
  ];

  static const DialogueTree arianaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'Приветствую путник {playerName}, я писала тебе в тг по поводу '
            'работы доставщиком, помнишь?',
        choices: [
          DialogueChoice(label: 'Конечно, помню!', nextNodeId: 'briefing'),
          DialogueChoice(
            label: 'Что происходит на Мосту?',
            nextNodeId: 'briefing',
          ),
          DialogueChoice(label: 'Открыть магазин костей', openShop: true),
        ],
      ),
      DialogueNode(
        id: 'briefing',
        text:
            'Иди через Парк к Мосту. На правом краю Моста два входа в одно '
            'здание: Копеечка и Чебуречная. За отдельным переходом к Донеру '
            'засел Шаурмек, а Виктор Корнеплод караулит рядом.',
        choices: [
          DialogueChoice(
            label: 'Принять маршрут через Парк к Мосту',
            nextNodeId: 'bridge',
            questId: 'q_bridge',
            notification: 'Задание принято: Дорога на Мост',
          ),
          DialogueChoice(
            label: 'Начать накопление монет',
            questId: 'q_coins',
            notification: 'Задание принято: Накопления',
          ),
          DialogueChoice(label: 'Спросить про Шаурмека', nextNodeId: 'bridge'),
          DialogueChoice(label: 'Открыть магазин костей', openShop: true),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'bridge',
        text:
            'Сначала доберись до Моста через Парк. Затем проверь Донер: '
            'Шаурмек не должен сорвать доставку. Если справишься, разберись '
            'с Виктором Корнеплодом и возвращайся ко мне.',
        choices: [
          DialogueChoice(
            label: 'Взяться за Шаурмека',
            questId: 'q_shaurmek',
            notification: 'Задание принято: Шаурмек на Мосту',
          ),
          DialogueChoice(
            label: 'Взяться за Виктора Корнеплода',
            questId: 'q_viktor_korneplod',
            notification: 'Задание принято: Виктор Корнеплод',
          ),
          DialogueChoice(label: 'Показать задания', openQuestLog: true),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree babaGalyaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'Принеси мне ШОКОЛАДКУ АЛПЕН ГОЛЬД из Копеечки, '
            'и я отблагодарю тебя.',
        choices: [
          DialogueChoice(
            label: 'Взять задание: принести Альпен Гольд',
            questId: 'q_alpen_gold',
            nextNodeId: 'accepted',
            notification: 'Задание принято: Альпен Гольд для Бабы Гали',
          ),
          DialogueChoice(label: 'Открыть магазин чебуреков', openShop: true),
          DialogueChoice(
            label: 'Передать Альпен Гольд',
            completeQuestId: 'q_alpen_gold',
            notification: 'Шоколадка передана Бабе Гале!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'accepted',
        text: 'Жду ШОКОЛАДКУ АЛПЕН ГОЛЬД. Она продаётся у Алёнки в Копеечке.',
        choices: [
          DialogueChoice(label: 'Открыть магазин чебуреков', openShop: true),
          DialogueChoice(
            label: 'Передать Альпен Гольд',
            completeQuestId: 'q_alpen_gold',
            notification: 'Шоколадка передана Бабе Гале!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree alenkaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text: 'Здравствуйте! Копеечка к вашим услугам. Что будете брать?',
        choices: [
          DialogueChoice(label: 'Открыть магазин Копеечки', openShop: true),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree shaurmekDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'Вай, герой! Теперь Донер снова работает. Соберём пару шаурм и '
            'поговорим о покупке для Ильи.',
        choices: [
          DialogueChoice(
            label: 'Задание 1: собрать классическую шаурму',
            questId: 'q_doner_classic',
            donerQuestId: 'q_doner_classic',
            donerRecipeId: 'classic',
            openDonerGame: true,
            requiredEnemyId: 'shaurmek',
            requiredLocationId: 'doner',
            notification: 'Задание принято: Классическая шаурма',
          ),
          DialogueChoice(
            label: 'Задание 2: собрать острую шаурму',
            questId: 'q_doner_spicy',
            donerQuestId: 'q_doner_spicy',
            donerRecipeId: 'spicy',
            openDonerGame: true,
            requiredEnemyId: 'shaurmek',
            requiredLocationId: 'doner',
            notification: 'Задание принято: Острая шаурма',
          ),
          DialogueChoice(
            label: 'Задание 3: фирменный свёрток',
            questId: 'q_doner_signature',
            donerQuestId: 'q_doner_signature',
            donerRecipeId: 'signature',
            openDonerGame: true,
            requiredEnemyId: 'shaurmek',
            requiredLocationId: 'doner',
            notification: 'Задание принято: Фирменный свёрток',
          ),
          DialogueChoice(
            label: 'Продолжить классическую шаурму',
            requiredQuestId: 'q_doner_classic',
            requiredQuestStates: {QuestState.active},
            donerQuestId: 'q_doner_classic',
            donerRecipeId: 'classic',
            openDonerGame: true,
          ),
          DialogueChoice(
            label: 'Продолжить острую шаурму',
            requiredQuestId: 'q_doner_spicy',
            requiredQuestStates: {QuestState.active},
            donerQuestId: 'q_doner_spicy',
            donerRecipeId: 'spicy',
            openDonerGame: true,
          ),
          DialogueChoice(
            label: 'Продолжить фирменный свёрток',
            requiredQuestId: 'q_doner_signature',
            requiredQuestStates: {QuestState.active},
            donerQuestId: 'q_doner_signature',
            donerRecipeId: 'signature',
            openDonerGame: true,
          ),
          DialogueChoice(
            label: 'Купить шаурму для Ильи',
            openShop: true,
            requiredQuestId: 'q_shawarma_for_ilya',
            requiredQuestStates: {QuestState.active},
            requiredEnemyId: 'shaurmek',
            requiredLocationId: 'doner',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree ilyaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text: 'Мне нужна шаурма от Шаурмека. Принесёшь её из Донера?',
        textQuestId: 'q_shawarma_for_ilya',
        textByQuestState: {
          QuestState.active:
              'Купи шаурму у Шаурмека в Донере. Если не передумаешь — принеси её мне.',
          QuestState.completed: 'Ну что, с шаурмой разобрался?',
          QuestState.claimed: 'Ну что, с шаурмой разобрался?',
        },
        textByShawarmaOutcome: {
          'eaten': 'Я просил принести шаурму, а ты съел её сам. Ладно, бывает.',
          'delivered': 'Вот это сервис! Спасибо за шаурму, она дошла целой.',
        },
        choices: [
          DialogueChoice(
            label: 'Взять задание: купить шаурму у Шаурмека',
            questId: 'q_shawarma_for_ilya',
            notification: 'Задание принято: Шаурма для Ильи',
          ),
          DialogueChoice(
            label: 'Передать шаурму Илье',
            completeQuestId: 'q_shawarma_for_ilya',
            notification: 'Шаурма передана Илье!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree wbEmployeeDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text: 'На Мосту завалялась картошка. Найдите её и принесите мне.',
        choices: [
          DialogueChoice(
            label: 'Взять задание: найти картошку на Мосту',
            questId: 'q_potato_bridge',
            nextNodeId: 'accepted',
            notification: 'Задание принято: картошка на Мосту',
          ),
          DialogueChoice(
            label: 'Принести картошку',
            completeQuestId: 'q_potato_bridge',
            nextNodeId: 'returned',
            notification: 'Картошка передана сотруднику ПВЗ!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'accepted',
        text: 'Ищите картошку среди травы на Мосту и возвращайтесь сюда.',
        choices: [
          DialogueChoice(
            label: 'Принести картошку',
            completeQuestId: 'q_potato_bridge',
            nextNodeId: 'returned',
            notification: 'Картошка передана сотруднику ПВЗ!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'returned',
        text: 'Забирайте свои вонючие носки.',
        choices: [
          DialogueChoice(label: 'Я батю депнуууул!', nextNodeId: 'final'),
        ],
      ),
      DialogueNode(
        id: 'final',
        text: 'Сотрудник ПВЗ молча возвращается за стойку.',
        choices: [DialogueChoice(label: 'Закрыть')],
      ),
    ],
  );

  static const DialogueTree malekDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'В магазине потерялась важная вещь — помоги найти '
            'SyncAsync и принеси его мне.',
        textQuestId: 'q_sync_async',
        textByQuestState: {
          QuestState.active:
              'Ищи SyncAsync в кустах Парка и возвращайся ко мне.',
          QuestState.completed:
              'Спасибо, ты принёс SyncAsync! Теперь всё на месте, задание выполнено.',
          QuestState.claimed:
              'Спасибо, ты принёс SyncAsync! Теперь всё на месте, задание выполнено.',
        },
        choices: [
          DialogueChoice(
            label: 'Взять задание: найти SyncAsync',
            questId: 'q_sync_async',
            nextNodeId: 'accepted',
            notification: 'Задание принято: SyncAsync для Малёка',
          ),
          DialogueChoice(
            label: 'Передать SyncAsync',
            completeQuestId: 'q_sync_async',
            notification: 'SyncAsync передан Малёку!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'accepted',
        text: 'Ищи SyncAsync в кустах Парка и возвращайся ко мне.',
        textQuestId: 'q_sync_async',
        textByQuestState: {
          QuestState.completed:
              'Спасибо, ты принёс SyncAsync! Теперь всё на месте, задание выполнено.',
          QuestState.claimed:
              'Спасибо, ты принёс SyncAsync! Теперь всё на месте, задание выполнено.',
        },
        choices: [
          DialogueChoice(
            label: 'Передать SyncAsync',
            completeQuestId: 'q_sync_async',
            notification: 'SyncAsync передан Малёку!',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree ribkaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text: 'Привет! Сыграй со мной песню, и я приготовила подарок.',
        textQuestId: 'q_song',
        textByQuestState: {
          QuestState.completed:
              'Молодец, ты справился! Песня получилась отличная, а подарок уже твой.',
          QuestState.claimed:
              'Молодец, ты справился! Песня получилась отличная, а подарок уже твой.',
        },
        choices: [
          DialogueChoice(
            label: 'Взять задание: сыграть песню',
            questId: 'q_song',
            nextNodeId: 'accepted',
            notification: 'Задание принято: Песня для Рибки',
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
      DialogueNode(
        id: 'accepted',
        text:
            'Слова уже приготовлены. Собери правильную фразу — и песенка зазвучит.',
        choices: [
          DialogueChoice(
            label: 'Начать мини-игру «Спой песенку»',
            openSongGame: true,
          ),
          DialogueChoice(label: 'До встречи'),
        ],
      ),
    ],
  );

  static const DialogueTree sofiaDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'витя умнее меня во многих сферах\n'
            'я вас ненавижу и не скрываю этого\n'
            'вы все пешки моего фанфика',
        choices: [DialogueChoice(label: 'До встречи')],
      ),
    ],
  );

  /// Реплики Бубера вынесены в дерево диалогов отдельно от боевых фраз,
  /// чтобы позже можно было поставить персонажа на любую карту без миграции
  /// контента.
  static const DialogueTree buberDialogue = DialogueTree(
    startNodeId: 'greeting',
    nodes: [
      DialogueNode(
        id: 'greeting',
        text:
            'я тебя подовлю\n'
            'я тебя придушу\n'
            'я тебя обоссу\n'
            'Я тебя унижу на весь колледж\n'
            'Тебе конец, ты получишь за гнилой базар\n'
            'я уже подучил кондишонал\n'
            'стрегите мне полубокс\n'
            'только не полубокс!\n'
            'protected это доступ по паролю\n'
            'я собираюсь в ломбард\n'
            '117 iq. как вам показатель? первый самый лучший в России',
        choices: [DialogueChoice(label: 'До встречи')],
      ),
    ],
  );

  /// Сюжетные задания нового маршрута и нейтральное задание на монеты.
  static const List<Quest> quests = [
    Quest(
      id: 'q_bridge',
      title: 'Дорога на Мост',
      description: 'Пройдите через Парк и доберитесь до Моста.',
      type: QuestType.location,
      locationId: 'ruins',
      target: 1,
      coinReward: 35,
      xpReward: 18,
    ),
    Quest(
      id: 'q_shaurmek',
      title: 'Горячая точка',
      description: 'Победите Шаурмека в Донере.',
      type: QuestType.kill,
      enemyId: 'shaurmek',
      target: 1,
      coinReward: 50,
      xpReward: 24,
    ),
    Quest(
      id: 'q_viktor_korneplod',
      title: 'Корнеплодный король',
      description: 'Победите Виктора Корнеплода в Копеечке.',
      type: QuestType.kill,
      enemyId: 'viktor_korneplod',
      target: 1,
      coinReward: 65,
      xpReward: 28,
    ),
    Quest(
      id: 'q_coins',
      title: 'Накопления',
      description: 'Соберите 100 монет.',
      type: QuestType.collect,
      target: 100,
      coinReward: 25,
    ),
    Quest(
      id: 'q_alpen_gold',
      title: 'Шоколадка для Бабы Гали',
      description:
          'Купите ШОКОЛАДКУ АЛПЕН ГОЛЬД в Копеечке и принесите Бабе Гале.',
      type: QuestType.deliverItem,
      itemId: 'alpen_gold',
      acceptanceNpcId: 'baba_galya',
      target: 1,
      coinReward: 35,
      xpReward: 20,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_sync_async',
      title: 'SyncAsync для Малёка',
      description:
          'Найдите SyncAsync в специальном кусте Парка и принесите его Малику.',
      type: QuestType.deliverItem,
      itemId: 'sync_async',
      searchPropId: 'forest_search_bush_sync_async',
      acceptanceNpcId: 'malek',
      target: 1,
      coinReward: 20,
      xpReward: 15,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_song',
      title: 'Песня для Рибки',
      description: 'Сыграйте песню для Рибки в мини-игре.',
      type: QuestType.miniGame,
      miniGameId: 'song',
      acceptanceNpcId: 'ribka',
      target: 1,
      coinReward: 0,
      xpReward: 0,
      artifactCaseReward: 0,
      skinRewardId: 'ribka_reward',
    ),
    Quest(
      id: 'q_doner_classic',
      title: 'Донер: классика',
      description: 'Соберите классическую шаурму из четырёх компонентов.',
      type: QuestType.miniGame,
      miniGameId: 'doner_classic',
      acceptanceNpcId: 'shaurmek',
      target: 1,
      coinReward: 18,
      xpReward: 8,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_doner_spicy',
      title: 'Донер: огонь',
      description: 'Соберите острую шаурму и не перепутайте соус.',
      type: QuestType.miniGame,
      miniGameId: 'doner_spicy',
      acceptanceNpcId: 'shaurmek',
      target: 1,
      coinReward: 22,
      xpReward: 10,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_doner_signature',
      title: 'Донер: фирменный свёрток',
      description: 'Повторите фирменную сборку Шаурмека.',
      type: QuestType.miniGame,
      miniGameId: 'doner_signature',
      acceptanceNpcId: 'shaurmek',
      target: 1,
      coinReward: 28,
      xpReward: 12,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_shawarma_for_ilya',
      title: 'Шаурма для Ильи',
      description:
          'Возьмите задание у Ильи, купите шаурму у победившего Шаурмека и решите, что с ней сделать.',
      type: QuestType.deliverItem,
      itemId: 'shaurma',
      acceptanceNpcId: 'ilya',
      target: 1,
      coinReward: 40,
      xpReward: 18,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_potato_bridge',
      title: 'Картошка на Мосту',
      description: 'Найдите картошку на Мосту и принесите сотруднику ПВЗ.',
      type: QuestType.deliverItem,
      itemId: 'potato',
      acceptanceNpcId: 'wb_employee',
      target: 1,
      coinReward: 30,
      xpReward: 16,
      artifactCaseReward: 0,
    ),
    Quest(
      id: 'q_kartofla_videos',
      title: 'Картофля',
      description: 'Посмотрите три ролика подряд в раздевалке ВБ.',
      type: QuestType.miniGame,
      miniGameId: 'kartofla_videos',
      acceptancePropId: 'wb_fitting_room',
      target: 1,
      coinReward: 0,
      xpReward: 0,
      artifactCaseReward: 0,
      skinRewardId: 'kartofla',
    ),
  ];

  static EnemyArchetype? enemyById(String id) {
    for (final e in enemies) {
      if (e.id == id) return e;
    }
    return null;
  }

  static DialogueTree? dialogueForNpc(String npcId) {
    if (npcId == 'ariana') return arianaDialogue;
    if (npcId == 'baba_galya') return babaGalyaDialogue;
    if (npcId == 'alenka') return alenkaDialogue;
    if (npcId == 'shaurmek') return shaurmekDialogue;
    if (npcId == 'ilya') return ilyaDialogue;
    if (npcId == 'wb_employee') return wbEmployeeDialogue;
    if (npcId == 'malek') return malekDialogue;
    if (npcId == 'ribka') return ribkaDialogue;
    if (npcId == 'sofia') return sofiaDialogue;
    if (npcId == 'buber') return buberDialogue;
    return null;
  }
}
