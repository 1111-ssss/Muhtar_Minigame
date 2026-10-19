import 'dart:async';

import 'package:flame/components.dart';

import '../../domain/game_content.dart';
import '../../domain/location.dart';
import '../../domain/locations.dart';
import '../../domain/quest.dart';
import '../../game_logic/game_state.dart';
import '../../game_logic/pathfinding.dart';
import 'enemy_entity.dart';
import 'isometric_map.dart';
import 'npc_entity.dart';
import 'player.dart';
import 'respawn_timer_entity.dart';

/// Игровой мир: изометрическая карта, камера, игрок, враги и NPC одной локации.
class GameWorld extends World {
  GameWorld({
    required this.gameState,
    required this.onLocationChange,
    required this.onBattleStart,
    required this.onNpcTalk,
    this.onPropSearch,
    this.onPropInteract,
  });

  final GameState gameState;
  final void Function(LocationExit exit) onLocationChange;
  final void Function(EnemyEntity enemy) onBattleStart;
  final void Function(NpcEntity npc) onNpcTalk;

  /// Вызывается, когда игрок подошёл к searchable-пропу.
  ///
  /// Колбэк оставлен необязательным, чтобы мир можно было загрузить отдельно
  /// от UI и подключить экран поиска позже.
  final void Function(LocationProp prop)? onPropSearch;

  /// Вызывается, когда игрок подошёл к интерактивному пропу.
  final void Function(LocationProp prop)? onPropInteract;

  /// Игрок живёт столько же, сколько мир: единственный экземпляр, который
  /// loadLocation лишь переперемещает. Это позволяет обращаться к нему
  /// (например, из боёв и диалогов) до первой загрузки локации.
  final Player player = Player(col: 0, row: 0);
  late IsometricMap map;
  late LocationDef location;
  final List<EnemyEntity> enemies = [];
  final List<NpcEntity> npcs = [];
  final Map<String, RespawnTimerEntity> _respawnTimers = {};

  Pathfinding? _pathfinding;
  bool _loadingLocation = false;
  bool _exitPending = false;

  /// Враг/NPC, к которому игрок сейчас подходит для взаимодействия.
  EnemyEntity? _pendingEnemy;
  NpcEntity? _pendingNpc;
  LocationProp? _pendingProp;

  @override
  Future<void> onLoad() async {
    // Рендерер читает выбранный id лениво, поэтому смена скина в UI видна
    // сразу и не требует пересоздания Player или текущей локации.
    player.skinProvider = () {
      try {
        return (gameState as dynamic).selectedSkinId?.toString();
      } catch (_) {
        return null;
      }
    };
    await loadLocation(gameState.currentLocationId);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_loadingLocation) return;

    _updateRespawnTimers();

