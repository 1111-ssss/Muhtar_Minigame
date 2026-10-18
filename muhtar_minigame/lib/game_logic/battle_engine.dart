import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/dice.dart';
import '../domain/artifact.dart';
import '../domain/equipment.dart';

/// Максимальное количество щита, которое может одновременно иметь враг.
const maxEnemyShield = 8;

@immutable
class RolledDie {
  const RolledDie({required this.dice, required this.value});

  final Dice dice;
  final int value;
}

/// Намерение известно до расстановки игрока и не меняется при рероллах.
@immutable
class TurnEffects {
  const TurnEffects({
    this.attack = 0,
    this.attackHits = 1,
    this.shield = 0,
    this.heal = 0,
    this.burn = 0,
  });

  final int attack;
  final int attackHits;
  final int shield;
  final int heal;
  final int burn;

  TurnEffects copyWith({
    int? attack,
    int? attackHits,
    int? shield,
    int? heal,
    int? burn,
  }) => TurnEffects(
    attack: attack ?? this.attack,
    attackHits: attackHits ?? this.attackHits,
    shield: shield ?? this.shield,
    heal: heal ?? this.heal,
    burn: burn ?? this.burn,
  );
}

@immutable
class BattlePreview {
  const BattlePreview({
    this.outgoingDamage = 0,
    this.outgoingDamagePerHit = 0,
    this.outgoingHits = 0,
    this.incomingDamage = 0,
    this.incomingDamagePerHit = 0,
    this.incomingHits = 0,
    this.shield = 0,
    this.availableShield = 0,
    this.blockedDamage = 0,
    this.healing = 0,
    this.burnApplied = 0,
  });

  final int outgoingDamage;
  final int outgoingDamagePerHit;
  final int outgoingHits;
  final int incomingDamage;
  final int incomingDamagePerHit;
  final int incomingHits;

  /// Полный щит, который будет добавлен в начале этого раунда.
  ///
  /// Это намерение отличается от [blockedDamage]: последний показывает,
  /// сколько фактического входящего урона поглотит щит и потому может быть
  /// меньше полного значения щита.
  final int shield;

  /// Щит, который будет доступен после добавления нового щита этого раунда.
  final int availableShield;
  final int blockedDamage;
  final int healing;
  final int burnApplied;
}

enum BattleEventType { shield, attack, blocked, damage, burn, heal }

/// Одно визуально значимое действие раунда. Расчёт боя остаётся синхронным,
/// а UI проигрывает этот список по одному событию, чтобы игрок видел причинно-
/// следственную цепочку: удар → блок → урон → лечение.
@immutable
class BattleEvent {
  const BattleEvent({
    required this.sequence,
    required this.type,
    required this.source,
    required this.target,
    required this.amount,
    this.hits = 1,
  });

  final int sequence;
  final BattleSide source;
  final BattleEventType type;
  final BattleSide target;
  final int amount;
  final int hits;
}

enum BattleSide { player, enemy }

class Fighter {
  Fighter({
    required this.name,
    required this.maxHp,
    List<Dice> dice = const [],
    this.isPlayer = false,
    int? initialHp,
    this.attackFaces = const [],
    this.baseAttack = 0,
    int attackHits = 1,
    this.baseShield = 0,
    this.shieldChance = .5,
    this.baseHealing = 0,
    this.healingChance = 1,
    this.hideStats = false,
    this.actsFirst = false,
    this.burnDamage = 0,
    this.appearance = 'player',
    this.attackPhrases = const [],
    this.equipment = const [],
    int initialShield = 0,
    int rootCells = 0,
  }) : dice = List<Dice>.from(dice),
       hp = (initialHp ?? maxHp).clamp(0, maxHp).toInt(),
       shield = isPlayer
           ? initialShield
           : initialShield.clamp(0, maxEnemyShield).toInt(),
       rootCells = rootCells.clamp(0, 9).toInt(),
       attackHits = attackHits.clamp(1, 99).toInt();

