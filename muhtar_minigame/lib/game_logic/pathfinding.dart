import '../domain/location.dart';

/// Поиск пути A* на сетке тайлов. Нужен для движения по тапу.
class Pathfinding {
  Pathfinding(this.location);

  final LocationDef location;

  static const _directions = [(0, -1), (1, 0), (0, 1), (-1, 0)];

  /// Возвращает путь от [start] к [goal] списком тайлов (не включая старт).
  /// Гарантирует, что цель достижима, иначе возвращает пустой список.
  List<(int, int)> findPath((int, int) start, (int, int) goal) {
    final (sc, sr) = start;
    final (gc, gr) = goal;
    if (!location.isWalkable(gc, gr) || !location.isWalkable(sc, sr)) {
      return [];
    }
    if (start == goal) return [];

    final open = <_Node>[];
    final cameFrom = <(int, int), (int, int)>{};
    final gScore = <(int, int), int>{start: 0};
    open.add(_Node(start, _heuristic(start, goal)));

    final closed = <(int, int)>{};

    while (open.isNotEmpty) {
      open.sort((a, b) => a.f.compareTo(b.f));
      final current = open.removeAt(0).pos;

      if (current == goal) return _reconstruct(cameFrom, current);

      closed.add(current);
      final (cc, cr) = current;

      for (final (dc, dr) in _directions) {
        final next = (cc + dc, cr + dr);
        if (closed.contains(next)) continue;
        if (!location.isWalkable(next.$1, next.$2)) continue;
        // Переход — конечная точка, а не обычная часть маршрута. Это не даёт
        // A* прокладывать путь «сквозь» телепорт к клеткам за ним.
        if (location.tileAt(next.$1, next.$2) == 4 && next != goal) {
          continue;
        }

        final tentative = (gScore[current] ?? 999) + 1;
        if (tentative < (gScore[next] ?? 999)) {
          cameFrom[next] = current;
          gScore[next] = tentative;
          final h = _heuristic(next, goal);
          final inOpen = open.where((n) => n.pos == next);
          if (inOpen.isEmpty) {
            open.add(_Node(next, tentative + h));
          }
        }
      }
    }

    return [];
  }

  int _heuristic((int, int) a, (int, int) b) =>
      (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();

  List<(int, int)> _reconstruct(
    Map<(int, int), (int, int)> cameFrom,
    (int, int) current,
  ) {
    final path = <(int, int)>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.insert(0, current);
    }
    return path.sublist(1); // без стартового тайла
  }
}

class _Node {
  _Node(this.pos, this.f);
  final (int, int) pos;
  final int f;
}