    // Игрок дошёл до цели взаимодействия — запускаем бой/диалог.
    if (!player.isMoving) {
      // Переход срабатывает и тогда, когда игрок пришёл на клетку телепорта
      // обычным маршрутом, а не только при прямом тапе по самой клетке.
      final exit = location.exitAt(player.col, player.row);
      if (exit != null) {
        _useExit(exit);
        return;
      }
      if (_pendingEnemy != null) {
        final enemy = _pendingEnemy!;
        if (_isAdjacent(player.col, player.row, enemy.col, enemy.row)) {
          _pendingEnemy = null;
          onBattleStart(enemy);
        }
      } else if (_pendingNpc != null) {
        final npc = _pendingNpc!;
        if (_isAdjacent(player.col, player.row, npc.col, npc.row)) {
          _pendingNpc = null;
          onNpcTalk(npc);
        }
      } else if (_pendingProp != null) {
        final prop = _pendingProp!;
        if (_isAdjacentToProp(prop)) {
          _pendingProp = null;
          if (prop.interactionId != null) {
            onPropInteract?.call(prop);
          } else {
            onPropSearch?.call(prop);
          }
        }
      }
    }
  }

  static bool _isAdjacent(int c1, int r1, int c2, int r2) =>
      (c1 - c2).abs() + (r1 - r2).abs() <= 1;

  /// Загружает локацию по id: строит карту и спавнит сущности.
  Future<void> loadLocation(
    String locationId, {
    (int, int)? spawnOverride,
    String? fromLocationId,
  }) async {
    if (_loadingLocation) return;
    _loadingLocation = true;
    _exitPending = false;
    try {
      // Игрока не трогаем: удаление в Flame отложенное, и его isMounted был бы
      // ещё true — add ниже пропустил бы, а апдейт кадр спустя удалил бы его.
      removeAll(children.where((component) => component != player).toList());
      _pendingEnemy = null;
      _pendingNpc = null;
      _pendingProp = null;
      _respawnTimers.clear();

      location = Locations.byId(locationId) ?? Locations.meadow;
      _pathfinding = Pathfinding(location);

      map = IsometricMap(
        location,
        propFilter: gameState.isPropVisible,
        propHighlight: (prop) {
          if (prop.id != 'wb_fitting_room') return false;
          final state = gameState.quest('q_kartofla_videos')?.state;
          return state == QuestState.notStarted || state == QuestState.active;
        },
      );
      await add(map);

      final requestedSpawn =
          spawnOverride ??
          _spawnNearReturnExit(location, fromLocationId) ??
          location.spawn;
      final spawn = location.isWalkable(requestedSpawn.$1, requestedSpawn.$2)
          ? requestedSpawn
          : location.spawn;
      player
        ..col = spawn.$1
        ..row = spawn.$2
        ..label = gameState.playerName
        ..syncPosition();
      if (!player.isMounted) {
        await add(player);
      }
      enemies.clear();
      for (final spawn in location.enemies) {
        final spawnKey = _enemySpawnKey(location, spawn);
        final remaining = gameState.enemyRespawnRemaining(spawnKey);
        if (remaining != null) {
          _addRespawnTimer(spawn, spawnKey, remaining);
          continue;
        }
        await _spawnEnemy(spawn);
      }

      npcs.clear();
      for (final spawn in location.allNpcs) {
        final npc = NpcEntity(
          npcId: spawn.id,
          col: spawn.col,
          row: spawn.row,
          label: spawn.name,
        );
        npcs.add(npc);
        await add(npc);
      }
    } finally {
      _loadingLocation = false;
    }

    // Камеру настраивает MuhtarGame после загрузки мира.
  }

  /// Подбирает клетку рядом с переходом, который ведёт обратно в предыдущую
  /// локацию. Это оставляет игрока возле понятной точки возврата даже для
  /// новых карт, где arrival ещё не задан вручную.
  (int, int)? _spawnNearReturnExit(LocationDef target, String? fromLocationId) {
    if (fromLocationId == null) return null;
    LocationExit? returnExit;
    for (final exit in target.exits) {
      if (exit.targetId == fromLocationId) {
        returnExit = exit;
        break;
      }
    }
    if (returnExit == null) return null;

    const offsets = [(0, 1), (1, 0), (0, -1), (-1, 0)];
    for (final (dc, dr) in offsets) {
      final col = returnExit.col + dc;
      final row = returnExit.row + dr;
      if (target.isWalkable(col, row)) return (col, row);
    }
    return null;
  }

  /// Обрабатывает тап по карте: перемещает игрока к тайлу.
  void handleMapTap(Vector2 worldPosition) {
    if (_loadingLocation) return;
    final tile = map.worldToTile(worldPosition);
    if (tile == null) return;

    final (col, row) = tile;

    // Тап по врагу — подходим и начинаем бой.
    for (final enemy in enemies) {
      if (enemy.col == col && enemy.row == row) {
        _pendingNpc = null;
        _pendingProp = null;
        _approachTo(enemy.col, enemy.row, () => _pendingEnemy = enemy);
        return;
      }
    }

    // Тап по NPC — подходим и открываем диалог.
    for (final npc in npcs) {
      if (npc.col == col && npc.row == row) {
        _pendingEnemy = null;
        _pendingProp = null;
        _approachTo(npc.col, npc.row, () => _pendingNpc = npc);
        return;
      }
    }

    // Тап по интерактивному объекту или кусту/мусорному ведру — подходим к
    // объекту и вызываем соответствующее действие, когда игрок действительно
    // оказался рядом.
    final prop =
        _interactablePropAt(col, row) ?? map.visualPropAt(worldPosition);
    if (prop != null) {
      _approachToProp(prop);
      return;
    }

    // Тап по переходу — цель маршрута. Смена локации запускается только в
    // update после того, как игрок действительно встал на клетку перехода.
    final exit = location.exitAt(col, row);
    if (exit != null) {
      _pendingEnemy = null;
      _pendingNpc = null;
      _pendingProp = null;
      final path = _pathfinding?.findPath(player.tile, (col, row)) ?? [];
      if (path.isNotEmpty) player.moveTo(path);
      return;
    }

    // Обычный тайл — путь к нему.
    if (!location.isWalkable(col, row)) return;
    _pendingEnemy = null;
    _pendingNpc = null;
    _pendingProp = null;
    final path = _pathfinding?.findPath(player.tile, (col, row)) ?? [];
    if (path.isNotEmpty) {
      player.moveTo(path);
    }
  }

  /// Прокладывает путь к тайлу, соседнему с целью, и помечает ожидание.
  /// Если игрок уже стоит рядом — цель помечается сразу.
  void _approachTo(int targetCol, int targetRow, void Function() setPending) {
    if (_isAdjacent(player.col, player.row, targetCol, targetRow)) {
      player.stop();
      setPending();
      return;
    }

    // Ищем ближайший *достижимый* тайл рядом с целью. Раньше выбирался
    // только ближайший по Манхэттену вариант: если он был отрезан стеной,
    // игрок останавливался на соседнем тайле и взаимодействие не запускалось.
    List<(int, int)>? bestPath;
    var bestPathLength = 999999;
    for (final (dc, dr) in [(0, -1), (1, 0), (0, 1), (-1, 0)]) {
      final c = targetCol + dc;
      final r = targetRow + dr;
      if (!location.isWalkable(c, r)) continue;
      final candidatePath = _pathfinding?.findPath(player.tile, (c, r)) ?? [];
      if (candidatePath.isEmpty || candidatePath.length >= bestPathLength) {
        continue;
      }
      bestPathLength = candidatePath.length;
      bestPath = candidatePath;
    }

    if (bestPath == null) return;
    setPending();
    player.moveTo(bestPath);
  }

  /// Прокладывает путь к ближайшей свободной клетке рядом с пропом.
  void _approachToProp(LocationProp prop) {
    _pendingEnemy = null;
    _pendingNpc = null;
    if (_isAdjacentToProp(prop)) {
      player.stop();
      _pendingProp = prop;
      return;
    }

    List<(int, int)>? bestPath;
    var bestPathLength = 999999;
    for (var col = prop.col; col < prop.col + prop.width; col++) {
      for (var row = prop.row; row < prop.row + prop.height; row++) {
        for (final (dc, dr) in [(0, -1), (1, 0), (0, 1), (-1, 0)]) {
          final targetCol = col + dc;
          final targetRow = row + dr;
          if (!location.isWalkable(targetCol, targetRow)) continue;
          final candidatePath =
              _pathfinding?.findPath(player.tile, (targetCol, targetRow)) ?? [];
          if (candidatePath.isEmpty || candidatePath.length >= bestPathLength) {
            continue;
          }
          bestPathLength = candidatePath.length;
          bestPath = candidatePath;
        }
      }
    }

    if (bestPath == null) return;
    _pendingProp = prop;
    player.moveTo(bestPath);
  }

  /// Пошаговое перемещение от клавиатуры.
  /// Возвращает true, если команда была принята. Во время анимации команда
  /// может заменить текущую цель: это позволяет сразу развернуться назад или
  /// сменить направление без ожидания конца текущего сегмента.
  bool movePlayerBy(int dCol, int dRow) {
    // Управление намеренно остаётся четырёхнаправленным: диагональные
    // направления в изометрической сетке визуально путают направление
    // столкновения и соседний тайл.
    if (_loadingLocation ||
        (dCol == 0 && dRow == 0) ||
        (dCol != 0 && dRow != 0)) {
      return false;
    }

    final activeDirection = player.movementDirection;
    if (player.isMoving &&
        activeDirection != null &&
        dCol == -activeDirection.$1 &&
        dRow == -activeDirection.$2) {
      // Игрок ещё находится между двумя клетками. Целью разворота является
      // текущая клетка, а не следующая клетка за спиной — поэтому движение
      // визуально сразу возвращается назад без ожидания конца сегмента.
      player.moveTo([player.tile]);
      _pendingEnemy = null;
      _pendingNpc = null;
      _pendingProp = null;
      return true;
    }

    // Перпендикулярное направление не перенаправляет персонажа по косой
    // линии из середины тайла. Оно будет обработано следующим повтором,
    // когда текущий короткий сегмент завершится. Для того же направления
    // заранее ставим следующий тайл в очередь: это убирает остановку между
    // шагами при удержании WASD/стрелки.
    final appendingToMovement = player.isMoving;
    if (appendingToMovement) {
      if (activeDirection == null || activeDirection != (dCol, dRow)) {
        return false;
      }
      if (player.path.length >= 2) return true;
    }

    final origin = player.movementPathTailTile ?? player.tile;
    final target = (origin.$1 + dCol, origin.$2 + dRow);
    if (!location.inBounds(target.$1, target.$2)) return false;

    // Столкновение с врагом — бой.
    for (final enemy in enemies) {
      if (enemy.col == target.$1 && enemy.row == target.$2) {
        if (appendingToMovement) return false;
        _pendingNpc = null;
        _pendingProp = null;
        onBattleStart(enemy);
        return true;
      }
    }

    // Столкновение с NPC — диалог.
    for (final npc in npcs) {
      if (npc.col == target.$1 && npc.row == target.$2) {
        if (appendingToMovement) return false;
        _pendingEnemy = null;
        _pendingProp = null;
        onNpcTalk(npc);
        return true;
      }
    }

    final prop = _interactablePropAt(target.$1, target.$2);
    if (prop != null) {
      if (appendingToMovement) return false;
      _approachToProp(prop);
      return true;
    }

    if (!location.isWalkable(target.$1, target.$2)) return false;

    // Переход считается обычной клеткой только для последнего шага. Проверку
    // делаем перед запуском движения, но сам transition будет вызван update-ом
    // после прибытия, а не прямо из обработки клавиши.
    final exit = location.exitAt(target.$1, target.$2);
    if (exit != null) {
      _pendingEnemy = null;
      _pendingNpc = null;
      _pendingProp = null;
      if (appendingToMovement) {
        player.queueMoveTo(target);
      } else {
        player.moveTo([target]);
      }
      return true;
    }

    _pendingEnemy = null;
    _pendingNpc = null;
    _pendingProp = null;
    // Не вызываем stop(): он возвращает позицию в центр исходной клетки и
    // именно это создавало визуальный рывок/ощущение сдвинутой коллизии.
    if (appendingToMovement) {
      player.queueMoveTo(target);
    } else {
      player.moveTo([target]);
    }
    return true;
  }

  /// Удаляет побеждённого врага с карты.
  void removeEnemy(EnemyEntity enemy) {
    enemies.remove(enemy);
    enemy.removeFromParent();
    final remaining = gameState.enemyRespawnRemaining(enemy.spawnKey);
    if (remaining != null) {
      _addRespawnTimer(
        EnemySpawn(enemy.enemyId, enemy.col, enemy.row),
        enemy.spawnKey,
        remaining,
      );
    }
  }

  /// Обновляет подпись героя после повышения уровня, не пересоздавая карту.
  void syncPlayerName() {
    if (player.isMounted) player.label = gameState.playerName;
  }

  bool isPlayerAdjacentTo(NpcEntity npc) =>
      _isAdjacent(player.col, player.row, npc.col, npc.row);

  bool isPlayerAdjacentToProp(LocationProp prop) => _isAdjacentToProp(prop);

  LocationProp? _interactablePropAt(int col, int row) {
    for (final prop in location.props) {
      if ((prop.searchable || prop.interactionId != null) &&
          gameState.isPropVisible(prop) &&
          prop.occupies(col, row)) {
        return prop;
      }
    }
    return null;
  }

  bool _isAdjacentToProp(LocationProp prop) {
    for (var col = prop.col; col < prop.col + prop.width; col++) {
      for (var row = prop.row; row < prop.row + prop.height; row++) {
        if (_isAdjacent(player.col, player.row, col, row)) return true;
      }
    }
    return false;
  }

  void _useExit(LocationExit exit) {
    if (_exitPending) return;
    _exitPending = true;
    player.stop();
    gameState.progressQuests(locationId: exit.targetId);
    onLocationChange(exit);
  }

  String _enemySpawnKey(LocationDef location, EnemySpawn spawn) =>
      '${location.id}:${spawn.enemyId}:${spawn.col}:${spawn.row}';

  Future<void> _spawnEnemy(EnemySpawn spawn) async {
    final archetype = GameContent.enemyById(spawn.enemyId);
    if (archetype == null) return;
    final spawnKey = _enemySpawnKey(location, spawn);
    if (enemies.any((enemy) => enemy.spawnKey == spawnKey)) return;
    final enemy = EnemyEntity(
      enemyId: spawn.enemyId,
      col: spawn.col,
      row: spawn.row,
      label: archetype.name,
      spawnKey: spawnKey,
    );
    enemies.add(enemy);
    await add(enemy);
  }

  void _addRespawnTimer(EnemySpawn spawn, String spawnKey, Duration remaining) {
    if (_respawnTimers.containsKey(spawnKey)) return;
    final timer = RespawnTimerEntity(
      col: spawn.col,
      row: spawn.row,
      remaining: remaining,
    );
    _respawnTimers[spawnKey] = timer;
    add(timer);
  }

  void _updateRespawnTimers() {
    if (_respawnTimers.isEmpty) return;
    for (final entry in _respawnTimers.entries.toList()) {
      final remaining = gameState.enemyRespawnRemaining(entry.key);
      if (remaining == null) {
        entry.value.removeFromParent();
        _respawnTimers.remove(entry.key);
        for (final spawn in location.enemies) {
          if (_enemySpawnKey(location, spawn) == entry.key) {
            unawaited(_spawnEnemy(spawn));
            break;
          }
        }
      } else {
        entry.value.setRemaining(remaining);
      }
    }
  }
}
