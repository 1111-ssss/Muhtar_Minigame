import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/dice.dart';
import '../domain/artifact.dart';
import '../domain/game_content.dart';
import '../domain/location.dart';
import '../domain/locations.dart';
import '../domain/player_skin.dart';
import '../domain/quest.dart';
import '../domain/shop_item.dart';

/// Состояние игрока и прогресс. Знает про Flutter только через ChangeNotifier.
class GameState extends ChangeNotifier {
  /// Старый лимит API сохранён для миграции; реальные ящики не ограничивают
  /// размер инвентаря.
  static const int maxDiceCount = 6;

  /// Максимальный размер хотбара, который можно купить у Арианы.
  static const int maxDicePerTurn = 3;
  static const int maxRerollsPerRound = 6;
  static const int caseCost = 30;
  static const int maxDiceBoxLevel = 3;
  static const int maxBushHpReward = 3;
  static const String insulinSyringeItemId = 'insulin_syringe';
  static const Duration tripDuration = Duration(minutes: 5);
  static const Duration enemyRespawnDelay = Duration(minutes: 5);

  GameState({Random? random}) : _random = random ?? Random() {
    _resetValues();
  }

  int _coins = 50;
  int _xp = 0;
  int _level = 1;
  int _playerHp = 30;
  int _bonusMaxHp = 0;
  int _dicePerTurn = 1;
  int _rerollsPerRound = 1;
  String _currentLocationId = 'meadow';
  List<Dice> _dice = [];
  Map<String, QuestProgress> _quests = {};
  Set<String> _defeatedEnemyKeys = {};
  Map<String, DateTime> _enemyRespawnAt = {};
  final Map<CaseType, int> _cases = {};
  final Map<Artifact, int> _artifacts = {};
  final Map<String, int> _items = {};
  final Set<String> _purchasedShopItems = {};
  final Set<String> _defeatedEnemyAccess = {};
  String? _shawarmaOutcome;
  DateTime? _tripUntil;
  List<Artifact> _pendingArtifactChoices = [];
  bool _pendingModifierChoice = false;
  DiceModifier? _pendingModifier;
  Dice? _pendingDiceReward;
  final Random _random;
  final Set<String> _ownedSkinIds = {};
  String _selectedSkinId = PlayerSkin.defaultSkin.id;
  final Map<String, int> _searchTaps = {};
  final Map<String, SearchResult> _searchResults = {};

  int boxCount(CaseType type) => _cases[type] ?? 0;

  @Deprecated('Используйте boxCount')
  int caseCount(CaseType type) => boxCount(type);

  void addArtifactBoxes(int count) {
    if (count <= 0) return;
    _cases[CaseType.artifact] = boxCount(CaseType.artifact) + count;
    notifyListeners();
  }

  @Deprecated('Используйте addArtifactBoxes')
  void addArtifactCases(int count) => addArtifactBoxes(count);

  Map<Artifact, int> get artifacts => Map.unmodifiable(_artifacts);
  List<Artifact> get pendingArtifactChoices =>
      List.unmodifiable(_pendingArtifactChoices);
  bool get hasPendingModifierChoice => _pendingModifierChoice;
  DiceModifier? get pendingModifier => _pendingModifier;
  Dice? get pendingDiceReward => _pendingDiceReward;

  int get coins => _coins;
  int get xp => _xp;
  int get level => _level;
  String get playerName => GameContent.playerNameForLevel(_level);
  int get playerMaxHp => 30 + (_level - 1) * 3 + _bonusMaxHp;
  int get playerHp => _playerHp.clamp(0, playerMaxHp).toInt();
  int get dicePerTurn => _dicePerTurn.clamp(1, maxDicePerTurn).toInt();
  int get rerollsPerRound =>
      _rerollsPerRound.clamp(1, maxRerollsPerRound).toInt();
  List<Dice> get dice => List.unmodifiable(_dice);
  List<Dice> get inventory => List.unmodifiable(_dice);
  int get diceCount => _dice.length;
  int get inventoryCount => _dice.length;
  int get bonusMaxHp => _bonusMaxHp;
  Map<String, int> get items => Map.unmodifiable(_items);
  int itemCount(String itemId) => _items[itemId] ?? 0;
  bool hasItem(String itemId) => itemCount(itemId) > 0;
  DateTime? get tripUntil => _tripUntil;
  bool get tripActive =>
      _tripUntil != null && DateTime.now().isBefore(_tripUntil!);
  bool hasPurchasedShopItem(String itemId) =>
      _purchasedShopItems.contains(itemId);

  /// Результат сценки после покупки шаурмы: `eaten` или `delivered`.
  String? get shawarmaOutcome => _shawarmaOutcome;

  List<PlayerSkin> get ownedSkins => [
    for (final skin in GameContent.skinCatalog)
      if (_ownedSkinIds.contains(skin.id)) skin,
  ];

  /// Каталог, отфильтрованный по уже открытым образам. Инвентарь использует
  /// именно этот список, чтобы закрытые скины вообще не занимали место в UI.
  List<PlayerSkin> get availableSkins => List.unmodifiable(ownedSkins);

  Set<String> get ownedSkinIds => Set.unmodifiable(_ownedSkinIds);

  String get selectedSkinId => _selectedSkinId;

  PlayerSkin get selectedSkin =>
      GameContent.skinById(_selectedSkinId) ?? PlayerSkin.defaultSkin;

  PlayerSkin get selectedPlayerSkin => selectedSkin;

  bool hasSkin(String skinId) {
    final skin = GameContent.skinById(skinId);
    return skin != null && _ownedSkinIds.contains(skin.id);
  }

  bool unlockSkin(String skinId) {
    final skin = GameContent.skinById(skinId);
    if (skin == null || !_ownedSkinIds.add(skin.id)) return false;
    notifyListeners();
    return true;
  }

