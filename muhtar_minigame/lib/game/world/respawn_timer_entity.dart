import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import 'isometric_map.dart';

/// Небольшая надпись на месте побеждённого врага.
class RespawnTimerEntity extends PositionComponent {
  RespawnTimerEntity({
    required this.col,
    required this.row,
    required this.remaining,
  }) : super(
         anchor: Anchor.center,
         position: IsometricMap.tileToWorld(col, row),
         size: Vector2(120, 28),
         priority: IsometricMap.tileToWorld(col, row).y.round() + 110,
       );

  final int col;
  final int row;
  Duration remaining;

  final TextPaint _paint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD36A),
      fontSize: 11,
      fontFamily: 'monospace',
      backgroundColor: Color(0xCC171923),
    ),
  );

  void setRemaining(Duration value) {
    remaining = value;
  }

  @override
  void render(Canvas canvas) {
    final totalSeconds = remaining.inSeconds.clamp(0, 3599).toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    _paint.render(
      canvas,
      'Возрождение ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      Vector2(size.x / 2, -24),
      anchor: Anchor.center,
    );
  }
}
