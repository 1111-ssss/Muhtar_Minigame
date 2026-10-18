import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'build_models.dart';

/// The editor palette follows LocationDef's tile codes, including void.
const mapTileNames = <String>[
  'Трава / пол',
  'Стена',
  'Дорога',
  'Дерево',
  'Переход',
  'Пустота',
  'Вода',
  'Край',
  'Рельсы',
  'Земля',
  'Каменная плитка',
  'Деревянный настил',
  'Песок',
  'Цветочный луг',
  'Гравий',
  'Деревянный пол',
  'Светлая плитка',
  'Тёмная плитка',
];

const mapTileColors = <Color>[
  Color(0xFF527952),
  Color(0xFF776254),
  Color(0xFFB59A70),
  Color(0xFF315E40),
  Color(0xFF687CB2),
  Color(0xFF252B35),
  Color(0xFF397D99),
  Color(0xFF89939E),
  Color(0xFF6E6B59),
  Color(0xFF94755A),
  Color(0xFF76818C),
  Color(0xFF906449),
  Color(0xFFCCB880),
  Color(0xFF71985A),
  Color(0xFF8A8578),
  Color(0xFF9B6B45),
  Color(0xFFC8CDD2),
  Color(0xFF59616B),
];

int mapEditorTileAt(BuildMapDocument map, int col, int row) =>
    row >= 0 && row < map.rows && col >= 0 && col < map.tiles[row].length
    ? map.tiles[row][col]
    : -1;

bool mapCellBlocked(BuildMapDocument map, int col, int row) {
  if (!const {
    0,
    2,
    4,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  }.contains(mapEditorTileAt(map, col, row))) {
    return true;
  }
  return map.props.any((p) => p.blocksMovement && mapPropContains(p, col, row));
}

bool mapPropContains(BuildProp prop, int col, int row) =>
    col >= prop.col &&
    col < prop.col + prop.width &&
    row >= prop.row &&
    row < prop.row + prop.height;