  bool selectSkin(String skinId) {
    final skin = GameContent.skinById(skinId);
    if (skin == null || !hasSkin(skin.id)) return false;
    if (_selectedSkinId == skin.id) return true;
    _selectedSkinId = skin.id;
    notifyListeners();
    return true;
  }

  int searchTapCount(String propId) => _searchTaps[propId] ?? 0;

  SearchResult? searchResult(String propId) => _searchResults[propId];

  /// Возвращает, должен ли проп оставаться видимым и доступным для поиска.
  ///
  /// Обычные поисковые объекты можно исследовать снова по старому правилу
  /// игры. Объект с [LocationProp.specialItemId] — одноразовый: успешный
  /// поиск фиксируется в [searchResult] и скрывает его навсегда, независимо от
  /// того, находится предмет ещё в инвентаре или уже был передан по квесту.
  bool isPropVisible(LocationProp prop) {
    if (prop.specialItemId == null) return true;
    return _searchResults[prop.id]?.completed != true;
  }

  /// Цена следующего места в хотбаре.
  int get diceUpgradeCost => 35 + (dicePerTurn - 1) * 25;
  int get rerollUpgradeCost => 25 + (rerollsPerRound - 1) * 20;

  Map<String, QuestProgress> get quests => Map.unmodifiable(_quests);

  bool isEnemyDefeated(String spawnKey) {
    final remaining = enemyRespawnRemaining(spawnKey);
    return remaining != null;
  }

  /// Проверяет победу над конкретным врагом в конкретной локации.
  /// Координаты не нужны снаружи: достаточно любого живого таймера
  /// возрождения этого архетипа.
  bool hasDefeatedEnemyAt(String locationId, String enemyId) {
    if (_defeatedEnemyAccess.contains('$locationId:$enemyId')) return true;
    final prefix = '$locationId:$enemyId:';
    for (final key in _enemyRespawnAt.keys.toList()) {
      if (key.startsWith(prefix) && enemyRespawnRemaining(key) != null) {
        return true;
      }
    }
    return false;
  }