  final String name;
  final int maxHp;
  final List<Dice> dice;
  final bool isPlayer;
  final List<int> attackFaces;
  final int baseAttack;
  final int attackHits;
  final int baseShield;
  final double shieldChance;
  final int baseHealing;
  final double healingChance;
  final bool hideStats;
  final bool actsFirst;
  final int burnDamage;
  final String appearance;
  final List<String> attackPhrases;
  final List<EquipmentSlot> equipment;
  final int rootCells;
  String attackPhrase = '';
  int hp;
  int shield;
  int burn = 0;
  int poison = 0;
  bool get isDead => hp <= 0;
}

/// Один раунд: пополнить пустые места → расставить кости → разыграть обе
/// атаки в порядке инициативы → вылечить выживших. UI не управляет ходом ИИ.
class BattleEngine extends ChangeNotifier {
  BattleEngine({
    required this.player,
    required this.enemy,
    int playerDiceCount = 1,
    int playerRerollsPerRound = 1,
    Map<Artifact, int> artifacts = const {},
    this.onDiceConsumed,
    this.onDiceChanged,
    Random? random,
  }) : hotbarSize = playerDiceCount.clamp(1, 3).toInt(),
       rerollsPerRound =
            (playerRerollsPerRound +
                    _normalizedArtifactCount(artifacts, Artifact.luckyCharm))
                .clamp(0, 6)
                .toInt(),
        artifacts = Map.unmodifiable(_normalizeArtifacts(artifacts)),
        _random = random ?? Random() {
    _hotbar = List.filled(hotbarSize, null);
  }

  final Fighter player;
  final Fighter enemy;
  final Map<Artifact, int> artifacts;
  int playerHitVersion = 0;
  int enemyHitVersion = 0;
  int lastPlayerDamage = 0;
  int lastEnemyDamage = 0;
  final int hotbarSize;
  final int rerollsPerRound;
  final void Function(Dice dice)? onDiceConsumed;
  final void Function(Dice before, Dice? after)? onDiceChanged;
  final Random _random;
  late final List<RolledDie?> _hotbar;
  final List<RolledDie?> _board = List.filled(9, null);
  final List<MapEntry<int, RolledDie>> _glassDice = [];
  final Set<int> _rootedCells = <int>{};
  final Set<int> _cancelledCells = <int>{};
  final Map<String, int> _legacyAssignments = {};
  List<BattleEvent> lastEvents = const [];
  List<RolledDie?> get hotbar => List.unmodifiable(_hotbar);
  List<RolledDie?> get board => List.unmodifiable(_board);
  Set<int> get rootedCells => Set.unmodifiable(_rootedCells);
  Set<int> get cancelledCells => Set.unmodifiable(_cancelledCells);
  bool get healingDieDrawn => _healingDieDrawn;

  static int _normalizedArtifactCount(
    Map<Artifact, int> artifacts,
    Artifact artifact,
  ) {
    final count = artifacts[artifact] ?? 0;
    return count <= 0 ? 0 : artifact.stackable ? count : 1;
  }

  static Map<Artifact, int> _normalizeArtifacts(
    Map<Artifact, int> artifacts,
  ) => {
    for (final entry in artifacts.entries)
      if (entry.value > 0)
        entry.key: _normalizedArtifactCount(artifacts, entry.key),
  };

  bool isCellRooted(int cell) => _rootedCells.contains(cell);
  bool isCellCancelled(int cell) => _cancelledCells.contains(cell);

  TurnEffects _enemyIntent = const TurnEffects();
  TurnEffects get enemyIntent => _enemyIntent;
  int round = 1;
  int rerollsRemaining = 0;
  static const int maxEnergy = 2;
  int energy = 0;
  bool _healingDieDrawn = false;
  bool _started = false;
  bool _over = false;
  bool _rootResolutionPrepared = false;
  bool get isOver => _over;
  bool get canAct => _started && !_over;
  bool get isPlayerTurn => true;
  List<RolledDie> get playerHotbar => [for (final die in _hotbar) ?die];
  Set<int> get usedPlayerDice => {
    for (var i = 0; i < _hotbar.length; i++)
      if (_hotbar[i] == null) i,
  };
  List<RolledDie> get rolledDice => [for (final die in _hotbar) ?die];
  List<int> get rolledValues => [for (final die in rolledDice) die.value];
  Fighter get currentFighter => player;
  Map<String, int> get assignments => _legacyAssignments;
  Set<int> get usedDice => _legacyAssignments.values.toSet();

