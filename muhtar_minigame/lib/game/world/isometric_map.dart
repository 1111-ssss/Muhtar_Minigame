import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import '../../domain/location.dart';
import '../../domain/locations.dart';

/// Изометрическая карта с ромбовидными тайлами.
///
/// Логика перемещения по-прежнему работает с парой `(col, row)`, а этот
/// компонент отвечает только за согласованное преобразование сетки в мир и
/// обратно. Поэтому A* и коллизии не зависят от угла обзора камеры.
class IsometricMap extends Component {
  IsometricMap(this.location) : super(priority: 0);

  final LocationDef location;

  /// Полный размер ромба. Умеренная высота оставляет карту читаемой и не
  /// превращает её в «алмаз» с углом 45°.
  static const double tileWidth = 80;
  static const double tileHeight = 40;

  /// Тайлы одинакового визуального стиля переиспользуются между картами.
  /// Раньше новый tile sheet создавался при каждом переходе, поэтому первый
  /// переход после запуска одновременно запускал растеризацию и отрисовку
  /// новой карты.
  static final Map<String, Image> _tileImageCache = {};
  static final Map<String, Future<Image>> _tileImageLoads = {};

  /// Проецирует точку локального квадратного тайла в его изометрический
  /// ромб. `u` идёт вдоль `(col + 1, row)`, `v` — вдоль `(col, row + 1)`.
  static Offset projectTilePoint(double u, double v, {double tileOffsetX = 0}) {
    return Offset(
      tileOffsetX + tileWidth / 2 + (u - v) * tileWidth / 2,
      tileHeight / 2 + (u + v - 1) * tileHeight / 2,
    );
  }

  late final Image _tileImage;
  final TextPaint _exitLabel = TextPaint(
    style: const TextStyle(
      color: Color(0xFFD7E2FF),
      fontFamily: 'monospace',
      fontSize: 12,
      backgroundColor: Color(0xBB171923),
    ),
  );

  @override
  Future<void> onLoad() async {
    _tileImage = await _tileImageForStyle(_tileStyleKey(location));
  }

  /// Прогревает tile sheet до появления игрового экрана. Это переносит
  /// дорогой первый [Picture.toImage] на splash, а не на первый телепорт.
  static Future<void> precache(LocationDef location) async {
    await _tileImageForStyle(_tileStyleKey(location));
  }

  static String _tileStyleKey(LocationDef location) {
    if (location.id == 'kopeechka' || location.id == 'cheburechnaya') {
      return 'shop';
    }
    return switch (location.id) {
      'meadow' => 'meadow',
      'ruins' => 'ruins',
      _ => 'grass',
    };
  }

  static Future<Image> _tileImageForStyle(String style) async {
    final cached = _tileImageCache[style];
    if (cached != null) return cached;

    final pending = _tileImageLoads[style];
    if (pending != null) return pending;

    final load = _generateTileSheet(style);
    _tileImageLoads[style] = load;
    try {
      final image = await load;
      _tileImageCache[style] = image;
      return image;
    } finally {
      if (identical(_tileImageLoads[style], load)) {
        _tileImageLoads.remove(style);
      }
    }
  }

  /// Генерирует горизонтальную полоску из ромбовидных тайлов. Тайл 5 —
  /// прозрачная пустота, 6 — вода, 7 — серый приподнятый край моста,
  /// 9 — плоская земля берегов, 13 — травяная площадка.
  static Future<Image> _generateTileSheet(String style) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const w = tileWidth;
    const h = tileHeight;
    final colors = [
      style == 'shop'
          ? const Color(0xFF767C82)
          : switch (style) {
              'meadow' => const Color(0xFF9A8062),
              'ruins' => const Color(0xFF807E78),
              _ => const Color(0xFF4C9A4C),
            }, // 0 пол/трава
      const Color(0xFF6B5A4A), // 1 стена
      style == 'shop'
          ? const Color(0xFF8B9094)
          : const Color(0xFFC8A872), // 2 дорога / серый пол магазина
      const Color(0xFF2E7D32), // 3 лесная кромка
      const Color(0xFF65748A), // 4 переход без пёстрой текстуры
      const Color(0x00000000), // 5 пустота
      const Color(0xFF3A7180), // 6 вода
      const Color(0xFF858B90), // 7 серый край
      const Color(0xFF75705F), // 8 рельсы (балласт)
      const Color(0xFF9A8062), // 9 земля
      const Color(0xFF777D82), // 10 каменная плитка
      const Color(0xFF8B5A3C), // 11 деревянный настил
      const Color(0xFFD8C08A), // 12 песок
      const Color(0xFF4C9A4C), // 13 цветочный луг
      const Color(0xFF8A8578), // 14 гравий
    ];