/// A lightweight editor preview, independent of the Flame game lifecycle.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.document,
    required this.revision,
    required this.panMode,
    required this.showGrid,
    required this.showCollision,
    required this.showLabels,
    required this.selected,
    required this.onStrokeStart,
    required this.onCell,
    required this.onStrokeEnd,
  });

  final BuildMapDocument document;
  final int revision;
  final bool panMode;
  final bool showGrid;
  final bool showCollision;
  final bool showLabels;
  final (int, int)? selected;
  final VoidCallback onStrokeStart;
  final void Function(int col, int row, bool first) onCell;
  final VoidCallback onStrokeEnd;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  final _transform = TransformationController();
  Size _viewport = Size.zero;
  String? _fittedMap;
  int? _pointer;
  (int, int)? _lastCell;

  _IsoGeometry get _geometry =>
      _IsoGeometry(widget.document.cols, widget.document.rows);

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit() {
    if (!mounted || _viewport.isEmpty) return;
    final size = _geometry.size;
    final scale = math
        .min(
          (_viewport.width - 32) / size.width,
          (_viewport.height - 32) / size.height,
        )
        .clamp(.05, 2.0)
        .toDouble();
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport.width - size.width * scale) / 2,
        (_viewport.height - size.height * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor) {
    final oldScale = _transform.value.getMaxScaleOnAxis();
    final next = (oldScale * factor).clamp(.05, 5.0).toDouble();
    final center = _viewport.center(Offset.zero);
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * next,
        center.dy - scene.dy * next,
        0,
        1,
      )
      ..scaleByDouble(next, next, 1, 1);
  }

  void _visit(Offset position, {required bool first}) {
    final cell = _geometry.cellAt(position);
    if (cell == null) {
      _lastCell = null;
      return;
    }
    if (cell == _lastCell && !first) return;
    final previous = _lastCell;
    _lastCell = cell;
    if (!first && previous != null) {
      // Fill skipped cells during fast drags; one drag is one undo step.
      final dc = cell.$1 - previous.$1;
      final dr = cell.$2 - previous.$2;
      final steps = math.max(dc.abs(), dr.abs());
      for (var i = 1; i < steps; i++) {
        widget.onCell(
          (previous.$1 + dc * i / steps).round(),
          (previous.$2 + dr * i / steps).round(),
          false,
        );
      }
    }
    widget.onCell(cell.$1, cell.$2, first);
  }

  void _finish(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _lastCell = null;
    widget.onStrokeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final signature =
            '${widget.document.id}:${geometry.cols}:${geometry.rows}';
        if (signature != _fittedMap || viewport != _viewport) {
          _fittedMap = signature;
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
        }
        return ColoredBox(
          color: const Color(0xFF10151D),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    alignment: Alignment.topLeft,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: .05,
                    maxScale: 5,
                    panEnabled: widget.panMode,
                    scaleEnabled: widget.panMode,
                    child: MouseRegion(
                      cursor: widget.panMode
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.precise,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          if (widget.panMode ||
                              _pointer != null ||
                              event.buttons != kPrimaryButton) {
                            return;
                          }
                          _pointer = event.pointer;
                          widget.onStrokeStart();
                          _visit(event.localPosition, first: true);
                        },
                        onPointerMove: (event) {
                          if (_pointer == event.pointer && !widget.panMode) {
                            _visit(event.localPosition, first: false);
                          }
                        },
                        onPointerUp: _finish,
                        onPointerCancel: _finish,
                        child: Semantics(
                          label:
                              'Изометрическая карта, ${geometry.cols} столбцов, '
                              '${geometry.rows} строк. Выберите клетку для редактирования.',
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: geometry.size,
                              painter: _MapPainter(
                                map: widget.document,
                                revision: widget.revision,
                                geometry: geometry,
                                selected: widget.selected,
                                grid: widget.showGrid,
                                collision: widget.showCollision,
                                labels: widget.showLabels,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xE6202834),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        widget.panMode
                            ? 'Обзор • тяните карту / колесо — масштаб'
                            : 'Редактирование • клик / протяжка кистью',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: const Color(0xEE202834),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Уменьшить масштаб',
                        onPressed: () => _zoom(1 / 1.25),
                        icon: const Icon(Icons.remove),
                      ),
                      ValueListenableBuilder<Matrix4>(
                        valueListenable: _transform,
                        builder: (_, matrix, _) => SizedBox(
                          width: 52,
                          child: Text(
                            '${(matrix.getMaxScaleOnAxis() * 100).round()}%',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Увеличить масштаб',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Показать всю карту',
                        onPressed: _fit,
                        icon: const Icon(Icons.fit_screen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IsoGeometry {
  const _IsoGeometry(this.cols, this.rows);
  final int cols;
  final int rows;
  static const double halfWidth = 32;
  static const double halfHeight = 16;
  static const double margin = 56;

  Size get size => Size(
    (cols + rows) * halfWidth + margin * 2,
    (cols + rows) * halfHeight + margin * 2,
  );

  Offset point(double col, double row) => Offset(
    margin + rows * halfWidth + (col - row) * halfWidth,
    margin + (col + row) * halfHeight,
  );

  Path diamond(int col, int row, {int width = 1, int height = 1}) => Path()
    ..moveTo(
      point(col.toDouble(), row.toDouble()).dx,
      point(col.toDouble(), row.toDouble()).dy,
    )
    ..lineTo(
      point((col + width).toDouble(), row.toDouble()).dx,
      point((col + width).toDouble(), row.toDouble()).dy,
    )
    ..lineTo(
      point((col + width).toDouble(), (row + height).toDouble()).dx,
      point((col + width).toDouble(), (row + height).toDouble()).dy,
    )
    ..lineTo(
      point(col.toDouble(), (row + height).toDouble()).dx,
      point(col.toDouble(), (row + height).toDouble()).dy,
    )
    ..close();

  (int, int)? cellAt(Offset point) {
    final x = (point.dx - margin - rows * halfWidth) / halfWidth;
    final y = (point.dy - margin) / halfHeight;
    final col = ((x + y) / 2).floor();
    final row = ((y - x) / 2).floor();
    return col >= 0 && row >= 0 && col < cols && row < rows ? (col, row) : null;
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.map,
    required this.revision,
    required this.geometry,
    required this.selected,
    required this.grid,
    required this.collision,
    required this.labels,
  });

  final BuildMapDocument map;
  final int revision;
  final _IsoGeometry geometry;
  final (int, int)? selected;
  final bool grid;
  final bool collision;
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final line = Paint()
      ..color = const Color(0x66313E4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final blocked = <(int, int)>{};
    if (collision) {
      for (final prop in map.props.where((p) => p.blocksMovement)) {
        for (
          var r = math.max(0, prop.row);
          r < math.min(map.rows, prop.row + prop.height);
          r++
        ) {
          for (
            var c = math.max(0, prop.col);
            c < math.min(map.cols, prop.col + prop.width);
            c++
          ) {
            blocked.add((c, r));
          }
        }
      }
    }
    for (var r = 0; r < map.rows; r++) {
      for (var c = 0; c < map.cols; c++) {
        final tile = mapEditorTileAt(map, c, r);
        final path = geometry.diamond(c, r);
        fill.color = tile >= 0 && tile < mapTileColors.length
            ? mapTileColors[tile]
            : Colors.pink;
        canvas.drawPath(path, fill);
        if (grid) canvas.drawPath(path, line);
        if (collision &&
        (!const {0, 2, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17}.contains(tile) ||
                blocked.contains((c, r)))) {
          canvas.drawPath(path, Paint()..color = const Color(0x88C7354D));
          final center = geometry.point(c + .5, r + .5);
          canvas.drawLine(
            center - const Offset(5, 3),
            center + const Offset(5, 3),
            Paint()..color = const Color(0xFFFECCD1),
          );
          canvas.drawLine(
            center - const Offset(5, -3),
            center + const Offset(5, -3),
            Paint()..color = const Color(0xFFFECCD1),
          );
        }
      }
    }
    for (final prop in map.props) {
      final path = geometry.diamond(
        prop.col,
        prop.row,
        width: prop.width,
        height: prop.height,
      );
      canvas.drawPath(path, Paint()..color = const Color(0x5549C7D2));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF65DFDA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _marker(
        canvas,
        prop.col,
        prop.row,
        'О',
        const Color(0xFF75DFD8),
        labels ? prop.id : null,
        shift: const Offset(-12, 0),
      );
    }
    for (final enemy in map.enemies) {
      _marker(
        canvas,
        enemy.col,
        enemy.row,
        'В',
        const Color(0xFFFF8999),
        labels ? enemy.enemyId : null,
        shift: const Offset(12, 0),
      );
    }
    for (final npc in map.npcs) {
      _marker(
        canvas,
        npc.col,
        npc.row,
        'Н',
        const Color(0xFFFFD183),
        labels ? npc.name : null,
        shift: const Offset(0, -6),
      );
    }
    for (final npc in map.additionalNpcs) {
      _marker(
        canvas,
        npc.col,
        npc.row,
        'Н+',
        const Color(0xFFE4B4FA),
        labels ? npc.name : null,
        shift: const Offset(0, -6),
      );
    }
    for (final exit in map.exits) {
      final symbol = switch (exit.direction) {
        'left' => '←',
        'right' => '→',
        'up' => '↑',
        'down' => '↓',
        _ => '↗',
      };
      _marker(
        canvas,
        exit.col,
        exit.row,
        symbol,
        const Color(0xFFA7BFFF),
        labels ? exit.targetId : null,
        shift: const Offset(0, 5),
      );
    }
    _marker(
      canvas,
      map.spawnCol,
      map.spawnRow,
      'И',
      Colors.white,
      labels ? 'Игрок' : null,
      shift: const Offset(0, -12),
    );
    if (selected case final cell?) {
      canvas.drawPath(
        geometry.diamond(cell.$1, cell.$2),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (labels) {
      for (var c = 0; c < map.cols; c += 4) {
        _text(
          canvas,
          '$c',
          geometry.point(c + .5, -.7),
          const Color(0xFFA8B8CE),
        );
      }
      for (var r = 0; r < map.rows; r += 4) {
        _text(
          canvas,
          '$r',
          geometry.point(-.7, r + .5),
          const Color(0xFFA8B8CE),
        );
      }
      _text(
        canvas,
        'столбец →',
        geometry.point(map.cols / 2, -2),
        const Color(0xFFA8B8CE),
      );
      _text(
        canvas,
        '← строка',
        geometry.point(-2, map.rows / 2),
        const Color(0xFFA8B8CE),
      );
    }
  }

  void _marker(
    Canvas canvas,
    int col,
    int row,
    String mark,
    Color color,
    String? label, {
    Offset shift = Offset.zero,
  }) {
    final center = geometry.point(col + .5, row + .5) + shift;
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF17202B));
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _text(canvas, mark, center, color, bold: true);
    if (label != null) {
      _text(
        canvas,
        label.length > 24 ? '${label.substring(0, 23)}…' : label,
        center - const Offset(0, 21),
        color,
        background: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    Color color, {
    bool bold = false,
    bool background = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          backgroundColor: background ? const Color(0xDD15202B) : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.map.id != map.id ||
      oldDelegate.selected != selected ||
      oldDelegate.grid != grid ||
      oldDelegate.collision != collision ||
      oldDelegate.labels != labels;
}