  void startTurn() {
    if (_started || _over) return;
    _started = true;
    _prepareRound();
    notifyListeners();
  }

  RolledDie? _drawDie({Iterable<RolledDie?> excluded = const []}) {
    final excludedIds = {
      for (final die in excluded)
        if (die != null) die.dice.id,
    };
    final candidates = _availableDice
        .where((die) => !excludedIds.contains(die.id))
        .toList();
    if (candidates.isEmpty) return null;
    final die = candidates[_random.nextInt(candidates.length)];
    if (die.ability == DiceAbility.doctor) _healingDieDrawn = true;
    return _rollDie(die);
  }

  RolledDie _rollDie(Dice die) {
    final faces = die.rollFaces;
    return RolledDie(
      dice: die,
      value: faces[_random.nextInt(faces.length)],
    );
  }

  List<Dice> get _availableDice => [
    for (final dice in player.dice)
      if ((!_healingDieDrawn || dice.ability != DiceAbility.doctor) &&
          !_board.any((rolled) => identical(rolled?.dice, dice)))
        dice,
  ];

  void _prepareRound() {
    // Энергия не накапливается: каждый новый раунд начинается ровно с двух.
    energy = maxEnergy;
    _rootedCells.clear();
    _cancelledCells.clear();
    _rootResolutionPrepared = false;
    final drawnSources = <String>{
      for (final die in _hotbar)
        if (die != null) die.dice.id,
    };
    for (var index = 0; index < hotbarSize; index++) {
      if (_hotbar[index] == null && _availableDice.isNotEmpty) {
        final candidates = _availableDice
            .where((dice) => !drawnSources.contains(dice.id))
            .toList();
        if (candidates.isEmpty) break;
        final source = candidates[_random.nextInt(candidates.length)];
        drawnSources.add(source.id);
        if (source.ability == DiceAbility.doctor) _healingDieDrawn = true;
        _hotbar[index] = _rollDie(source);
      }
    }
    rerollsRemaining = rerollsPerRound;
    final attack = enemy.attackFaces.isEmpty
        ? enemy.baseAttack
        : enemy.attackFaces[_random.nextInt(enemy.attackFaces.length)];
    final shield = min(
      max(0, maxEnemyShield - enemy.shield),
      max(0, enemy.baseShield),
    );
    final shieldProbability = shield > 0
        ? enemy.shieldChance.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final healProbability = enemy.baseHealing > 0
        ? enemy.healingChance.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final attackIntent = TurnEffects(
      attack: attack,
      attackHits: enemy.attackHits,
      burn: enemy.burnDamage,
    );
    if (shieldProbability == 0 && healProbability == 0) {
      _enemyIntent = attackIntent;
    } else {
      final actionRoll = _random.nextDouble();
      final healThreshold =
          shieldProbability + (1 - shieldProbability) * healProbability;
      // Враг выбирает ровно одно действие. Вероятность щита — фактическая,
      // а лечение получает оставшееся после щита окно случайного броска.
      _enemyIntent = actionRoll < shieldProbability
          ? TurnEffects(shield: shield)
          : actionRoll < healThreshold
          ? TurnEffects(heal: enemy.baseHealing)
          : attackIntent;
    }
    enemy.attackPhrase = _attackPhraseForRound();
    player.attackPhrase = _playerAttackPhraseForRound();
  }

  /// Chooses Victor's cells after the player has finished placing dice.
  ///
  /// The selection deliberately samples the whole board, including occupied
  /// cells. Occupied cells are remembered separately so the UI can show the
  /// cancelled dice during the root animation while [playerIntent] excludes
  /// them from the round's resolution.
  Set<int> prepareEndTurn() {
    if (!canAct || _rootResolutionPrepared) return rootedCells;
    _chooseRootedCells();
    _cancelledCells.addAll(
      _rootedCells.where((cell) => _board[cell] != null),
    );
    _rootResolutionPrepared = true;
    notifyListeners();
    return rootedCells;
  }

  void _chooseRootedCells() {
    _rootedCells.clear();
    if (enemy.rootCells == 0) return;
    final cells = List<int>.generate(_board.length, (index) => index)
      ..shuffle(_random);
    _rootedCells.addAll(cells.take(enemy.rootCells));
  }

