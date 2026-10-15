import 'package:flutter/material.dart';

import '../../domain/artifact.dart';
import '../../domain/dice.dart';

enum GameSymbol { heart, sword, incoming, shield, heal, fire, upgrade, reroll }

/// Единый набор читаемых игровых символов, независимый от системного шрифта.
class GameIcon extends StatelessWidget {
  const GameIcon(
    this.symbol, {
    this.color = Colors.white,
    this.size = 22,
    super.key,
  });
  final GameSymbol symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SymbolPainter(symbol, color),
  );
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);
  final GameSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (symbol) {
      case GameSymbol.heart:
        path.moveTo(12, 21);
        path.cubicTo(-8, 8, 7, -2, 12, 6);
        path.cubicTo(17, -2, 32, 8, 12, 21);
        canvas.drawPath(path, paint);
      case GameSymbol.sword:
      case GameSymbol.incoming:
        path.moveTo(8, 14);
        path.lineTo(18, 3);
        path.lineTo(22, 2);
        path.lineTo(21, 6);
        path.lineTo(11, 17);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawLine(const Offset(5, 12), const Offset(14, 21), paint);
        canvas.drawLine(const Offset(9, 16), const Offset(3, 22), paint);
        if (symbol == GameSymbol.incoming) {
          canvas.drawLine(const Offset(2, 5), const Offset(9, 5), paint);
        }
      case GameSymbol.shield:
        path.moveTo(12, 2);
        path.lineTo(21, 6);
        path.lineTo(20, 14);
        path.quadraticBezierTo(18, 20, 12, 23);
        path.quadraticBezierTo(6, 20, 4, 14);
        path.lineTo(3, 6);
        path.close();
        paint.style = PaintingStyle.stroke;
        canvas.drawPath(path, paint);
        canvas.drawLine(const Offset(12, 6), const Offset(12, 17), paint);
      case GameSymbol.heal:
        canvas.drawRect(const Rect.fromLTWH(9, 3, 6, 18), paint);
        canvas.drawRect(const Rect.fromLTWH(3, 9, 18, 6), paint);
      case GameSymbol.fire:
        path.moveTo(13, 1);
        path.cubicTo(17, 8, 23, 10, 20, 17);
        path.cubicTo(17, 25, 3, 24, 3, 15);
        path.quadraticBezierTo(3, 10, 8, 7);
        path.quadraticBezierTo(6, 14, 11, 13);
        path.quadraticBezierTo(16, 12, 13, 1);
        canvas.drawPath(path, paint);
      case GameSymbol.upgrade:
        paint.style = PaintingStyle.stroke;
        path.moveTo(5, 11);
        path.lineTo(12, 4);
        path.lineTo(19, 11);
        path.moveTo(5, 20);
        path.lineTo(12, 13);
        path.lineTo(19, 20);
        canvas.drawPath(path, paint);
      case GameSymbol.reroll:
        paint.style = PaintingStyle.stroke;
        canvas.drawArc(
          const Rect.fromLTWH(3, 3, 18, 18),
          0.3,
          5.2,
          false,
          paint,
        );
        path.moveTo(20, 2);
        path.lineTo(20, 8);
        path.lineTo(14, 8);
        canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}

GameSymbol diceSymbol(DiceAbility ability) => switch (ability) {
  DiceAbility.none || DiceAbility.warrior => GameSymbol.sword,
  DiceAbility.doctor => GameSymbol.heal,
  DiceAbility.guardian => GameSymbol.shield,
  DiceAbility.ember => GameSymbol.fire,
  DiceAbility.upgrade => GameSymbol.upgrade,
};

Color diceColor(DiceAbility ability) => switch (ability) {
  DiceAbility.none || DiceAbility.warrior => const Color(0xFFFFC857),
  DiceAbility.doctor => const Color(0xFF75D6A4),
  DiceAbility.ember => const Color(0xFFFF795C),
  DiceAbility.guardian => const Color(0xFF78B7FF),
  DiceAbility.upgrade => const Color(0xFFF58CFF),
};

IconData artifactIcon(Artifact artifact) => switch (artifact) {
  Artifact.truceSeal => Icons.spa_outlined,
  Artifact.ironThread => Icons.shield_outlined,
  Artifact.whetstone => Icons.diamond_outlined,
  Artifact.fieldKit => Icons.medical_services_outlined,
  Artifact.emberHeart => Icons.local_fire_department_outlined,
  Artifact.luckyCharm => Icons.all_inclusive,
};

class ArtifactBadge extends StatelessWidget {
  const ArtifactBadge(
    this.artifact, {
    this.count = 1,
    this.size = 42,
    super.key,
  });
  final Artifact artifact;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        '${artifact.title}${count > 1 ? ' ×$count' : ''}\n${artifact.description}',
    waitDuration: const Duration(milliseconds: 150),
    showDuration: const Duration(seconds: 8),
    constraints: const BoxConstraints(maxWidth: 300),
    child: Semantics(
      label: '${artifact.title}, $count. ${artifact.description}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4E3B62), Color(0xFF241C32)],
          ),
          border: Border.all(color: const Color(0xFFAE8DC6)),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(2, 3),
              blurRadius: 5,
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                artifactIcon(artifact),
                size: size * .58,
                color: const Color(0xFFE8C78B),
              ),
            ),
            if (count > 1)
              Positioned(
                right: 2,
                bottom: 0,
                child: Text('$count', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    ),
  );
}
