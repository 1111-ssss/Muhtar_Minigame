import 'package:flutter/material.dart';

import '../../domain/dice.dart';

/// Компактная пиксельная кость. Значок способности живёт в отдельном бейдже,
/// а число строго по центру лицевой грани — поэтому элементы больше не
/// наезжают друг на друга в хотбаре и на доске.
class DiceVisual extends StatelessWidget {
  const DiceVisual({
    required this.dice,
    this.value,
    this.compact = false,
    this.selected = false,
    this.used = false,
    this.showLevel = false,
    super.key,
  });

  final Dice dice;
  final int? value;
  final bool compact;
  final bool selected;
  final bool used;
  final bool showLevel;

  IconData get _icon => switch (dice.ability) {
    DiceAbility.none => Icons.sports_martial_arts,
    DiceAbility.warrior => Icons.sports_martial_arts,
    DiceAbility.doctor => Icons.healing,
    DiceAbility.ember => Icons.local_fire_department,
    DiceAbility.guardian => Icons.shield,
    DiceAbility.upgrade => Icons.auto_fix_high,
  };

  Color get _color => switch (dice.ability) {
    DiceAbility.none => const Color(0xFF8E82D7),
    DiceAbility.warrior => const Color(0xFFD99438),
    DiceAbility.doctor => const Color(0xFF4B9F76),
    DiceAbility.ember => const Color(0xFFC9573F),
    DiceAbility.guardian => const Color(0xFF4E87C8),
    DiceAbility.upgrade => const Color(0xFFB35AB8),
  };

  @override
  Widget build(BuildContext context) {
    final size = compact ? 58.0 : 74.0;
    final foreground = used ? Colors.white38 : const Color(0xFFF8EEDC);
    final background = used ? const Color(0xFF626773) : _color;
    final iconSize = compact ? 14.0 : 16.0;

    return Semantics(
      label: '${dice.name}${value == null ? '' : ', значение $value'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF7FFFE1) : Colors.transparent,
            width: selected ? 3 : 0,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x887FFFE1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PixelCubePainter(color: background, used: used),
            ),
            Positioned(
              left: compact ? 8 : 10,
              top: compact ? 8 : 10,
              child: Container(
                width: compact ? 19 : 22,
                height: compact ? 19 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x66202631),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(_icon, size: iconSize, color: foreground),
              ),
            ),
            if (value != null)
              Positioned.fill(
                top: compact ? 24 : 27,
                bottom: compact ? 12 : 15,
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: foreground,
                      fontSize: compact ? 24 : 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: const [
                        Shadow(color: Color(0x99000000), offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            if (!compact && value == null)
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  'D${dice.maxFace}',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (showLevel)
              Positioned(
                right: compact ? 5 : 8,
                bottom: compact ? 5 : 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC202631),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 4 : 5,
                      vertical: 2,
                    ),
                    child: Text(
                      'Ур. ${dice.level}',
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PixelCubePainter extends CustomPainter {
  const _PixelCubePainter({required this.color, required this.used});

  final Color color;
  final bool used;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final left = 4.0;
    final right = size.width - 5;
    final top = 4.0;
    final bottom = size.height - 5;
    final base = used ? const Color(0xFF626773) : color;
    final light = Color.lerp(base, Colors.white, .2)!;
    final dark = Color.lerp(base, Colors.black, .35)!;
    final deep = Color.lerp(base, Colors.black, .55)!;

    paint.color = const Color(0xAA080B12);
    canvas.drawRect(
      Rect.fromLTRB(left + 3, top + 5, right + 2, bottom + 3),
      paint,
    );

    final face = Path()
      ..moveTo(left + 5, top)
      ..lineTo(right - 5, top)
      ..lineTo(right, top + 6)
      ..lineTo(right, bottom - 7)
      ..lineTo(right - 6, bottom)
      ..lineTo(left + 5, bottom)
      ..lineTo(left, bottom - 6)
      ..lineTo(left, top + 6)
      ..close();
    paint.color = base;
    canvas.drawPath(face, paint);

    paint.color = light;
    canvas.drawRect(Rect.fromLTRB(left + 5, top, right - 5, top + 5), paint);
    canvas.drawRect(Rect.fromLTRB(left, top + 6, left + 5, bottom - 6), paint);

    paint.color = dark;
    canvas.drawRect(
      Rect.fromLTRB(right - 5, top + 6, right, bottom - 7),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(left + 5, bottom - 5, right - 6, bottom),
      paint,
    );

    paint.color = deep;
    canvas.drawRect(
      Rect.fromLTRB(left + 8, bottom - 8, right - 8, bottom - 5),
      paint,
    );
    paint.color = Colors.white.withValues(alpha: .35);
    canvas.drawRect(Rect.fromLTWH(left + 8, top + 8, 4, 3), paint);
    canvas.drawRect(Rect.fromLTWH(left + 13, top + 8, 2, 2), paint);
  }

  @override
  bool shouldRepaint(_PixelCubePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.used != used;
}