  String _attackPhraseForRound() {
    if (enemy.attackPhrases.isEmpty) return '';
    final phraseIndex = (round - 1) % enemy.attackPhrases.length;
    return enemy.attackPhrases[phraseIndex];
  }

  String _playerAttackPhraseForRound() {
    if (player.attackPhrases.isEmpty) return '';
    final phraseIndex = (round - 1) % player.attackPhrases.length;
    return player.attackPhrases[phraseIndex];
  }

  /// Проверяет, хватает ли энергии на размещение выбранного броска.
  bool canPlaceDie(int hotbarIndex) {
    if (!canAct ||
        hotbarIndex < 0 ||
        hotbarIndex >= hotbarSize ||
        _hotbar[hotbarIndex] == null) {
      return false;
    }
    return energy >= _energyCost(_hotbar[hotbarIndex]!);
  }

  static int _energyCost(RolledDie die) =>
      die.dice.hasModifier(DiceModifier.light) ? 0 : 1;

  /// Установка сразу расходует бросок: слот хотбара остаётся пустым до
  /// следующего раунда. Легкий не расходует энергию, Стекло срабатывает сразу.
  bool placeDie(int hotbarIndex, int cell) {
    if (!canAct ||
        !_validCell(cell) ||
        isCellRooted(cell) ||
        hotbarIndex < 0 ||
        hotbarIndex >= hotbarSize ||
        _board[cell] != null ||
        _hotbar[hotbarIndex] == null ||
        !canPlaceDie(hotbarIndex)) {
      return false;
    }
    final die = _hotbar[hotbarIndex]!;
    energy -= _energyCost(die);
    _hotbar[hotbarIndex] = null;
    if (die.dice.hasModifier(DiceModifier.glass)) {
      _glassDice.add(MapEntry(cell, die));
      final inventoryIndex = player.dice.indexOf(die.dice);
      if (inventoryIndex >= 0) player.dice.removeAt(inventoryIndex);
      onDiceConsumed?.call(die.dice);
    } else {
      _board[cell] = die;
    }
    notifyListeners();
    return true;
  }

  // Compatibility helpers for the original prototype API.
  bool assignDie(String slotId, int diceIndex) {
    if (diceIndex < 0 || diceIndex >= rolledDice.length) return false;
    final cell = int.tryParse(slotId.replaceFirst('board_', ''));
    if (cell != null && slotId.startsWith('board_')) {
      final hotbarIndex = _hotbar.indexWhere(
        (die) =>
            die != null &&
            die.value == rolledDice[diceIndex].value &&
            die.dice == rolledDice[diceIndex].dice,
      );
      return hotbarIndex < 0 ? false : placeDie(hotbarIndex, cell);
    }
    _legacyAssignments[slotId] = diceIndex;
    notifyListeners();
    return true;
  }

  void unassignDie(String slotId) {
    _legacyAssignments.remove(slotId);
    notifyListeners();
  }

  bool assignDieForAi(String slotId, int diceIndex) =>
      assignDie(slotId, diceIndex);

  bool surrender() {
    if (_over) return false;
    player.hp = 0;
    _over = true;
    notifyListeners();
    return true;
  }

  bool rerollPlayerHotbar() {
    for (var index = 0; index < _hotbar.length; index++) {
      if (_hotbar[index] != null && rerollDie(index)) return true;
    }
    return false;
  }

  RolledDie? playerDieAt(String slotId) {
    final cell = int.tryParse(slotId.replaceFirst('board_', ''));
    if (cell == null || !_validCell(cell)) return null;
    return _board[cell];
  }

  int? playerEffectiveValueAt(String slotId) {
    final cell = int.tryParse(slotId.replaceFirst('board_', ''));
    if (cell == null || !_validCell(cell) || _board[cell] == null) return null;
    return effectiveValueAt(cell);
  }

  bool isUpgradeTarget(String slotId) {
    final cell = int.tryParse(slotId.replaceFirst('board_', ''));
    if (cell == null) return false;
    for (var source = 0; source < 9; source++) {
      final die = _board[source];
      if (_cancelledCells.contains(source)) continue;
      if (die?.dice.ability == DiceAbility.upgrade &&
          upgradeTargets(source, die!.dice.level).contains(cell)) {
        return true;
      }
    }
    for (final entry in _glassDice) {
      if (_cancelledCells.contains(entry.key)) continue;
      final die = entry.value;
      if (die.dice.ability == DiceAbility.upgrade &&
          upgradeTargets(entry.key, die.dice.level).contains(cell)) {
        return true;
      }
    }
    return false;
  }