    final pixelPaint = Paint()..isAntiAlias = false;

    for (var i = 0; i < colors.length; i++) {
      final center = Offset(i.toDouble() * w + w / 2, h / 2);
      final path = Path()
        ..moveTo(center.dx, 0)
        ..lineTo(center.dx + w / 2, center.dy)
        ..lineTo(center.dx, h)
        ..lineTo(center.dx - w / 2, center.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[i]
          ..isAntiAlias = false,
      );

      if (i != 5) {
        // Контур для читаемости ромбов.
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x33000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..isAntiAlias = false,
        );
      }

      // Небольшие узоры из ромбиков и пикселей делают процедурный тайлсет
      // похожим на текстуру, а прозрачные углы сохраняют изометрию соседей.
      final offsetX = i.toDouble() * w;
      switch (i) {
        case 0: // трава
          pixelPaint.color = const Color(0x55316B35);
          canvas.drawRect(Rect.fromLTWH(offsetX + 18, 18, 3, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 56, 20, 2, 2), pixelPaint);
          pixelPaint.color = const Color(0x445FB35C);
          canvas.drawRect(Rect.fromLTWH(offsetX + 38, 9, 2, 2), pixelPaint);
        case 1: // камень/стена
          pixelPaint.color = const Color(0x55312620);
          canvas.drawRect(Rect.fromLTWH(offsetX + 20, 14, 9, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 51, 20, 7, 3), pixelPaint);
        case 2: // дорога
          pixelPaint.color = const Color(0x335B432D);
          canvas.drawRect(Rect.fromLTWH(offsetX + 20, 17, 4, 2), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 56, 17, 4, 2), pixelPaint);
        case 3: // тёмная трава/лес
          pixelPaint.color = const Color(0x553C6E35);
          canvas.drawRect(Rect.fromLTWH(offsetX + 18, 15, 4, 4), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 26, 11, 3, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 55, 20, 3, 3), pixelPaint);
        case 4: // переход: стрелка рисуется поверх карты
          break;
        case 5: // пустота за контуром карты
          break;
        case 6: // вода
          pixelPaint.color = const Color(0x334EC2C5);
          canvas.drawRect(Rect.fromLTWH(offsetX + 16, 17, 12, 2), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 48, 22, 14, 2), pixelPaint);
          break;
        case 7: // серый приподнятый край
          pixelPaint.color = const Color(0x5552575C);
          canvas.drawRect(Rect.fromLTWH(offsetX + 16, 18, 12, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 48, 14, 10, 3), pixelPaint);
          break;
        case 8: // рельсы: балласт, шпалы и стальные нити
          // Детали рельсов задаются в координатах квадратного тайла и
          // проецируются в тот же ромб, что и его фон. Прямоугольники в
          // экранных координатах делали рельсы вертикальной плоской полосой.
          canvas.save();
          canvas.clipPath(path);

          final ballastPaint = Paint()
            ..color = const Color(0x33524E45)
            ..isAntiAlias = false;
          for (final point in const [
            (u: .18, v: .32),
            (u: .50, v: .68),
            (u: .82, v: .30),
          ]) {
            final center = projectTilePoint(
              point.u,
              point.v,
              tileOffsetX: offsetX,
            );
            final ballast = Path()
              ..moveTo(center.dx, center.dy - 2)
              ..lineTo(center.dx + 3, center.dy)
              ..lineTo(center.dx, center.dy + 2)
              ..lineTo(center.dx - 3, center.dy)
              ..close();
            canvas.drawPath(ballast, ballastPaint);
          }

          final sleeperPaint = Paint()
            ..color = const Color(0xFF5C4130)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.square
            ..isAntiAlias = false;
          for (final u in const [.18, .50, .82]) {
            canvas.drawLine(
              projectTilePoint(u, .18, tileOffsetX: offsetX),
              projectTilePoint(u, .82, tileOffsetX: offsetX),
              sleeperPaint,
            );
          }

          final darkRailPaint = Paint()
            ..color = const Color(0xFF3A3E44)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.square
            ..isAntiAlias = false;
          final steelRailPaint = Paint()
            ..color = const Color(0xFFB9BEC4)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.square
            ..isAntiAlias = false;
          for (final v in const [.30, .70]) {
            final start = projectTilePoint(0, v, tileOffsetX: offsetX);
            final end = projectTilePoint(1, v, tileOffsetX: offsetX);
            canvas.drawLine(start, end, darkRailPaint);
            canvas.drawLine(start, end, steelRailPaint);
          }
          canvas.restore();
          break;
        case 9: // земля: крошка и тёплые пятна
          pixelPaint.color = const Color(0x664D382A);
          canvas.drawRect(Rect.fromLTWH(offsetX + 17, 15, 5, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 50, 22, 7, 3), pixelPaint);
          pixelPaint.color = const Color(0x447A6048);
          canvas.drawRect(Rect.fromLTWH(offsetX + 31, 28, 3, 2), pixelPaint);
          break;
        case 10: // каменная плитка
          pixelPaint.color = const Color(0x55444A4F);
          canvas.drawRect(Rect.fromLTWH(offsetX + 13, 19, 15, 2), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 50, 12, 15, 2), pixelPaint);
          break;
        case 11: // деревянный настил
          pixelPaint.color = const Color(0x66552D20);
          for (var plank = 0; plank < 3; plank++) {
            canvas.drawRect(
              Rect.fromLTWH(offsetX + 11, (10 + plank * 9).toDouble(), 58, 3),
              pixelPaint,
            );
          }
          break;
        case 12: // песок: волны и зерно
          pixelPaint.color = const Color(0x55B49B6A);
          canvas.drawRect(Rect.fromLTWH(offsetX + 14, 16, 14, 2), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 44, 24, 16, 2), pixelPaint);
          pixelPaint.color = const Color(0x66FFF3D0);
          canvas.drawRect(Rect.fromLTWH(offsetX + 28, 12, 3, 2), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 52, 19, 2, 2), pixelPaint);
          break;
        case 13: // цветочный луг
          pixelPaint.color = const Color(0x55316B35);
          canvas.drawRect(Rect.fromLTWH(offsetX + 20, 24, 4, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 52, 14, 4, 3), pixelPaint);
          pixelPaint.color = const Color(0xFFE46B6B);
          canvas.drawRect(Rect.fromLTWH(offsetX + 30, 13, 4, 4), pixelPaint);
          pixelPaint.color = const Color(0xFFFFD36A);
          canvas.drawRect(Rect.fromLTWH(offsetX + 46, 24, 4, 4), pixelPaint);
          pixelPaint.color = const Color(0xFFF2F2F2);
          canvas.drawRect(Rect.fromLTWH(offsetX + 18, 17, 3, 3), pixelPaint);
          break;
        case 14: // гравий: угловатые камешки
          pixelPaint.color = const Color(0x55605C50);
          canvas.drawRect(Rect.fromLTWH(offsetX + 15, 14, 7, 5), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 34, 24, 8, 5), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 52, 13, 6, 4), pixelPaint);
          pixelPaint.color = const Color(0x55A8A295);
          canvas.drawRect(Rect.fromLTWH(offsetX + 24, 18, 5, 3), pixelPaint);
          canvas.drawRect(Rect.fromLTWH(offsetX + 46, 22, 6, 3), pixelPaint);
          break;
      }
    }

    final picture = pictureRecorder.endRecording();
    return picture.toImage(colors.length * w.toInt(), h.toInt());
  }

  /// Центр тайла в координатах мира. `(0, 0)` находится в центре камеры при
  /// первой загрузке, а соседние направления расходятся по диагоналям.
  static Vector2 tileToWorld(int col, int row) {
    return Vector2(
      (col - row).toDouble() * tileWidth / 2,
      (col + row).toDouble() * tileHeight / 2,
    );
  }

  /// Индекс тайла под точкой мира (или null, если вне карты).
  (int, int)? worldToTile(Vector2 world) {
    return worldToTileInLocation(location, world);
  }

  /// Обратное преобразование центра ромба в координаты сетки. Округление
  /// выбирает ближайший центр, а проверка bounds/типа тайла отсекает пустоту.
  static (int, int)? worldToTileInLocation(
    LocationDef location,
    Vector2 world,
  ) {
    final col = (world.x / tileWidth + world.y / tileHeight).round();
    final row = (world.y / tileHeight - world.x / tileWidth).round();
    if (!location.inBounds(col, row) || location.tileAt(col, row) == 5) {
      return null;
    }
    return (col, row);
  }

  @override
  void render(Canvas canvas) {
    final rows = location.rows;
    final cols = location.cols;

    _renderOutside(canvas, rows, cols);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final tile = location.tiles[row][col];
        if (tile == 5) continue;
        final pos = tileToWorld(col, row);
        if (tile == 7) {
          _renderRaisedTile(canvas, pos, tile);
          continue;
        }

        final src = Rect.fromLTWH(
          tile.toDouble() * tileWidth,
          0,
          tileWidth,
          tileHeight,
        );
        final dst = Rect.fromLTWH(
          pos.x - tileWidth / 2,
          pos.y - tileHeight / 2,
          tileWidth,
          tileHeight,
        );
        canvas.drawImageRect(
          _tileImage,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
    }

    final props = [...location.props]
      ..sort((a, b) {
        final depth = _propCenter(b).y.compareTo(_propCenter(a).y);
        if (depth != 0) return depth;
        return _propLayer(a).compareTo(_propLayer(b));
      });
    for (final prop in props) {
      _renderProp(canvas, prop);
    }

    for (final exit in location.exits) {
      final exitPosition = tileToWorld(exit.col, exit.row);
      _renderExitMarker(canvas, exitPosition, exit);
      _exitLabel.render(
        canvas,
        Locations.byId(exit.targetId)?.name ?? exit.targetId,
        exitPosition + Vector2(0, -31),
        anchor: Anchor.bottomCenter,
      );
    }
  }

  void _renderOutside(Canvas canvas, int rows, int cols) {
    if (location.outsideTile == 5 && location.outsideGroundRegions.isEmpty) {
      return;
    }
    var minCol = -2;
    var maxCol = cols + 1;
    var minRow = -2;
    var maxRow = rows + 1;
    for (final region in location.outsideGroundRegions) {
      minCol = math.min(minCol, region.minCol);
      maxCol = math.max(maxCol, region.maxCol);
      minRow = math.min(minRow, region.minRow);
      maxRow = math.max(maxRow, region.maxRow);
    }

    for (var row = minRow; row <= maxRow; row++) {
      // Береговые декоративные площадки моста занимают две клетки за
      // каждым торцом. Они остаются вне bounds и не участвуют в логике игры.
      for (var col = minCol; col <= maxCol; col++) {
        if (location.inBounds(col, row)) continue;
        final outsideTile = location.outsideTileAt(col, row);
        if (outsideTile == 5) continue;
        final pos = tileToWorld(col, row);
        final src = Rect.fromLTWH(
          outsideTile.toDouble() * tileWidth,
          0,
          tileWidth,
          tileHeight,
        );
        final dst = Rect.fromLTWH(
          pos.x - tileWidth / 2,
          pos.y - tileHeight / 2,
          tileWidth,
          tileHeight,
        );
        canvas.drawImageRect(
          _tileImage,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
    }
  }

  void _renderRaisedTile(Canvas canvas, Vector2 position, int tile) {
    _drawPrismTile(
      canvas,
      baseCenter: position,
      topColor: const Color(0xFF858B90),
      side: const Color(0xFF555A60),
      end: const Color(0xFF70767B),
      lift: -14,
      tile: tile,
    );
  }

  List<Offset> _diamond(Vector2 center) => [
    Offset(center.x, center.y - tileHeight / 2),
    Offset(center.x + tileWidth / 2, center.y),
    Offset(center.x, center.y + tileHeight / 2),
    Offset(center.x - tileWidth / 2, center.y),
  ];

  Vector2 _propCenter(LocationProp prop) {
    final col = prop.col.toDouble() + (prop.width - 1) / 2;
    final row = prop.row.toDouble() + (prop.height - 1) / 2;
    return Vector2((col - row) * tileWidth / 2, (col + row) * tileHeight / 2);
  }

  int _propLayer(LocationProp prop) =>
      prop.kind == LocationPropKind.platform ? 0 : 1;

  void _renderProp(Canvas canvas, LocationProp prop) {
    final position = _propCenter(prop);
    final paint = Paint()..isAntiAlias = false;
    canvas.save();
    switch (prop.kind) {
      case LocationPropKind.tree:
        final treeVariant = prop.variant % 3;
        paint.color = const Color(0x550F1A12);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(position.x, position.y + 7),
            width: treeVariant == 2 ? 42 : 34,
            height: 12,
          ),
          paint,
        );
        paint.color = treeVariant == 2
            ? const Color(0xFF745037)
            : const Color(0xFF65452F);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(position.x, position.y - 3),
            width: treeVariant == 1 ? 12 : 9,
            height: treeVariant == 2 ? 34 : 28,
          ),
          paint,
        );
        final darkLeaves = switch (treeVariant) {
          0 => const Color(0xFF1E5B32),
          1 => const Color(0xFF245D48),
          _ => const Color(0xFF3C6136),
        };
        final lightLeaves = switch (treeVariant) {
          0 => const Color(0xFF2E7D4A),
          1 => const Color(0xFF3F9162),
          _ => const Color(0xFF648E42),
        };
        paint.color = darkLeaves;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(position.x, position.y - 30),
            width: treeVariant == 2 ? 46 : 38,
            height: treeVariant == 2 ? 25 : 30,
          ),
          paint,
        );
        paint.color = lightLeaves;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(
              position.x + (treeVariant == 1 ? 8 : -8),
              position.y - (treeVariant == 2 ? 39 : 38),
            ),
            width: treeVariant == 1 ? 28 : 22,
            height: treeVariant == 2 ? 17 : 20,
          ),
          paint,
        );
        if (treeVariant == 1) {
          paint.color = const Color(0xFF5AA65A);
          canvas.drawRect(
            Rect.fromLTWH(position.x - 20, position.y - 29, 9, 5),
            paint,
          );
        }
        paint.color = const Color(0xFF5AA65A);
        canvas.drawRect(
          Rect.fromLTWH(position.x - 8, position.y - 45, 8, 5),
          paint,
        );
      case LocationPropKind.rock:
        paint.color = const Color(0x660F1A12);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(position.x + 2, position.y + 7),
            width: 38,
            height: 13,
          ),
          paint,
        );
        paint.color = switch (prop.variant % 3) {
          0 => const Color(0xFF686C70),
          1 => const Color(0xFF806F67),
          _ => const Color(0xFF5C7070),
        };
        final rock = Path()
          ..moveTo(position.x - 18, position.y + 4)
          ..lineTo(
            position.x - 13,
            position.y - 13 - prop.variant.toDouble() * 2,
          )
          ..lineTo(position.x + 5, position.y - 20 - prop.variant.toDouble())
          ..lineTo(position.x + 18, position.y - 6)
          ..lineTo(position.x + 12, position.y + 6)
          ..close();
        canvas.drawPath(rock, paint);
        paint.color = prop.variant % 3 == 1
            ? const Color(0xFFB89A8A)
            : const Color(0xFFA4A8AA);
        canvas.drawRect(
          Rect.fromLTWH(position.x - 7, position.y - 12, 9, 4),
          paint,
        );
      case LocationPropKind.bush:
        paint.color = const Color(0x5A0F1A12);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(position.x + 2, position.y + 6),
            width: 40,
            height: 13,
          ),
          paint,
        );
        final bushColor = switch (prop.variant % 3) {
          0 => const Color(0xFF2E7D4A),
          1 => const Color(0xFF3B8850),
          _ => const Color(0xFF567D3E),
        };
        paint.color = const Color(0xFF183A27);
        canvas.drawRect(
          Rect.fromLTWH(position.x - 19, position.y - 6, 38, 14),
          paint,
        );
        paint.color = bushColor;
        canvas.drawCircle(Offset(position.x - 12, position.y - 8), 11, paint);
        canvas.drawCircle(Offset(position.x, position.y - 14), 14, paint);
        canvas.drawCircle(Offset(position.x + 13, position.y - 7), 10, paint);
        paint.color = const Color(0xFF79B85B);
        canvas.drawRect(
          Rect.fromLTWH(position.x - 8, position.y - 23, 7, 4),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(position.x + 8, position.y - 16, 5, 3),
          paint,
        );
      case LocationPropKind.platform:
        _renderPlatform(canvas, prop);
      case LocationPropKind.bench:
        if (prop.id == 'cheburechnaya_table') {
          // В интерьере это небольшая зона сидений. Она использует тот же
          // тип пропа для совместимости с картой, но не должна наследовать
          // трёхтайловый размер парковки.
          _renderDiningBench(canvas, prop);
        } else {
          _renderParkBench(canvas, prop);
        }
      case LocationPropKind.trashBin:
        _renderTrashBin(canvas, position, prop.variant);
    }
    canvas.restore();
  }

  /// Визуальный городской мусорный бак. Он остаётся декоративным даже если
  /// prop помечен searchable: интеракции принадлежат world/game-state слою.
  void _renderTrashBin(Canvas canvas, Vector2 position, int variant) {
    final center = Offset(position.x + 9, position.y - 9);
    final paint = Paint()..isAntiAlias = false;

    paint.color = const Color(0x550F1522);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, position.y + 5),
        width: 25,
        height: 8,
      ),
      paint,
    );

    // Корпус слегка сужается к низу, чтобы бак не выглядел плоским
    // прямоугольником поверх ромбовидного тайла.
    paint.color = switch (variant % 3) {
      0 => const Color(0xFF40535A),
      1 => const Color(0xFF4C5964),
      _ => const Color(0xFF53665F),
    };
    final body = Path()
      ..moveTo(center.dx - 9, center.dy - 5)
      ..lineTo(center.dx + 9, center.dy - 5)
      ..lineTo(center.dx + 7, center.dy + 12)
      ..lineTo(center.dx - 7, center.dy + 12)
      ..close();
    canvas.drawPath(body, paint);
    paint.color = const Color(0xFF6F8588);
    canvas.drawRect(Rect.fromLTWH(center.dx - 6, center.dy - 2, 3, 11), paint);

    paint.color = const Color(0xFF29373E);
    canvas.drawRect(Rect.fromLTWH(center.dx - 12, center.dy - 9, 24, 4), paint);
    paint.color = const Color(0xFF8FA3A1);
    canvas.drawRect(Rect.fromLTWH(center.dx - 5, center.dy - 13, 10, 4), paint);
    paint.color = const Color(0xFF202B31);
    canvas.drawRect(Rect.fromLTWH(center.dx - 2, center.dy - 12, 4, 2), paint);
  }

  /// Проекция точки внутри footprint пропа.
  ///
  /// `u` идёт по col, `v` — по row. Поэтому постоянный `v` даёт именно
  /// изометрическую грань слева-сверху направо-вниз, а не экранную
  /// горизонталь. [lift] — вертикальный подъём детали над землёй.
  Offset _propPoint(LocationProp prop, double u, double v, {double lift = 0}) {
    final origin = tileToWorld(prop.col, prop.row);
    return Offset(
      origin.x + (u - v) * tileWidth / 2,
      origin.y + (u + v - 1) * tileHeight / 2 + lift,
    );
  }

  List<Offset> _propRectangle(
    LocationProp prop, {
    required double u0,
    required double u1,
    required double v0,
    required double v1,
    double lift = 0,
  }) => [
    _propPoint(prop, u0, v0, lift: lift),
    _propPoint(prop, u1, v0, lift: lift),
    _propPoint(prop, u1, v1, lift: lift),
    _propPoint(prop, u0, v1, lift: lift),
  ];

  void _drawPropPolygon(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  /// Изометрическая доска с короткой вертикальной передней гранью.
  /// Все длинные линии строятся в координатах footprint, поэтому ни сиденье,
  /// ни спинка не превращаются в горизонтальные экранные полосы.
  void _drawBenchBoard(
    Canvas canvas,
    LocationProp prop, {
    required double u0,
    required double u1,
    required double v0,
    required double v1,
    required double lift,
    required Color color,
    required Color edgeColor,
    double thickness = 4,
  }) {
    final top = _propRectangle(
      prop,
      u0: u0,
      u1: u1,
      v0: v0,
      v1: v1,
      lift: lift,
    );
    final front = Path()
      ..moveTo(top[2].dx, top[2].dy)
      ..lineTo(top[3].dx, top[3].dy)
      ..lineTo(top[3].dx, top[3].dy + thickness)
      ..lineTo(top[2].dx, top[2].dy + thickness)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..color = edgeColor
        ..isAntiAlias = false,
    );
    _drawPropPolygon(canvas, top, color);

    final highlightStart = _propPoint(prop, u0 + .08, v0 + .07, lift: lift - 1);
    final highlightEnd = _propPoint(prop, u1 - .08, v0 + .07, lift: lift - 1);
    canvas.drawLine(
      highlightStart,
      highlightEnd,
      Paint()
        ..color = color.withValues(alpha: .45)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false,
    );
  }

  void _drawBenchSupport(
    Canvas canvas,
    LocationProp prop, {
    required double u,
    required double v,
    required double topLift,
    required double bottomLift,
    double width = 5,
    Color color = const Color(0xFF39261F),
  }) {
    final top = _propPoint(prop, u, v, lift: topLift);
    final bottom = _propPoint(prop, u, v, lift: bottomLift);
    final halfWidth = width / 2;
    final support = Path()
      ..moveTo(top.dx - halfWidth, top.dy)
      ..lineTo(top.dx + halfWidth, top.dy)
      ..lineTo(bottom.dx + halfWidth, bottom.dy)
      ..lineTo(bottom.dx - halfWidth, bottom.dy)
      ..close();
    canvas.drawPath(
      support,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  void _renderParkBench(Canvas canvas, LocationProp prop) {
    final variant = prop.variant;
    final length = prop.width.toDouble();
    final warm = variant.isEven
        ? const Color(0xFF7D4B31)
        : const Color(0xFF5F3B2D);
    final light = variant.isEven
        ? const Color(0xFFB8794B)
        : const Color(0xFF93613D);
    final dark = const Color(0xFF39261F);

    // Тень повторяет весь footprint 3x1, а не только центр среднего тайла.
    _drawPropPolygon(
      canvas,
      _propRectangle(
        prop,
        u0: 0,
        u1: prop.width.toDouble(),
        v0: 0,
        v1: prop.height.toDouble(),
        lift: 5,
      ),
      const Color(0x550F1522),
    );

    // Для длинной парковочной лавки есть центральная опора; короткие лавки
    // (например, в Копеечке) сохраняют обычные две опоры.
    final supportPositions = length >= 3
        ? [length * .12, length / 2, length - length * .12]
        : [length * .25, length * .75];
    for (final u in supportPositions) {
      _drawBenchSupport(
        canvas,
        prop,
        u: u,
        v: .58,
        topLift: -9,
        bottomLift: 6,
        width: 5,
        color: dark,
      );
    }
    // Длинная нижняя перемычка тоже следует col-направлению.
    final braceStart = _propPoint(prop, length * .10, .58, lift: 3);
    final braceEnd = _propPoint(prop, length - length * .10, .58, lift: 3);
    canvas.drawLine(
      braceStart,
      braceEnd,
      Paint()
        ..color = const Color(0xFF2C2420)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false,
    );

    // Спинка держится на двух вертикальных стойках, расположенных за сиденьем.
    for (final u in [length * .08, length - length * .08]) {
      _drawBenchSupport(
        canvas,
        prop,
        u: u,
        v: .18,
        topLift: -29,
        bottomLift: -7,
        width: 5,
        color: dark,
      );
    }

    _drawBenchBoard(
      canvas,
      prop,
      u0: .06,
      u1: length - .06,
      v0: .39,
      v1: .76,
      lift: -10,
      color: warm,
      edgeColor: dark,
      thickness: 4,
    );
    _drawBenchBoard(
      canvas,
      prop,
      u0: .06,
      u1: length - .06,
      v0: .03,
      v1: .29,
      lift: -26,
      color: light,
      edgeColor: dark,
      thickness: 5,
    );
  }

  /// В чебуречной остаётся отдельный компактный вариант: чуть крупнее
  /// прежнего одноместного рисунка, но с теми же изометрическими плоскостями.
  /// Увеличение намеренно не применяется к парковым и магазинным лавкам.
  void _renderDiningBench(Canvas canvas, LocationProp prop) {
    final dark = const Color(0xFF39261F);
    final warm = const Color(0xFF6F4430);
    final light = const Color(0xFFB8794B);

    _drawPropPolygon(
      canvas,
      _propRectangle(prop, u0: .02, u1: .98, v0: .22, v1: .78, lift: 4),
      const Color(0x550F1522),
    );
    for (final u in const [.22, .78]) {
      _drawBenchSupport(
        canvas,
        prop,
        u: u,
        v: .56,
        topLift: -6,
        bottomLift: 4,
        width: 5,
        color: dark,
      );
    }
    _drawBenchBoard(
      canvas,
      prop,
      u0: .02,
      u1: .98,
      v0: .34,
      v1: .73,
      lift: -7,
      color: warm,
      edgeColor: dark,
      thickness: 4,
    );
    _drawBenchBoard(
      canvas,
      prop,
      u0: .02,
      u1: .98,
      v0: .08,
      v1: .31,
      lift: -19,
      color: light,
      edgeColor: dark,
      thickness: 4,
    );
  }

  /// Общая отрисовка приподнятого ромба: две боковые грани и верхушка.
  /// Верхушкой может быть как цветная заливка, так и спрайт тайла.
  void _drawPrismTile(
    Canvas canvas, {
    required Vector2 baseCenter,
    required Color side,
    required Color end,
    Color? topColor,
    int? tile,
    double lift = -10,
  }) {
    final topCenter = baseCenter + Vector2(0, lift);
    final top = _diamond(topCenter);
    final bottom = _diamond(baseCenter);
    Paint colored(Color color) => Paint()
      ..color = color
      ..isAntiAlias = false;
    canvas.drawPath(
      Path()
        ..moveTo(top[1].dx, top[1].dy)
        ..lineTo(top[2].dx, top[2].dy)
        ..lineTo(bottom[2].dx, bottom[2].dy)
        ..lineTo(bottom[1].dx, bottom[1].dy)
        ..close(),
      colored(side),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top[2].dx, top[2].dy)
        ..lineTo(top[3].dx, top[3].dy)
        ..lineTo(bottom[3].dx, bottom[3].dy)
        ..lineTo(bottom[2].dx, bottom[2].dy)
        ..close(),
      colored(end),
    );
    if (tile != null) {
      canvas.drawImageRect(
        _tileImage,
        Rect.fromLTWH(tile.toDouble() * tileWidth, 0, tileWidth, tileHeight),
        Rect.fromLTWH(
          topCenter.x - tileWidth / 2,
          topCenter.y - tileHeight / 2,
          tileWidth,
          tileHeight,
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(top[0].dx, top[0].dy)
          ..lineTo(top[1].dx, top[1].dy)
          ..lineTo(top[2].dx, top[2].dy)
          ..lineTo(top[3].dx, top[3].dy)
          ..close(),
        colored(topColor!),
      );
    }
  }

  void _renderPlatform(Canvas canvas, LocationProp prop) {
    // Платформа собирается из отдельных приподнятых ромбов, а не из одной
    // длинной ленты. Каменный цвет соответствует пролёту Моста.
    for (var row = prop.row; row < prop.row + prop.height; row++) {
      for (var col = prop.col; col < prop.col + prop.width; col++) {
        _drawPrismTile(
          canvas,
          baseCenter: tileToWorld(col, row),
          topColor: const Color(0xFF9AA0A6),
          side: const Color(0xFF5B6066),
          end: const Color(0xFF71777D),
        );
      }
    }
  }

  void _renderExitMarker(Canvas canvas, Vector2 position, LocationExit exit) {
    final shadow = Paint()
      ..color = const Color(0x990F1522)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    final paint = Paint()
      ..color = const Color(0xFFFFD36A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    final direction = switch (exit.direction) {
      ExitDirection.left => const Offset(-1, 0),
      ExitDirection.right => const Offset(1, 0),
      ExitDirection.up => const Offset(0, -1),
      ExitDirection.down => const Offset(0, 1),
      ExitDirection.auto =>
        exit.col == 0
            ? const Offset(-1, 0)
            : exit.col == location.cols - 1
            ? const Offset(1, 0)
            : exit.row == 0
            ? const Offset(0, -1)
            : const Offset(0, 1),
    };
    final start = Offset(
      position.x - direction.dx * 7,
      position.y - direction.dy * 7,
    );
    final tip = Offset(
      position.x + direction.dx * 7,
      position.y + direction.dy * 7,
    );
    canvas.drawLine(start.translate(2, 2), tip.translate(2, 2), shadow);
    canvas.drawLine(start, tip, paint);

    final head = Path()
      ..moveTo(
        tip.dx - direction.dx * 5 - direction.dy * 4,
        tip.dy - direction.dy * 5 + direction.dx * 4,
      )
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * 5 + direction.dy * 4,
        tip.dy - direction.dy * 5 - direction.dx * 4,
      );
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0xFFFFD36A)
        ..style = PaintingStyle.fill
        ..isAntiAlias = false,
    );
  }
}
