import 'package:flutter/foundation.dart';

/// Описание одной локации: карта тайлов, точки спавна врагов и NPC.
///
/// Карта — матрица кодов тайлов:
///   0 — трава (проходимо), 1 — стена (непроходимо), 2 — дорога,
///   3 — дерево (непроходимо), 4 — переход на другую локацию,
///   5 — пустота за контуром карты, 6 — вода, 7 — серый приподнятый край,
///   8 — рельсы, 9 — земля, 10 — каменная плитка, 11 — деревянный настил,
///   12 — песок, 13 — цветочный луг, 14 — гравий, 15 — деревянный пол,
///   16 — светлая плитка, 17 — тёмная плитка.
///
/// TODO(сюжет): пользователь будет добавлять сюда новые локации.
@immutable
class LocationDef {
  const LocationDef({
    required this.id,
    required this.name,
    required this.tiles,
    required this.spawn,
    this.enemies = const [],
    this.npcs = const [],
    this.additionalNpcs = const [],
    this.exits = const [],
    this.props = const [],
    this.outsideTile = 5,
    this.outsideGroundRegions = const [],
  });

  final String id;
  final String name;

  /// Матрица тайлов: tiles[row][col].
  final List<List<int>> tiles;

  /// Точка появления игрока (col, row).
  final (int, int) spawn;

  /// Спавны врагов: (id врага, col, row).
  final List<EnemySpawn> enemies;

  /// Спавны NPC: (id NPC, имя, col, row).
  final List<NpcSpawn> npcs;

  /// Дополнительные сюжетные NPC. Отдельный список сохраняет старый контракт
  /// [npcs] для локаций, где внешний код ожидает единственного NPC.
  final List<NpcSpawn> additionalNpcs;

  List<NpcSpawn> get allNpcs => [...npcs, ...additionalNpcs];

  /// Переходы между локациями. Координаты перехода указываются в текущей
  /// карте, а [arrival] — необязательная точка появления на целевой карте.
  final List<LocationExit> exits;

  /// Декоративные и интерактивные объекты мира. Объекты с [blocksMovement]
  /// участвуют в коллизии так же, как стены и деревья, включая все клетки их
  /// размера.
  final List<LocationProp> props;

  /// Визуальный тайл за пределами логической карты. Значение 5 означает
  /// прозрачную пустоту, 6 — воду вокруг мостов. Зоны из
  /// [outsideGroundRegions] точечно переопределяют его декоративным тайлом
  /// только при внешней отрисовке; границы и коллизии карты от этого не
  /// меняются.
  final int outsideTile;

  /// Декоративные прямоугольники за пределами логической карты.
  /// Координаты включительные и используются только рендерером.
  final List<OutsideGroundRegion> outsideGroundRegions;

  int get rows => tiles.length;
  int get cols => tiles.first.length;

  bool inBounds(int col, int row) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  int tileAt(int col, int row) => inBounds(col, row) ? tiles[row][col] : 1;

  bool isOutsideGround(int col, int row) =>
      !inBounds(col, row) &&
      outsideGroundRegions.any((region) => region.contains(col, row));

  /// Визуальный тайл внешней клетки. Не используется для движения или
  /// проверки bounds.
  int outsideTileAt(int col, int row) {
    for (final region in outsideGroundRegions) {
      if (!inBounds(col, row) && region.contains(col, row)) {
        return region.tile;
      }
    }
    return outsideTile;
  }

  LocationProp? propById(String id) {
    for (final prop in props) {
      if (prop.id == id) return prop;
    }
    return null;
  }

  /// Возвращает переход под указанным тайлом.
  LocationExit? exitAt(int col, int row) {
    if (tileAt(col, row) != 4) return null;
    for (final exit in exits) {
      if (exit.col == col && exit.row == row) return exit;
    }
    return null;
  }

  /// Проходим ли тайл (для движения и поиска пути).
  bool isWalkable(int col, int row) {
    const walkable = {0, 2, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17};
    if (!inBounds(col, row) || !walkable.contains(tiles[row][col])) {
      return false;
    }
    return !props.any((prop) => prop.blocksMovement && prop.occupies(col, row));
  }
}

/// Визуальная зона земли за пределами логической карты.
@immutable
class OutsideGroundRegion {
  const OutsideGroundRegion({
    required this.minCol,
    required this.maxCol,
    required this.minRow,
    required this.maxRow,
    this.tile = 9,
  });

  final int minCol;
  final int maxCol;
  final int minRow;
  final int maxRow;
  final int tile;

  bool contains(int col, int row) =>
      col >= minCol && col <= maxCol && row >= minRow && row <= maxRow;
}

/// Связь между двумя картами.
@immutable
class LocationExit {
  const LocationExit({
    required this.col,
    required this.row,
    required this.targetId,
    this.arrival,
    this.direction = ExitDirection.auto,
  });

  final int col;
  final int row;
  final String targetId;
  final (int, int)? arrival;
  final ExitDirection direction;
}

/// Направление стрелки перехода. [auto] сохраняет старое поведение: сторона
/// карты определяется по координате выхода.
enum ExitDirection { auto, left, right, up, down }

@immutable
class EnemySpawn {
  const EnemySpawn(this.enemyId, this.col, this.row);
  final String enemyId;
  final int col;
  final int row;
}

@immutable
class NpcSpawn {
  const NpcSpawn(this.id, this.name, this.col, this.row);
  final String id;
  final String name;
  final int col;
  final int row;
}

enum LocationPropKind {
  tree,
  rock,
  bush,
  platform,
  bench,
  trashBin,
  crate,
  lamp,
  flowerBed,
}

@immutable
class LocationProp {
  const LocationProp({
    String? id,
    required this.kind,
    required this.col,
    required this.row,
    this.width = 1,
    this.height = 1,
    this.blocksMovement = true,
    this.variant = 0,
    this.searchable = false,
    this.specialItemId,
    this.interactionId,
  }) : id = id ?? 'prop_${col}_$row';

  /// Стабильный id объекта, используемый поиском и сохранением прогресса.
  final String id;

  final LocationPropKind kind;
  final int col;
  final int row;
  final int width;
  final int height;
  final bool blocksMovement;

  /// Номер визуального варианта процедурного спрайта. Логика коллизий от него
  /// не зависит, поэтому новые варианты можно добавлять без миграции сейва.
  final int variant;

  /// Можно ли взаимодействовать с объектом через поиск.
  final bool searchable;

  /// Особый предмет, который может находиться внутри объекта.
  final String? specialItemId;

  /// Идентификатор действия, которое запускается при взаимодействии с объектом.
  /// В отличие от [searchable], действие не открывает экран поиска.
  final String? interactionId;

  bool occupies(int targetCol, int targetRow) =>
      targetCol >= col &&
      targetCol < col + width &&
      targetRow >= row &&
      targetRow < row + height;
}