  bool moveDie(int from, int to) {
    if (!canAct ||
        !_validCell(from) ||
        !_validCell(to) ||
        isCellRooted(to) ||
        from == to ||
        _board[from] == null ||
        _isLocked(_board[from]!) ||
        (_board[to] != null && _isLocked(_board[to]!))) {
      return false;
    }
    final other = _board[to];
    _board[to] = _board[from];
    _board[from] = other;
    notifyListeners();
    return true;
  }

  /// Снимает кость с доски и возвращает тот же бросок в первый свободный слот
  /// хотбара. Значение не перебрасывается: игрок может спокойно переставить
  /// кость, не теряя удачный результат.
  bool removeDie(int cell) {
    if (!canAct ||
        !_validCell(cell) ||
        _board[cell] == null ||
        _isLocked(_board[cell]!)) {
      return false;
    }
    final die = _board[cell]!;
    final freeSlot = _hotbar.indexWhere((die) => die == null);
    if (freeSlot < 0) return false;
    _hotbar[freeSlot] = die;
    _board[cell] = null;
    energy = min(maxEnergy, energy + _energyCost(die));
    notifyListeners();
    return true;
  }

  /// Одна попытка заменяет один выбранный бросок случайным из инвентаря.
  bool rerollDie(int hotbarIndex) {
    if (!canAct ||
        rerollsRemaining == 0 ||
        _availableDice.isEmpty ||
        hotbarIndex < 0 ||
        hotbarIndex >= hotbarSize ||
        _hotbar[hotbarIndex] == null) {
      return false;
    }
    final replacement = _drawDie(
      excluded: [
        for (var index = 0; index < _hotbar.length; index++)
          if (index != hotbarIndex) _hotbar[index],
      ],
    );
    if (replacement == null) return false;
    _hotbar[hotbarIndex] = replacement;
    rerollsRemaining--;
    notifyListeners();
    return true;
  }

  static bool _validCell(int cell) => cell >= 0 && cell < 9;

  static bool _isLocked(RolledDie die) =>
      die.dice.hasModifier(DiceModifier.heavy);

  /// Фиксированный приоритет клеток: сначала соседи, затем дальние клетки.
  /// Пустые позиции не заменяются другими целями. Число целей по уровням:
  /// 8, 6, 4, 3, 2, 1. Положение и уровень определяют зону до расстановки.
  static const _targetOrder = [
    [1, 3, 4, 2, 6, 5, 7, 8],
    [4, 0, 2, 3, 5, 7, 6, 8],
    [1, 5, 4, 0, 8, 3, 7, 6],
    [4, 0, 6, 1, 7, 5, 2, 8],
    [1, 5, 7, 3, 0, 2, 8, 6],
    [4, 2, 8, 1, 7, 3, 0, 6],
    [3, 7, 4, 0, 8, 1, 5, 2],
    [4, 6, 8, 3, 5, 1, 0, 2],
    [5, 7, 4, 2, 6, 1, 3, 0],
  ];

  static List<int> upgradeTargets(int cell, int level) {
    if (!_validCell(cell)) return const [];
    const counts = [8, 6, 4, 3, 2, 1];
    return _targetOrder[cell]
        .take(counts[level.clamp(1, 6).toInt() - 1])
        .toList();
  }

  Set<int> get upgradeTargetCells {
    final targets = <int>{};
    for (var source = 0; source < _board.length; source++) {
      final die = _board[source];
      if (_cancelledCells.contains(source)) continue;
      if (die?.dice.ability == DiceAbility.upgrade) {
        targets.addAll(upgradeTargets(source, die!.dice.level));
      }
    }
    for (final entry in _glassDice) {
      if (_cancelledCells.contains(entry.key)) continue;
      final die = entry.value;
      if (die.dice.ability == DiceAbility.upgrade) {
        targets.addAll(upgradeTargets(entry.key, die.dice.level));
      }
    }
    return Set.unmodifiable(targets);
  }

