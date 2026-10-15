import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/dice.dart';
import '../domain/artifact.dart';

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
    this.shield = 0,
    this.heal = 0,
    this.burn = 0,
  });

  final int attack;
  final int shield;
  final int heal;
  final int burn;
}

@immutable
class BattlePreview {
  const BattlePreview({
    this.outgoingDamage = 0,
    this.incomingDamage = 0,
    this.shield = 0,
    this.blockedDamage = 0,
    this.healing = 0,
    this.burnApplied = 0,
  });

  final int outgoingDamage;
  final int incomingDamage;

  /// Полный щит, который будет добавлен в начале этого раунда.
  ///
  /// Это намерение отличается от [blockedDamage]: последний показывает,
  /// сколько фактического входящего урона поглотит щит и потому может быть
  /// меньше полного значения щита.
  final int shield;
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
  });

  final int sequence;
  final BattleSide source;
  final BattleEventType type;
  final BattleSide target;
  final int amount;
}

enum BattleSide { player, enemy }

class Fighter {
  Fighter({
    required this.name,
    required this.maxHp,
    this.dice = const [],
    this.isPlayer = false,
    int? initialHp,
    this.attackFaces = const [],
    this.baseAttack = 0,
    this.baseShield = 0,
    this.baseHealing = 0,
    this.actsFirst = false,
    this.burnDamage = 0,
    this.appearance = 'player',
    this.attackPhrases = const [],
    this.equipment = const [],
    int initialShield = 0,
    int rootCells = 0,
  }) : hp = (initialHp ?? maxHp).clamp(0, maxHp).toInt(),
       shield = initialShield,
       rootCells = rootCells.clamp(0, 9).toInt();

