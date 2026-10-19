import 'dart:ui';

import 'isometric_map.dart';
import 'map_entity.dart';

/// Игрок: перемещается по карте (тап по тайлу или WASD/стрелки).
class Player extends MapEntity {
  Player({
    super.col = 0,
    super.row = 0,
    String? label,
    super.skinId,
    super.skinProvider,
  }) : super(
         color: const Color(0xFF42A5F5),
         label: label ?? 'Игрок',
         kind: MapEntityKind.player,
       );

  /// Alias useful to callers that model the selected appearance as a
  /// player-owned value rather than a generic MapEntity skin.
  String? get selectedSkinId => activeSkinId;
  set selectedSkinId(String? value) => setSkin(value);

  /// Путь, по которому идёт игрок (список тайлов).
  final List<(int, int)> path = [];

  /// Скорость движения в тайлах в секунду.
  static const double tilesPerSecond = 4;

  bool _moving = false;
  bool get isMoving => _moving;

  (int, int) get tile => (col, row);

  /// Клетка, к которой сейчас движется игрок. Для обычного состояния это
  /// null, поэтому игровой мир всегда может отличить стоящего игрока от
  /// прерванного перехода.
  (int, int)? get movementTargetTile => path.isEmpty ? null : path.first;

  /// Последний тайл очереди движения. Нужен для удерживаемой клавиши: пока
  /// игрок проходит текущий тайл, следующий шаг можно положить в очередь и
  /// убрать паузу между шагами.
  (int, int)? get movementPathTailTile => path.isEmpty ? null : path.last;

  /// Направление текущего перехода на сетке. Для управления используются
  /// только четыре направления: `(0, ±1)` и `(±1, 0)`.
  (int, int)? get movementDirection {
    final target = movementTargetTile;
    if (target == null) return null;
    return (_sign(target.$1 - col), _sign(target.$2 - row));
  }

  static int _sign(int value) => value == 0 ? 0 : value.sign;

  /// Команда: идти к тайлу (цель уже проверена на проходимость).
  void moveTo(List<(int, int)> tiles) {
    path
      ..clear()
      ..addAll(tiles);
    _moving = path.isNotEmpty;
  }

  /// Добавляет один проверенный тайл в конец текущего маршрута.
  void queueMoveTo((int, int) tile) {
    if (path.isEmpty) {
      moveTo([tile]);
      return;
    }
    if (path.last == tile) return;
    path.add(tile);
    _moving = true;
  }

  /// Останавливает движение.
  void stop({bool snapToTile = true}) {
    path.clear();
    _moving = false;
    if (snapToTile) {
      position = IsometricMap.tileToWorld(col, row);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (path.isNotEmpty) {
      _moving = true;
      final target = path.first;
      final targetWorld = IsometricMap.tileToWorld(target.$1, target.$2);

      // Плавное перемещение к центру следующего тайла.
      final speed = tilesPerSecond * IsometricMap.tileWidth * dt;
      final direction = targetWorld - position;
      if (direction.length < speed) {
        position = targetWorld;
        col = target.$1;
        row = target.$2;
        path.removeAt(0);
        if (path.isEmpty) _moving = false;
      } else {
        position += direction.normalized() * speed;
      }
    } else {
      _moving = false;
    }

    priority = position.y.round() + 101;
  }
}