  /// Усиление только на этот раунд. Каждая кость улучшения добавляет к целевой
  /// кости своё текущее выпавшее значение; верхнего ограничения в 6 нет.
  /// Поэтому несколько улучшателей на одной ячейке складываются: 6 + 2 = 8,
  /// а 6 + 2 + 3 = 11.
  int effectiveValueAt(int cell) {
    if (!_validCell(cell) || _board[cell] == null) return 0;
    final target = _board[cell]!;
    return _effectiveValueFor(cell, target);
  }

  int _effectiveValueFor(int cell, RolledDie target) {
    if (target.dice.ability == DiceAbility.upgrade) return target.value;
    var value = target.value;
    for (var source = 0; source < 9; source++) {
      final die = _board[source];
      if (_cancelledCells.contains(source) ||
          die == null ||
          die.dice.ability != DiceAbility.upgrade) {
        continue;
      }
      if (upgradeTargets(source, die.dice.level).contains(cell)) {
        value += die.value;
      }
    }
    for (final entry in _glassDice) {
      final die = entry.value;
      if (_cancelledCells.contains(entry.key)) continue;
      if (die.dice.ability == DiceAbility.upgrade &&
          upgradeTargets(entry.key, die.dice.level).contains(cell)) {
        value += die.value;
      }
    }
    return value;
  }

  /// Уровень кости из инвентаря.
  ///
  /// Кость улучшения усиливает только текущий бросок через
  /// [effectiveValueAt]. Она не должна превращать временный бонус броска в
  /// новый уровень Dice: постоянный уровень по-прежнему берётся из
  /// [RolledDie.dice] и меняется только в инвентаре.
  int effectiveLevelAt(int cell) {
    if (!_validCell(cell) || _board[cell] == null) return 0;
    return _board[cell]!.dice.level;
  }

  int? hotbarIndexForDie(RolledDie die) {
    for (var index = 0; index < _hotbar.length; index++) {
      if (identical(_hotbar[index], die)) return index;
    }
    return null;
  }

  TurnEffects get playerIntent {
    var attack = 0;
    var shield = player.shield <= 0
        ? 2 * (artifacts[Artifact.ironThread] ?? 0)
        : 0;
    var heal = 2 * (artifacts[Artifact.fieldKit] ?? 0);
    var burn = 0;
    void applyDie(int cell, RolledDie die) {
      final value = _board[cell] == die
          ? effectiveValueAt(cell)
          : _effectiveValueFor(cell, die);
      switch (die.dice.ability) {
        case DiceAbility.none:
        case DiceAbility.warrior:
          attack += value + (artifacts[Artifact.whetstone] ?? 0);
        case DiceAbility.doctor:
          // Кость улучшения работает с текущим броском любой другой кости,
          // включая лечение. Постоянный уровень Dice при этом не меняется.
          heal += value;
        case DiceAbility.guardian:
          shield += value;
        case DiceAbility.ember:
          burn += value + (artifacts[Artifact.emberHeart] ?? 0);
        case DiceAbility.upgrade:
          break;
      }
    }
    for (var cell = 0; cell < 9; cell++) {
      final die = _board[cell];
      if (die != null && !_cancelledCells.contains(cell)) {
        applyDie(cell, die);
      }
    }
    for (final entry in _glassDice) {
      if (!_cancelledCells.contains(entry.key)) {
        applyDie(entry.key, entry.value);
      }
    }
    return TurnEffects(attack: attack, shield: shield, heal: heal, burn: burn);
  }

  BattlePreview previewFor(Fighter fighter) {
    final resolution = _resolve();
    return identical(fighter, player)
        ? resolution.player.preview
        : resolution.enemy.preview;
  }

  /// Preview и применение используют один расчёт, включая смертельный первый
  /// удар, щит, отложенный огонь и лечение только выживших в самом конце.
  _Resolution _resolve() {
    return _resolveWithEvents(null);
  }