  final String name;
  final int maxHp;
  final List<Dice> dice;
  final bool isPlayer;
  final List<int> attackFaces;
  final int baseAttack;
  final int baseShield;
  final int baseHealing;
  final bool actsFirst;
  final int burnDamage;
  final String appearance;
  final List<String> attackPhrases;
  final List<dynamic> equipment;
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
    Random? random,
  }) : hotbarSize = playerDiceCount.clamp(1, 3).toInt(),
       rerollsPerRound =
           (playerRerollsPerRound + (artifacts[Artifact.luckyCharm] ?? 0))
               .clamp(0, 6)
               .toInt(),
       artifacts = Map.unmodifiable(artifacts),
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
  final Random _random;
  late final List<RolledDie?> _hotbar;
  final List<RolledDie?> _board = List.filled(9, null);
  final Set<int> _rootedCells = <int>{};
  final Map<String, int> _legacyAssignments = {};
  List<BattleEvent> lastEvents = const [];
  List<RolledDie?> get hotbar => List.unmodifiable(_hotbar);
  List<RolledDie?> get board => List.unmodifiable(_board);
  Set<int> get rootedCells => Set.unmodifiable(_rootedCells);

  bool isCellRooted(int cell) => _rootedCells.contains(cell);

  TurnEffects _enemyIntent = const TurnEffects();
  TurnEffects get enemyIntent => _enemyIntent;
  int round = 1;
  int rerollsRemaining = 0;
  bool _started = false;
  bool _over = false;
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

  RolledDie _drawDie() {
    final die = player.dice[_random.nextInt(player.dice.length)];
    final minimum = die.level.clamp(1, 6).toInt();
    return RolledDie(dice: die, value: minimum + _random.nextInt(7 - minimum));
  }

  void _prepareRound() {
    _chooseRootedCells();
    final drawnSources = <String>{};
    for (var index = 0; index < hotbarSize; index++) {
      if (_hotbar[index] == null && player.dice.isNotEmpty) {
        final candidates = player.dice
            .where((dice) => !drawnSources.contains(dice.id))
            .toList();
        final source = candidates.isEmpty
            ? player.dice[_random.nextInt(player.dice.length)]
            : candidates[_random.nextInt(candidates.length)];
        drawnSources.add(source.id);
        final minimum = source.level.clamp(1, 6).toInt();
        _hotbar[index] = RolledDie(
          dice: source,
          value: minimum + _random.nextInt(7 - minimum),
        );
      }
    }
    rerollsRemaining = rerollsPerRound;
    _enemyIntent = TurnEffects(
      attack: enemy.attackFaces.isEmpty
          ? enemy.baseAttack
          : enemy.attackFaces[_random.nextInt(enemy.attackFaces.length)],
      shield: enemy.baseShield,
      heal: enemy.baseHealing,
      burn: enemy.burnDamage,
    );
    enemy.attackPhrase = _attackPhraseForRound();
    player.attackPhrase = _playerAttackPhraseForRound();
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

  /// Установка сразу расходует бросок: слот хотбара остаётся пустым до
  /// следующего раунда. Кость можно переместить или снять методом [removeDie].
  bool placeDie(int hotbarIndex, int cell) {
    if (!canAct ||
        !_validCell(cell) ||
        isCellRooted(cell) ||
        hotbarIndex < 0 ||
        hotbarIndex >= hotbarSize ||
        _board[cell] != null ||
        _hotbar[hotbarIndex] == null) {
      return false;
    }
    _board[cell] = _hotbar[hotbarIndex];
    _hotbar[hotbarIndex] = null;
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
      if (die?.dice.ability == DiceAbility.upgrade &&
          upgradeTargets(source, die!.dice.level).contains(cell)) {
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
        _board[from] == null) {
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
    if (!canAct || !_validCell(cell) || _board[cell] == null) return false;
    final freeSlot = _hotbar.indexWhere((die) => die == null);
    if (freeSlot < 0) return false;
    _hotbar[freeSlot] = _board[cell];
    _board[cell] = null;
    notifyListeners();
    return true;
  }

  /// Одна попытка заменяет один выбранный бросок случайным из инвентаря.
  bool rerollDie(int hotbarIndex) {
    if (!canAct ||
        rerollsRemaining == 0 ||
        player.dice.isEmpty ||
        hotbarIndex < 0 ||
        hotbarIndex >= hotbarSize ||
        _hotbar[hotbarIndex] == null) {
      return false;
    }
    _hotbar[hotbarIndex] = _drawDie();
    rerollsRemaining--;
    notifyListeners();
    return true;
  }

  static bool _validCell(int cell) => cell >= 0 && cell < 9;

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

  /// Усиление только на этот раунд, до 6. Улучшатели не усиливают друг друга,
  /// поэтому порядок установки не создаёт цепочек и не меняет результат.
  int effectiveValueAt(int cell) {
    if (!_validCell(cell) || _board[cell] == null) return 0;
    final target = _board[cell]!;
    if (target.dice.ability == DiceAbility.upgrade) return target.value;
    var value = target.value;
    for (var source = 0; source < 9; source++) {
      final die = _board[source];
      if (die == null || die.dice.ability != DiceAbility.upgrade) continue;
      if (upgradeTargets(source, die.dice.level).contains(cell)) {
        value += die.value;
      }
    }
    return value.clamp(1, 6).toInt();
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
    var shield = 2 * (artifacts[Artifact.ironThread] ?? 0);
    var heal = 2 * (artifacts[Artifact.fieldKit] ?? 0);
    var burn = 0;
    for (var cell = 0; cell < 9; cell++) {
      final die = _board[cell];
      if (die == null) continue;
      final value = effectiveValueAt(cell);
      switch (die.dice.ability) {
        case DiceAbility.none:
        case DiceAbility.warrior:
          attack += value + (artifacts[Artifact.whetstone] ?? 0);
        case DiceAbility.doctor:
          // Лечение доктора всегда равно уровню этой кости из инвентаря.
          // Upgrade временно меняет выпавшее значение атакующих/защитных
          // костей, но не превращает бросок в постоянный уровень.
          heal += effectiveLevelAt(cell);
        case DiceAbility.guardian:
          shield += value;
        case DiceAbility.ember:
          burn += value + (artifacts[Artifact.emberHeart] ?? 0);
        case DiceAbility.upgrade:
          break;
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
        intent.attack <= enemyIntent.shield &&
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
    ) {
      if (events == null || amount <= 0) return;
      events.add(
        BattleEvent(
          sequence: sequence++,
          type: type,
          source: source,
          target: target,
          amount: amount,
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
      (amount) => record(
        BattleEventType.burn,
        BattleSide.player,
        BattleSide.player,
        amount,
      ),
    );
    e.tickBurn(
      enemy.burn,
      (amount) => record(
        BattleEventType.burn,
        BattleSide.enemy,
        BattleSide.enemy,
        amount,
      ),
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

  bool endTurn() {
    if (!canAct) return _over;
    final events = <BattleEvent>[];
    final result = _resolveWithEvents(events);
    lastEvents = List.unmodifiable(events);
    lastPlayerDamage = result.player.incoming;
    lastEnemyDamage = result.enemy.incoming;
    if (lastPlayerDamage > 0) playerHitVersion++;
    if (lastEnemyDamage > 0) enemyHitVersion++;
    player.hp = result.player.hp;
    player.burn = result.player.burn;
    enemy.hp = result.enemy.hp;
    enemy.burn = result.enemy.burn;
    _over = player.isDead || enemy.isDead;
    _board.fillRange(0, 9, null);
    if (_over) {
      _rootedCells.clear();
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
    this.intent, {
    required this.side,
    this.immune = false,
  }) : hp = fighter.hp,
       maxHp = fighter.maxHp,
       shield = intent.shield;

  final TurnEffects intent;
  final BattleSide side;
  final bool immune;
  final int maxHp;
  int hp;
  int shield;
  int burn = 0;
  int outgoing = 0;
  int incoming = 0;
  int blocked = 0;
  int healing = 0;
  int burnApplied = 0;

  void tickBurn(int damage, void Function(int amount) record) {
    if (hp <= 0 || immune) return;
    final appliedDamage = min(hp, damage);
    incoming += appliedDamage;
    hp = max(0, hp - damage);
    record(appliedDamage);
  }

  void attack(
    _ResolvedFighter target,
    void Function(BattleEventType, BattleSide, BattleSide, int) record,
  ) {
    if (hp <= 0 || target.hp <= 0) return;
    outgoing = intent.attack;
    record(BattleEventType.attack, side, target.side, intent.attack);
    if (target.immune) return;
    final absorbed = min(target.shield, intent.attack);
    target.blocked += absorbed;
    target.shield -= absorbed;
    final damage = intent.attack - absorbed;
    record(BattleEventType.blocked, side, target.side, absorbed);
    final appliedDamage = min(target.hp, damage);
    target.incoming += appliedDamage;
    target.hp = max(0, target.hp - damage);
    record(BattleEventType.damage, side, target.side, appliedDamage);
    if (target.hp > 0) {
      target.burn += intent.burn;
      burnApplied = intent.burn;
      record(BattleEventType.burn, side, target.side, intent.burn);
    }
  }

  void heal(
    void Function(BattleEventType, BattleSide, BattleSide, int) record,
  ) {
    if (hp <= 0) return;
    healing = min(maxHp - hp, intent.heal);
    hp += healing;
    record(BattleEventType.heal, side, side, healing);
  }

  BattlePreview get preview => BattlePreview(
    outgoingDamage: outgoing,
    incomingDamage: incoming,
    shield: intent.shield,
    blockedDamage: blocked,
    healing: healing,
    burnApplied: burnApplied,
  );
}