  Duration? enemyRespawnRemaining(String spawnKey) {
    final respawnAt = _enemyRespawnAt[spawnKey];
    if (respawnAt == null) return null;
    final remaining = respawnAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _enemyRespawnAt.remove(spawnKey);
      _defeatedEnemyKeys.remove(spawnKey);
      return null;
    }
    return remaining;
  }

  /// id текущей локации игрока.
  String get currentLocationId => _currentLocationId;
  set currentLocationId(String value) {
    _currentLocationId = value;
    notifyListeners();
  }

  /// Опыт, нужный для следующего уровня.
  int get xpToNext => 100 * _level;

  List<QuestProgress> get activeQuests =>
      _quests.values.where((q) => q.state == QuestState.active).toList();

  List<QuestProgress> get completedQuests =>
      _quests.values.where((q) => q.state == QuestState.completed).toList();

  // --- Монеты ---

  void addCoins(int amount) {
    if (amount == 0) return;
    _coins += amount;
    notifyListeners();
  }

  bool spendCoins(int amount) {
    if (amount < 0 || _coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    return true;
  }

  // --- Опыт и уровни ---

  void addXp(int amount) {
    _addXpSilently(amount);
    notifyListeners();
  }

  void _addXpSilently(int amount) {
    _xp += amount;
    while (_xp >= xpToNext) {
      _xp -= xpToNext;
      _level++;
    }
  }

  /// HP героя живёт между отдельными сражениями.
  void setPlayerHp(int value) {
    _playerHp = value.clamp(0, playerMaxHp).toInt();
    notifyListeners();
  }

  /// Небольшое восстановление после победы: 10% максимального HP врага.
  int healAfterVictory(int defeatedMaxHp) {
    final amount = max(1, (defeatedMaxHp * .1).round());
    setPlayerHp(_playerHp + amount);
    return amount;
  }

  void loseCoins(int amount) {
    if (amount <= 0) return;
    _coins = (_coins - amount).clamp(0, 1 << 31).toInt();
    notifyListeners();
  }

  // --- Инвентарь и Шоп Арианы ---

  @Deprecated('Используйте buyCase')
  bool addDiceType(String diceId) {
    if (diceCount >= maxDiceCount) return false;
    final template = GameContent.diceById(diceId);
    if (template == null || !spendCoins(caseCost)) return false;
    _dice.add(template);
    notifyListeners();
    return true;
  }

  int diceTypeCount(String diceId) =>
      _dice.where((dice) => dice.id == diceId).length;

  /// Покупка не открывает ящик. Он попадает в стопку в инвентаре.
  bool buyDiceBox() {
    if (_coins < caseCost) return false;
    _coins -= caseCost;
    _cases[CaseType.dice] = boxCount(CaseType.dice) + 1;
    notifyListeners();
    return true;
  }

  @Deprecated('Используйте buyDiceBox')
  bool buyCase() => buyDiceBox();

  /// Уровни 2–3 из ящика редкие, а уровни 4–6 не выпадают вообще.
  int _rollDiceBoxLevel() {
    final roll = _random.nextInt(100);
    if (roll < 70) return 1;
    if (roll < 92) return 2;
    return maxDiceBoxLevel;
  }

  /// Награда фиксируется до анимации: закрытие окна не теряет кость и не
  /// позволяет перебросить результат открытия.
  Dice? beginDiceBoxOpening() {
    if (_pendingDiceReward != null) return _pendingDiceReward;
    if (boxCount(CaseType.dice) == 0) return null;
    _cases[CaseType.dice] = boxCount(CaseType.dice) - 1;
    final template = GameContent
        .diceCatalog[_random.nextInt(GameContent.diceCatalog.length)];
    _pendingDiceReward = template.copyWith(level: _rollDiceBoxLevel());
    notifyListeners();
    return _pendingDiceReward;
  }

  bool claimPendingDiceReward() {
    final reward = _pendingDiceReward;
    if (reward == null) return false;
    _dice.add(reward);
    _pendingDiceReward = null;
    notifyListeners();
    return true;
  }

  Dice? openDiceBox() {
    final result = beginDiceBoxOpening();
    if (result == null) return null;
    claimPendingDiceReward();
    return result;
  }

  @Deprecated('Используйте openDiceBox')
  Dice? openDiceCase() => openDiceBox();

  List<Artifact> openArtifactBox() {
    if (_pendingModifierChoice || _pendingArtifactChoices.isNotEmpty) {
      return pendingArtifactChoices;
    }
    if (boxCount(CaseType.artifact) == 0) return const [];
    _cases[CaseType.artifact] = boxCount(CaseType.artifact) - 1;
    _pendingModifierChoice = true;
    _pendingModifier = null;
    _pendingArtifactChoices = _rollArtifactChoices();
    notifyListeners();
    return pendingArtifactChoices;
  }

  @Deprecated('Используйте openArtifactBox')
  List<Artifact> openArtifactCase() => openArtifactBox();

  List<Artifact> _rollArtifactChoices() {
    final pool = Artifact.values
        .where((artifact) => artifact.stackable || !_artifacts.containsKey(artifact))
        .toList();
    final choices = <Artifact>[];
    while (pool.isNotEmpty && choices.length < 3) {
      final totalWeight = pool.fold<int>(
        0,
        (total, artifact) => total + artifact.rarity.dropWeight,
      );
      var roll = _random.nextInt(totalWeight);
      var selectedIndex = 0;
      for (var index = 0; index < pool.length; index++) {
        roll -= pool[index].rarity.dropWeight;
        if (roll < 0) {
          selectedIndex = index;
          break;
        }
      }
      choices.add(pool.removeAt(selectedIndex));
    }
    return choices;
  }

  bool chooseArtifact(Artifact artifact) {
    if (_pendingModifier != null || !_pendingArtifactChoices.contains(artifact)) {
      return false;
    }
    if (!artifact.stackable && _artifacts.containsKey(artifact)) return false;
    _artifacts[artifact] = artifact.stackable
        ? (_artifacts[artifact] ?? 0) + 1
        : 1;
    _pendingArtifactChoices = [];
    _pendingModifierChoice = false;
    notifyListeners();
    return true;
  }

  /// Фиксирует прокрутку списка модификаторов. Результат сохраняется, пока
  /// игрок не выберет кость, поэтому закрытие окна не даёт новый результат.
  DiceModifier? rollModifier() {
    if (!_pendingModifierChoice) return null;
    _pendingModifier ??= DiceModifier.values
        .where((modifier) => modifier != DiceModifier.none)
        .toList()[_random.nextInt(3)];
    notifyListeners();
    return _pendingModifier;
  }

  List<int> get modifierTargetIndexes => [
    for (var index = 0; index < _dice.length; index++)
      if (_pendingModifier != null &&
          _canApplyModifier(_dice[index], _pendingModifier!))
        index,
  ];

  static bool _canApplyModifier(Dice dice, DiceModifier modifier) {
    if (modifier == DiceModifier.none || dice.hasModifier(modifier)) {
      return false;
    }
    return !dice.activeModifiers.any((current) => current.conflictsWith(modifier));
  }

  bool applyPendingModifier(int diceIndex) {
    final modifier = _pendingModifier;
    if (modifier == null ||
        diceIndex < 0 ||
        diceIndex >= _dice.length ||
        !_canApplyModifier(_dice[diceIndex], modifier)) {
      return false;
    }
    _dice[diceIndex] = _dice[diceIndex].copyWith(
      modifier: _dice[diceIndex].activeModifiers.isEmpty
          ? modifier
          : _dice[diceIndex].modifier,
      modifiers: {..._dice[diceIndex].activeModifiers, modifier},
    );
    _pendingModifier = null;
    _pendingModifierChoice = false;
    _pendingArtifactChoices = [];
    notifyListeners();
    return true;
  }

  bool consumeDice(Dice dice) {
    final index = _dice.indexOf(dice);
    if (index < 0) return false;
    _dice.removeAt(index);
    notifyListeners();
    return true;
  }

  bool replaceDice(Dice before, Dice? after) {
    final index = _dice.indexOf(before);
    if (index < 0) return false;
    if (after == null) {
      _dice.removeAt(index);
    } else {
      _dice[index] = after;
    }
    notifyListeners();
    return true;
  }

  /// Увеличивает количество свободных мест в хотбаре.
  bool upgradeDicePerTurn() {
    if (_dicePerTurn >= maxDicePerTurn) return false;
    final cost = diceUpgradeCost;
    if (!spendCoins(cost)) return false;
    _dicePerTurn++;
    notifyListeners();
    return true;
  }

  int get dicePerTurnUpgradeCost => diceUpgradeCost;

  bool upgradeRerolls() {
    if (_rerollsPerRound >= maxRerollsPerRound) return false;
    if (!spendCoins(rerollUpgradeCost)) return false;
    _rerollsPerRound++;
    notifyListeners();
    return true;
  }

  bool hasNpcShopAccess(String npcId) =>
      npcId == 'elder' ||
      npcId == 'ariana' ||
      npcId == 'baba_galya' ||
      npcId == 'alenka' ||
      (npcId == 'shaurmek' && hasDefeatedEnemyAt('doner', 'shaurmek'));

  bool canBuyShopItem(String itemId) {
    final item = GameContent.shopItemById(itemId);
    if (item == null || hasPurchasedShopItem(itemId) || coins < item.price) {
      return false;
    }
    final requiredQuest = item.requiredQuestId;
    if (requiredQuest != null &&
        quest(requiredQuest)?.state != QuestState.active) {
      return false;
    }
    final requiredEnemy = item.requiredEnemyId;
    final requiredLocation = item.requiredLocationId;
    if (requiredEnemy != null &&
        requiredLocation != null &&
        !hasDefeatedEnemyAt(requiredLocation, requiredEnemy)) {
      return false;
    }
    if (item.effect == ShopEffect.heal && playerHp >= playerMaxHp) return false;
    return true;
  }

  /// Покупка товара и его эффект выполняются одной операцией, поэтому двойной
  /// клик не может повторно применить одноразовый предмет.
  bool buyShopItem(String itemId) {
    final item = GameContent.shopItemById(itemId);
    if (item == null || !canBuyShopItem(itemId)) return false;
    _coins -= item.price;
    switch (item.effect) {
      case ShopEffect.heal:
        _playerHp = (_playerHp + item.amount).clamp(0, playerMaxHp).toInt();
      case ShopEffect.increaseMaxHp:
        _bonusMaxHp += item.amount;
      case ShopEffect.addItem:
        final itemKey = item.itemId ?? item.id;
        _items[itemKey] = itemCount(itemKey) + 1;
        progressQuests(itemId: itemKey, notify: false);
      case ShopEffect.damage:
        _playerHp = (_playerHp - item.amount).clamp(0, playerMaxHp).toInt();
    }
    _purchasedShopItems.add(itemId);
    notifyListeners();
    return true;
  }

  bool useItem(String itemId) {
    final count = itemCount(itemId);
    if (count <= 0) return false;
    if (count == 1) {
      _items.remove(itemId);
    } else {
      _items[itemId] = count - 1;
    }
    notifyListeners();
    return true;
  }

  bool useInsulin() {
    if (!useItem(insulinSyringeItemId)) return false;
    _tripUntil = DateTime.now().add(tripDuration);
    notifyListeners();
    return true;
  }

  bool removeItem(String itemId) {
    final count = itemCount(itemId);
    if (count <= 0) return false;
    if (count == 1) {
      _items.remove(itemId);
    } else {
      _items[itemId] = count - 1;
    }
    notifyListeners();
    return true;
  }

  /// Объединяет две кости с одинаковой способностью и уровнем.
  bool mergeDice(int firstIndex, int secondIndex) {
    if (firstIndex == secondIndex ||
        firstIndex < 0 ||
        secondIndex < 0 ||
        firstIndex >= _dice.length ||
        secondIndex >= _dice.length) {
      return false;
    }
    final first = _dice[firstIndex];
    final second = _dice[secondIndex];
    if (first.ability != second.ability ||
        first.level != second.level ||
        first.activeModifiers.length != second.activeModifiers.length ||
        !first.activeModifiers.containsAll(second.activeModifiers)) {
      return false;
    }
    if (first.level >= Dice.maxLevel) return false;
    final low = min(firstIndex, secondIndex);
    final high = max(firstIndex, secondIndex);
    _dice.removeAt(high);
    _dice.removeAt(low);
    _dice.add(first.copyWith(level: first.level + 1));
    notifyListeners();
    return true;
  }

  @Deprecated('Используйте mergeDice')
  bool upgradeDice(String diceId) {
    final index = _dice.indexWhere((dice) => dice.id == diceId);
    if (index < 0 || !_dice[index].canUpgrade) return false;
    final cost = 25 * _dice[index].level;
    if (!spendCoins(cost)) return false;
    _dice[index] = _dice[index].copyWith(level: _dice[index].level + 1);
    notifyListeners();
    return true;
  }

  void markEnemyDefeated(String spawnKey) {
    _defeatedEnemyKeys.add(spawnKey);
    _enemyRespawnAt[spawnKey] = DateTime.now().add(enemyRespawnDelay);
    final parts = spawnKey.split(':');
    if (parts.length >= 2) {
      _defeatedEnemyAccess.add('${parts[0]}:${parts[1]}');
    }
    notifyListeners();
  }

  void addDice(Dice dice) {
    _dice.add(dice);
    notifyListeners();
  }

  // --- Поиск объектов ---

  /// Делает один тап по поиску. Ровно десятый тап завершает поиск; следующие
  /// вызовы возвращают тот же результат и не выдают награду повторно.
  SearchResult searchProp(String propId) {
    final prop = Locations.propById(propId);
    if (prop == null || !prop.searchable) {
      return SearchResult(
        propId: propId,
        taps: searchTapCount(propId),
        completed: false,
        accepted: false,
      );
    }

    final previous = _searchResults[propId];
    if (previous != null && previous.completed) return previous;

    final taps = (_searchTaps[propId] ?? 0) + 1;
    _searchTaps[propId] = taps.clamp(0, SearchResult.requiredTaps).toInt();
    if (taps < SearchResult.requiredTaps) {
      final result = SearchResult(propId: propId, taps: taps, completed: false);
      _searchResults[propId] = result;
      notifyListeners();
      return result;
    }

    final result = _completeSearch(prop);
    _searchResults[propId] = result;
    notifyListeners();
    return result;
  }

  SearchResult _completeSearch(LocationProp prop) {
    final syncQuest = _quests['q_sync_async'];
    final hasSyncAsyncQuest =
        syncQuest?.state == QuestState.active &&
        syncQuest?.quest.searchPropId == prop.id &&
        prop.specialItemId == syncQuest?.quest.itemId;
    // Специальный предмет действительно лежит в конкретном кусте. Его можно
    // найти и до разговора с Малёком: тогда он останется в инвентаре, а после
    // принятия задания обычная доставка завершит квест.
    if (prop.specialItemId != null) {
      final itemId = prop.specialItemId!;
      _items[itemId] = itemCount(itemId) + 1;
      if (hasSyncAsyncQuest) {
        progressQuests(itemId: itemId, notify: false);
      }
      return SearchResult(
        propId: prop.id,
        taps: SearchResult.requiredTaps,
        completed: true,
        rewardType: SearchRewardType.item,
        amount: 1,
        itemId: itemId,
      );
    }

    // В кустах добыча небольшая: иногда там вообще ничего нет, а если есть,
    // это только 1–3 HP или +5 монет. Редкие ящики и опыт остаются находками
    // мусорных баков и других будущих searchable-объектов.
    late final (SearchRewardType, int) reward;
    if (prop.kind == LocationPropKind.bush) {
      reward = switch (_random.nextInt(3)) {
        0 => (SearchRewardType.none, 0),
        1 => (
          SearchRewardType.hp,
          _random.nextInt(maxBushHpReward) + 1,
        ),
        _ => (SearchRewardType.coins, 5),
      };
    } else {
      // Ящики должны оставаться редкой находкой: обычный поиск чаще даёт
      // небольшое лечение, монеты или опыт.
      final rareRoll = _random.nextInt(100);
      reward = rareRoll < 2
          ? (SearchRewardType.artifactCase, 1)
          : rareRoll < 4
          ? (SearchRewardType.diceCase, 1)
          : switch (_random.nextInt(3)) {
              0 => (SearchRewardType.hp, 5),
              1 => (SearchRewardType.coins, 5),
              _ => (SearchRewardType.xp, 5),
            };
    }
    switch (reward.$1) {
      case SearchRewardType.hp:
        _playerHp = (_playerHp + reward.$2).clamp(0, playerMaxHp).toInt();
      case SearchRewardType.coins:
        _coins += reward.$2;
        progressQuests(coinsEarned: reward.$2, notify: false);
      case SearchRewardType.xp:
        _addXpSilently(reward.$2);
      case SearchRewardType.artifactCase:
        _cases[CaseType.artifact] = boxCount(CaseType.artifact) + reward.$2;
      case SearchRewardType.diceCase:
        _cases[CaseType.dice] = boxCount(CaseType.dice) + reward.$2;
      case SearchRewardType.item:
      case SearchRewardType.none:
        break;
    }
    return SearchResult(
      propId: prop.id,
      taps: SearchResult.requiredTaps,
      completed: true,
      rewardType: reward.$1,
      amount: reward.$2,
    );
  }

  // --- Квесты ---

  QuestProgress? quest(String id) => _quests[id];

  bool canActivateQuest(String id, {String? npcId, String? propId}) {
    final q = _quests[id];
    if (q == null || q.state != QuestState.notStarted) return false;
    final acceptanceNpcId = q.quest.acceptanceNpcId;
    final acceptancePropId = q.quest.acceptancePropId;
    return (acceptanceNpcId == null || acceptanceNpcId == npcId) &&
        (acceptancePropId == null || acceptancePropId == propId);
  }

  bool activateQuest(String id, {String? npcId, String? propId}) {
    if (!canActivateQuest(id, npcId: npcId, propId: propId)) return false;
    final q = _quests[id]!;
    q.state = QuestState.active;
    notifyListeners();
    return true;
  }

  /// Начисляет прогресс по типу цели. Активируетcompleted-состояние при достижении.
  void progressQuests({
    String? enemyId,
    String? locationId,
    int coinsEarned = 0,
    String? itemId,
    String? miniGameId,
    bool notify = true,
  }) {
    bool changed = false;
    for (final q in _quests.values) {
      if (q.state != QuestState.active) continue;

      switch (q.quest.type) {
        case QuestType.kill:
          if (enemyId != null && q.quest.enemyId == enemyId) {
            q.progress = (q.progress + 1).clamp(0, q.quest.target).toInt();
            changed = true;
          }
        case QuestType.location:
          if (locationId != null && q.quest.locationId == locationId) {
            q.progress = q.quest.target;
            changed = true;
          }
        case QuestType.collect:
          if (coinsEarned > 0) {
            q.progress = (q.progress + coinsEarned)
                .clamp(0, q.quest.target)
                .toInt();
            changed = true;
          }
        case QuestType.deliverItem:
          if (itemId != null && q.quest.itemId == itemId) {
            q.progress = q.quest.target;
            changed = true;
          }
        case QuestType.purchaseItem:
          if (itemId != null && q.quest.itemId == itemId) {
            q.progress = q.quest.target;
            changed = true;
          }
        case QuestType.miniGame:
          if (miniGameId != null && q.quest.miniGameId == miniGameId) {
            q.progress = (q.progress + 1).clamp(0, q.quest.target).toInt();
            changed = true;
          }
      }

      if (q.progress >= q.quest.target &&
          q.quest.type != QuestType.deliverItem) {
        q.state = QuestState.completed;
      }
    }
    if (changed && notify) notifyListeners();
  }

  /// Завершает активную мини-игру и переводит её в состояние награды.
  bool completeMiniGameQuest(String id, {String? miniGameId}) {
    final progress = _quests[id];
    if (progress == null ||
        progress.state != QuestState.active ||
        progress.quest.type != QuestType.miniGame ||
        (miniGameId != null && progress.quest.miniGameId != miniGameId)) {
      return false;
    }
    progress.progress = progress.quest.target;
    progress.state = QuestState.completed;
    notifyListeners();
    return true;
  }

  bool completeSongQuest() =>
      completeMiniGameQuest('q_song', miniGameId: 'song');

  bool completeDeliveryQuest(String id) {
    final progress = _quests[id];
    final itemId = progress?.quest.itemId;
    if (progress == null ||
        progress.state != QuestState.active ||
        progress.quest.type != QuestType.deliverItem ||
        itemId == null ||
        !hasItem(itemId)) {
      return false;
    }
    final count = itemCount(itemId);
    if (count == 1) {
      _items.remove(itemId);
    } else {
      _items[itemId] = count - 1;
    }
    progress.progress = progress.quest.target;
    progress.state = QuestState.completed;
    if (id == 'q_shawarma_for_ilya') _shawarmaOutcome = 'delivered';
    notifyListeners();
    return true;
  }

  /// Фиксирует выбор после покупки шаурмы. Если герой съедает её, доставка
  /// считается альтернативно завершённой и товар удаляется из инвентаря.
  /// Если он оставляет её Илье, квест остаётся активным до разговора с Ильёй.
  bool resolveShawarmaChoice({required bool eat}) {
    final progress = _quests['q_shawarma_for_ilya'];
    if (progress?.state != QuestState.active || !hasItem('shaurma')) {
      return false;
    }
    if (eat) {
      removeItem('shaurma');
      progress!.progress = progress.quest.target;
      progress.state = QuestState.completed;
      _shawarmaOutcome = 'eaten';
    } else {
      _shawarmaOutcome = 'forIlya';
    }
    notifyListeners();
    return true;
  }

  /// Забирает награду за выполненный квест.
  bool claimQuest(String id) {
    final q = _quests[id];
    if (q == null || q.state != QuestState.completed) return false;
    q.state = QuestState.claimed;
    _cases[CaseType.artifact] =
        boxCount(CaseType.artifact) + q.quest.artifactCaseReward;
    _coins += q.quest.coinReward;
    _addXpSilently(q.quest.xpReward);
    final skinRewardId = q.quest.skinRewardId;
    final skinReward = skinRewardId == null
        ? null
        : GameContent.skinById(skinRewardId);
    if (skinReward != null) _ownedSkinIds.add(skinReward.id);
    notifyListeners();
    return true;
  }

  /// Возвращает награды за завершённые задания. Вызывается только из явного
  /// действия игрока «Получить награду».
  int claimCompletedQuests() {
    final completed = _quests.values
        .where((progress) => progress.state == QuestState.completed)
        .map((progress) => progress.quest.id)
        .toList();
    for (final id in completed) {
      claimQuest(id);
    }
    return completed.length;
  }

  // --- Сохранение ---

  Map<String, dynamic> toJson() => {
    'coins': _coins,
    'xp': _xp,
    'level': _level,
    'playerHp': playerHp,
    'bonusMaxHp': _bonusMaxHp,
    'dicePerTurn': dicePerTurn,
    'rerollsPerRound': rerollsPerRound,
    'boxes': {for (final entry in _cases.entries) entry.key.name: entry.value},
    // Старый ключ остаётся для сохранений предыдущих версий.
    'cases': {for (final entry in _cases.entries) entry.key.name: entry.value},
    'artifacts': {
      for (final entry in _artifacts.entries) entry.key.name: entry.value,
    },
    'items': Map<String, int>.from(_items),
    'shawarmaOutcome': _shawarmaOutcome,
    'tripUntil': _tripUntil?.toIso8601String(),
    'purchasedShopItems': _purchasedShopItems.toList(),
    'pendingArtifactChoices': [
      for (final artifact in _pendingArtifactChoices) artifact.name,
    ],
    'pendingModifierChoice': _pendingModifierChoice,
    'pendingModifier': _pendingModifier?.name,
    'pendingDiceReward': _pendingDiceReward == null
        ? null
        : {
            'id': _pendingDiceReward!.id,
            'name': _pendingDiceReward!.name,
            'baseFaces': _pendingDiceReward!.baseFaces,
            'level': _pendingDiceReward!.level,
            'ability': _pendingDiceReward!.ability.name,
            'modifier': _pendingDiceReward!.modifier.name,
            'modifiers': _pendingDiceReward!.activeModifiers
                .map((modifier) => modifier.name)
                .toList(),
            'visualKey': _pendingDiceReward!.visualKey,
          },
    'currentLocationId': _currentLocationId,
    'ownedSkins': _ownedSkinIds.toList(),
    'selectedSkinId': _selectedSkinId,
    'searches': {
      for (final entry in _searchResults.entries)
        entry.key: {
          'taps': _searchTaps[entry.key] ?? entry.value.taps,
          'completed': entry.value.completed,
          'accepted': entry.value.accepted,
          'rewardType': entry.value.rewardType.name,
          'amount': entry.value.amount,
          'itemId': entry.value.itemId,
        },
    },
    'defeatedEnemies': [
      for (final key in _defeatedEnemyKeys.toList())
        if (enemyRespawnRemaining(key) != null) key,
    ],
    'defeatedEnemyAccess': _defeatedEnemyAccess.toList(),
    'enemyRespawns': {
      for (final key in _enemyRespawnAt.keys.toList())
        if (enemyRespawnRemaining(key) != null)
          key: _enemyRespawnAt[key]!.toIso8601String(),
    },
    'dice': _dice
        .map(
          (d) => {
            'id': d.id,
            'name': d.name,
            'baseFaces': d.baseFaces,
            'level': d.level,
            'ability': d.ability.name,
            'modifier': d.modifier.name,
            'modifiers': d.activeModifiers
                .map((modifier) => modifier.name)
                .toList(),
            'visualKey': d.visualKey,
          },
        )
        .toList(),
    'quests': _quests.map(
      (key, value) => MapEntry(key, {
        'state': value.state.name,
        'progress': value.progress,
      }),
    ),
  };

  static Dice? _diceFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final template = GameContent.diceById(id);
    final ability = DiceAbility.values.where(
      (candidate) => candidate.name == raw['ability']?.toString(),
    );
    final modifier = DiceModifier.values.where(
      (candidate) => candidate.name == raw['modifier']?.toString(),
    );
    final savedModifiers = <DiceModifier>{};
    final rawModifiers = raw['modifiers'];
    if (rawModifiers is List) {
      for (final value in rawModifiers) {
        final saved = DiceModifier.values.where(
          (candidate) => candidate.name == value.toString(),
        );
        if (saved.isNotEmpty && saved.first != DiceModifier.none) {
          savedModifiers.add(saved.first);
        }
      }
    }
    final rawFaces = raw['baseFaces'];
    final baseFaces = rawFaces is List
        ? rawFaces.whereType<int>().toList()
        : (template?.baseFaces ?? const [1, 2, 3, 4, 5, 6]);
    return Dice(
      id: id,
      name: raw['name']?.toString() ?? template?.name ?? id,
      baseFaces: baseFaces,
      level: (raw['level'] as int? ?? 1).clamp(1, Dice.maxLevel).toInt(),
      ability: ability.isEmpty
          ? template?.ability ?? DiceAbility.none
          : ability.first,
      modifier: modifier.isEmpty ? DiceModifier.none : modifier.first,
      modifiers: savedModifiers,
      visualKey: raw['visualKey']?.toString() ?? template?.visualKey ?? 'blade',
    );
  }

  void fromJson(Map<String, dynamic> json) {
    _cases.clear();
    final cases = (json['boxes'] as Map?) ?? (json['cases'] as Map?) ?? const {};
    for (final type in CaseType.values) {
      _cases[type] = max(0, (cases[type.name] as int?) ?? 0);
    }
    _artifacts.clear();
    final artifacts = json['artifacts'] as Map? ?? const {};
    for (final artifact in Artifact.values) {
      final count = (artifacts[artifact.name] as int?) ?? 0;
      if (count > 0) {
        _artifacts[artifact] = artifact.stackable ? count : 1;
      }
    }
    final pending = json['pendingArtifactChoices'] as List? ?? const [];
    _pendingArtifactChoices = Artifact.values
        .where((artifact) => pending.contains(artifact.name))
        .take(3)
        .toList();
    _pendingModifierChoice = json['pendingModifierChoice'] == true;
    final pendingModifierName = json['pendingModifier']?.toString();
    final pendingModifierValues = DiceModifier.values.where(
      (modifier) => modifier.name == pendingModifierName,
    );
    _pendingModifier = pendingModifierValues.isEmpty
        ? null
        : pendingModifierValues.first;
    if (_pendingModifier != null) _pendingModifierChoice = true;
    _pendingDiceReward = null;
    _coins = json['coins'] as int? ?? 50;
    _xp = json['xp'] as int? ?? 0;
    _level = json['level'] as int? ?? 1;
    _bonusMaxHp = (json['bonusMaxHp'] as int? ?? 0).clamp(0, 1000).toInt();
    _playerHp = (json['playerHp'] as int? ?? playerMaxHp)
        .clamp(0, playerMaxHp)
        .toInt();
    _dicePerTurn = (json['dicePerTurn'] as int? ?? 1)
        .clamp(1, maxDicePerTurn)
        .toInt();
    _rerollsPerRound = (json['rerollsPerRound'] as int? ?? 1)
        .clamp(1, maxRerollsPerRound)
        .toInt();
    _items.clear();
    final itemsJson = json['items'];
    if (itemsJson is Map) {
      for (final entry in itemsJson.entries) {
        final count = entry.value is int ? entry.value as int : 0;
        if (count > 0) _items[entry.key.toString()] = count;
      }
    }
    final shawarmaOutcome = json['shawarmaOutcome']?.toString();
    _shawarmaOutcome =
        const {'eaten', 'forIlya', 'delivered'}.contains(shawarmaOutcome)
        ? shawarmaOutcome
        : null;
    final tripUntil = DateTime.tryParse(json['tripUntil']?.toString() ?? '');
    _tripUntil = tripUntil != null && tripUntil.isAfter(DateTime.now())
        ? tripUntil
        : null;
    _purchasedShopItems
      ..clear()
      ..addAll(
        (json['purchasedShopItems'] as List?)?.whereType<String>() ?? const [],
      );
    final savedLocationId = json['currentLocationId'] as String?;
    _currentLocationId =
        savedLocationId != null && Locations.byId(savedLocationId) != null
        ? savedLocationId
        : 'meadow';

    _ownedSkinIds
      ..clear()
      ..add(PlayerSkin.defaultSkin.id);
    final ownedSkins = json['ownedSkins'] as List?;
    for (final skinId in ownedSkins?.whereType<String>() ?? const <String>[]) {
      final skin = GameContent.skinById(skinId);
      if (skin != null) _ownedSkinIds.add(skin.id);
    }
    final selectedSkinId = json['selectedSkinId'] as String?;
    final selectedSkin = selectedSkinId == null
        ? null
        : GameContent.skinById(selectedSkinId);
    _selectedSkinId = selectedSkin != null && hasSkin(selectedSkin.id)
        ? selectedSkin.id
        : PlayerSkin.defaultSkin.id;

    _searchTaps.clear();
    _searchResults.clear();
    final searches = json['searches'];
    if (searches is Map) {
      for (final entry in searches.entries) {
        final propId = entry.key.toString();
        final data = entry.value;
        if (data is! Map || Locations.propById(propId) == null) continue;
        final taps = ((data['taps'] as int?) ?? 0)
            .clamp(0, SearchResult.requiredTaps)
            .toInt();
        final completed =
            data['completed'] == true || taps >= SearchResult.requiredTaps;
        final rewardTypeName = data['rewardType']?.toString();
        final rewardType = SearchRewardType.values.firstWhere(
          (candidate) => candidate.name == rewardTypeName,
          orElse: () => SearchRewardType.none,
        );
        final result = SearchResult(
          propId: propId,
          taps: taps,
          completed: completed,
          accepted: data['accepted'] != false,
          rewardType: rewardType,
          amount: (data['amount'] as int?) ?? 0,
          itemId: data['itemId'] as String?,
        );
        _searchTaps[propId] = taps;
        _searchResults[propId] = result;
      }
    }

    final now = DateTime.now();
    _defeatedEnemyKeys = {};
    _enemyRespawnAt = {};
    _defeatedEnemyAccess
      ..clear()
      ..addAll(
        (json['defeatedEnemyAccess'] as List?)?.whereType<String>() ?? const [],
      );
    final respawns = json['enemyRespawns'] as Map?;
    if (respawns != null) {
      for (final entry in respawns.entries) {
        final value = DateTime.tryParse(entry.value.toString());
        if (value != null && value.isAfter(now)) {
          final key = entry.key.toString();
          _defeatedEnemyKeys.add(key);
          _enemyRespawnAt[key] = value;
          final parts = key.split(':');
          if (parts.length >= 2) {
            _defeatedEnemyAccess.add('${parts[0]}:${parts[1]}');
          }
        }
      }
    }
    // Старые сохранения хранили только факт победы. Даем таким записям
    // честное пятиминутное окно вместо вечного исчезновения врага.
    final defeated = json['defeatedEnemies'] as List?;
    for (final key in defeated?.whereType<String>() ?? const <String>[]) {
      if (_enemyRespawnAt.containsKey(key)) continue;
      _defeatedEnemyKeys.add(key);
      _enemyRespawnAt[key] = now.add(enemyRespawnDelay);
      final parts = key.split(':');
      if (parts.length >= 2) {
        _defeatedEnemyAccess.add('${parts[0]}:${parts[1]}');
      }
    }

    final diceJson = json['dice'] as List?;
    if (diceJson != null) {
      _dice = [];
      for (final raw in diceJson) {
        final dice = _diceFromJson(raw);
        if (dice != null) _dice.add(dice);
      }
      if (_dice.isEmpty) _dice = List.of(GameContent.starterInventory);
    }
    _pendingDiceReward = _diceFromJson(json['pendingDiceReward']);

    // Полностью пересоздаём карту: неполный или старый JSON не должен
    // оставлять в памяти состояние задания от предыдущего сейва.
    _quests = {
      for (final q in GameContent.quests) q.id: QuestProgress(quest: q),
    };
    final questsJson = json['quests'];
    if (questsJson is Map) {
      for (final entry in questsJson.entries) {
        final q = _quests[entry.key.toString()];
        final data = entry.value;
        if (q == null || data is! Map) continue;
        final stateName = data['state']?.toString();
        final state = QuestState.values.where(
          (candidate) => candidate.name == stateName,
        );
        q.state = state.isEmpty ? QuestState.notStarted : state.first;
        final rawProgress = data['progress'];
        final progress = rawProgress is int ? rawProgress : 0;
        q.progress = progress.clamp(0, q.quest.target).toInt();
        if (q.state == QuestState.completed && q.progress < q.quest.target) {
          q.progress = q.quest.target;
        }
      }
    }
    notifyListeners();
  }

  /// Полностью возвращает прогресс к состоянию новой игры.
  void reset() {
    _resetValues();
    notifyListeners();
  }

  void _resetValues() {
    _cases.clear();
    _artifacts.clear();
    _items.clear();
    _defeatedEnemyAccess.clear();
    _shawarmaOutcome = null;
    _tripUntil = null;
    _purchasedShopItems.clear();
    _pendingArtifactChoices = [];
    _pendingModifierChoice = false;
    _pendingModifier = null;
    _pendingDiceReward = null;
    _ownedSkinIds
      ..clear()
      ..add(PlayerSkin.defaultSkin.id);
    _selectedSkinId = PlayerSkin.defaultSkin.id;
    _searchTaps.clear();
    _searchResults.clear();
    _coins = 50;
    _xp = 0;
    _level = 1;
    _playerHp = 30;
    _bonusMaxHp = 0;
    _dicePerTurn = 1;
    _rerollsPerRound = 1;
    _currentLocationId = 'meadow';
    _dice = List.of(GameContent.starterInventory);
    _defeatedEnemyKeys = {};
    _enemyRespawnAt = {};
    _quests = {
      for (final q in GameContent.quests) q.id: QuestProgress(quest: q),
    };
  }

  Future<void> _saveQueue = Future.value();

  Future<void> save(String saveDir) {
    final snapshot = jsonEncode(toJson());
    // Открытие ящика и выбор награды могут вызвать два сейва подряд.
    // Пишем последовательно, чтобы старый снимок не затёр новый.
    final operation = _saveQueue.then((_) async {
      final file = File(p.join(saveDir, 'save.json'));
      await file.create(recursive: true);
      await file.writeAsString(snapshot, flush: true);
    });
    _saveQueue = operation.catchError((Object error) {
      debugPrint('Не удалось сохранить прогресс: $error');
    });
    return operation;
  }

  Future<bool> load(String saveDir) async {
    try {
      final file = File(p.join(saveDir, 'save.json'));
      if (!await file.exists()) return false;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      fromJson(json);
      return true;
    } catch (e) {
      debugPrint('Не удалось загрузить сохранение: $e');
      return false;
    }
  }

  Future<void> clearSave(String saveDir) async {
    await _saveQueue;
    try {
      final file = File(p.join(saveDir, 'save.json'));
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Не удалось стереть сохранение: $e');
    }
  }
}

/// Прогресс по конкретному квесту.
class QuestProgress extends ChangeNotifier {
  QuestProgress({required this.quest});

  final Quest quest;
  QuestState state = QuestState.notStarted;
  int progress = 0;

  double get progressFraction => quest.target == 0
      ? 0
      : (progress / quest.target).clamp(0.0, 1.0).toDouble();
}

enum SearchRewardType { none, hp, coins, xp, artifactCase, diceCase, item }

/// Результат одного шага или завершённого поиска объекта.
@immutable
class SearchResult {
  const SearchResult({
    required this.propId,
    required this.taps,
    required this.completed,
    this.accepted = true,
    this.rewardType = SearchRewardType.none,
    this.amount = 0,
    this.itemId,
  });

  static const int requiredTaps = 10;

  final String propId;
  final int taps;
  final bool completed;
  final bool accepted;
  final SearchRewardType rewardType;
  final int amount;
  final String? itemId;

  bool get isComplete => completed;
  bool get isCompleted => completed;
  int get progress => taps;
  int get tapCount => taps;
  SearchRewardType get reward => rewardType;
  int get rewardAmount => amount;
  String? get specialItemId => itemId;
  bool get foundSpecialItem => itemId != null;
}