  _Resolution _resolveWithEvents(List<BattleEvent>? events) {
    final intent = playerIntent;
    final truce =
        round == 1 &&
        (artifacts[Artifact.truceSeal] ?? 0) > 0 &&
        intent.attack <= enemy.shield + enemyIntent.shield &&
        enemy.burn == 0;
    final p = _ResolvedFighter(
      player,
      intent,
      side: BattleSide.player,
      immune: truce,
    );
    final e = _ResolvedFighter(enemy, enemyIntent, side: BattleSide.enemy);
    var sequence = 0;
    void record(
      BattleEventType type,
      BattleSide source,
      BattleSide target,
      int amount,
      {int hits = 1}) {
      if (events == null || amount <= 0) return;
      events.add(
        BattleEvent(
          sequence: sequence++,
          type: type,
          source: source,
          target: target,
          amount: amount,
          hits: hits,
        ),
      );
    }

    record(
      BattleEventType.shield,
      BattleSide.player,
      BattleSide.player,
      intent.shield,
    );
    record(
      BattleEventType.shield,
      BattleSide.enemy,
      BattleSide.enemy,
      enemyIntent.shield,
    );
    p.tickBurn(
      player.burn,
      (amount, blocked) {
        record(
          BattleEventType.blocked,
          BattleSide.player,
          BattleSide.player,
          blocked,
        );
        record(
          BattleEventType.burn,
          BattleSide.player,
          BattleSide.player,
          amount,
        );
      },
    );
    e.tickBurn(
      enemy.burn,
      (amount, blocked) {
        record(
          BattleEventType.blocked,
          BattleSide.enemy,
          BattleSide.enemy,
          blocked,
        );
        record(
          BattleEventType.burn,
          BattleSide.enemy,
          BattleSide.enemy,
          amount,
        );
      },
    );
    if (enemy.actsFirst) {
      e.attack(p, record);
      p.attack(e, record);
    } else {
      p.attack(e, record);
      e.attack(p, record);
    }
    p.heal(record);
    e.heal(record);
    return _Resolution(p, e);
  }

  void _advanceBoard() {
    for (var cell = 0; cell < _board.length; cell++) {
      final die = _board[cell];
      if (die == null) continue;
      if (!_isLocked(die)) {
        _board[cell] = null;
        continue;
      }
      final nextLevel = die.dice.level - 1;
      if (nextLevel <= 0) {
        _board[cell] = null;
        final inventoryIndex = player.dice.indexOf(die.dice);
        if (inventoryIndex >= 0) player.dice.removeAt(inventoryIndex);
        onDiceChanged?.call(die.dice, null);
        continue;
      }
      final updated = die.dice.copyWith(level: nextLevel);
      _board[cell] = RolledDie(
        dice: updated,
        value: die.value.clamp(nextLevel, 6).toInt(),
      );
      final inventoryIndex = player.dice.indexOf(die.dice);
      if (inventoryIndex >= 0) player.dice[inventoryIndex] = updated;
      onDiceChanged?.call(die.dice, updated);
    }
    _glassDice.clear();
  }

  bool endTurn() {
    if (!canAct) return _over;
    prepareEndTurn();
    final events = <BattleEvent>[];
    final result = _resolveWithEvents(events);
    lastEvents = List.unmodifiable(events);
    lastPlayerDamage = result.player.incoming;
    lastEnemyDamage = result.enemy.incoming;
    if (lastPlayerDamage > 0) playerHitVersion++;
    if (lastEnemyDamage > 0) enemyHitVersion++;
    player.hp = result.player.hp;
    player.shield = result.player.shield;
    player.burn = result.player.burn;
    enemy.hp = result.enemy.hp;
    enemy.shield = result.enemy.shield;
    enemy.burn = result.enemy.burn;
    _over = player.isDead || enemy.isDead;
    _advanceBoard();
    _rootResolutionPrepared = false;
    _cancelledCells.clear();
    _rootedCells.clear();
    if (_over) {
      _board.fillRange(0, 9, null);
      _glassDice.clear();
    } else {
      round++;
      _prepareRound();
    }
    notifyListeners();
    return _over;
  }
}

class _Resolution {
  const _Resolution(this.player, this.enemy);
  final _ResolvedFighter player;
  final _ResolvedFighter enemy;
}

class _ResolvedFighter {
  _ResolvedFighter(
    Fighter fighter,
    TurnEffects requestedIntent, {
    required this.side,
    this.immune = false,
  }) : intent = _normalizedIntent(fighter, requestedIntent, side),
       hp = fighter.hp,
       maxHp = fighter.maxHp,
       shieldAtStart = _shieldAtStart(fighter, requestedIntent, side),
       shield = _shieldAtStart(fighter, requestedIntent, side);

  static TurnEffects _normalizedIntent(
    Fighter fighter,
    TurnEffects intent,
    BattleSide side,
  ) {
    if (side != BattleSide.enemy) return intent;
    final currentShield = min(maxEnemyShield, max(0, fighter.shield));
    return intent.copyWith(
      shield: min(
        max(0, intent.shield),
        max(0, maxEnemyShield - currentShield),
      ),
    );
  }

  static int _shieldAtStart(
    Fighter fighter,
    TurnEffects requestedIntent,
    BattleSide side,
  ) {
    final currentShield = side == BattleSide.enemy
        ? min(maxEnemyShield, max(0, fighter.shield))
        : max(0, fighter.shield);
    final intent = _normalizedIntent(fighter, requestedIntent, side);
    return currentShield + intent.shield;
  }

  final TurnEffects intent;
  final BattleSide side;
  final bool immune;
  final int maxHp;
  final int shieldAtStart;
  int hp;
  int shield;
  int burn = 0;
  int outgoing = 0;
  int outgoingDamagePerHit = 0;
  int outgoingHits = 0;
  int incoming = 0;
  int incomingDamagePerHit = 0;
  int incomingHits = 0;
  int blocked = 0;
  int healing = 0;
  int burnApplied = 0;

  void tickBurn(
    int damage,
    void Function(int amount, int blocked) record,
  ) {
    if (hp <= 0 || immune) return;
    final absorbed = min(shield, damage);
    blocked += absorbed;
    shield -= absorbed;
    final remainingDamage = damage - absorbed;
    final appliedDamage = min(hp, remainingDamage);
    incoming += appliedDamage;
    hp = max(0, hp - remainingDamage);
    record(appliedDamage, absorbed);
  }

  void attack(
    _ResolvedFighter target,
    void Function(
      BattleEventType,
      BattleSide,
      BattleSide,
      int, {
      int hits,
    }) record,
  ) {
    if (hp <= 0 || target.hp <= 0) return;
    outgoing = intent.attack * intent.attackHits;
    outgoingDamagePerHit = intent.attack;
    outgoingHits = intent.attackHits;
    record(
      BattleEventType.attack,
      side,
      target.side,
      intent.attack,
      hits: intent.attackHits,
    );
    if (target.immune) return;
    final appliedPerHit = <int>[];
    for (var hit = 0; hit < intent.attackHits && target.hp > 0; hit++) {
      final absorbed = min(target.shield, intent.attack);
      target.blocked += absorbed;
      target.shield -= absorbed;
      final damage = intent.attack - absorbed;
      record(BattleEventType.blocked, side, target.side, absorbed);
      final appliedDamage = min(target.hp, damage);
      appliedPerHit.add(appliedDamage);
      target.incoming += appliedDamage;
      target.hp = max(0, target.hp - damage);
      record(BattleEventType.damage, side, target.side, appliedDamage);
    }
    if (appliedPerHit.isNotEmpty && appliedPerHit.toSet().length == 1) {
      target.incomingDamagePerHit = appliedPerHit.toSet().single;
      target.incomingHits = appliedPerHit.length;
    }
    if (target.hp > 0) {
      target.burn += intent.burn;
      burnApplied = intent.burn;
      record(BattleEventType.burn, side, target.side, intent.burn);
    }
  }

  void heal(
    void Function(
      BattleEventType,
      BattleSide,
      BattleSide,
      int, {
      int hits,
    }) record,
  ) {
    if (hp <= 0) return;
    healing = min(maxHp - hp, intent.heal);
    hp += healing;
    record(BattleEventType.heal, side, side, healing);
  }

  BattlePreview get preview => BattlePreview(
    outgoingDamage: outgoing,
    outgoingDamagePerHit: outgoingDamagePerHit,
    outgoingHits: outgoingHits,
    incomingDamage: incoming,
    incomingDamagePerHit: incomingDamagePerHit,
    incomingHits: incomingHits,
    shield: intent.shield,
    availableShield: shieldAtStart,
    blockedDamage: blocked,
    healing: healing,
    burnApplied: burnApplied,
  );
}
