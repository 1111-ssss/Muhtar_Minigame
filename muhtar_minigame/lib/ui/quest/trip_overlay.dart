import 'dart:math' as math;

import 'package:flutter/material.dart';

class TripOverlay extends StatefulWidget {
  const TripOverlay({super.key});

  @override
  State<TripOverlay> createState() => _TripOverlayState();
}

class _TripOverlayState extends State<TripOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _TripPainter(_controller.value),
          ),
        ),
      ],
    ),
  );
}

class _TripPainter extends CustomPainter {
  const _TripPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final centerA = Offset(
      size.width * (.5 + math.cos(phase) * .35),
      size.height * (.45 + math.sin(phase * 1.3) * .35),
    );
    final centerB = Offset(
      size.width * (.5 + math.sin(phase * .8) * .4),
      size.height * (.5 + math.cos(phase * 1.1) * .4),
    );
    // Белый слой в режиме difference инвертирует исходные цвета всего окна.
    // Поверх него движется насыщенный линейный градиент, поэтому эффект
    // заметен даже на тёмной карте и не сводится к лёгкой цветной дымке.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.difference,
    );
    final paint = Paint()
      ..blendMode = BlendMode.color
      ..shader = LinearGradient(
        begin: Alignment(
          -1 + math.sin(phase) * .8,
          -1,
        ),
        end: Alignment(
          1 + math.sin(phase) * .8,
          1,
        ),
        colors: const [
          Color(0xCC00FFFF),
          Color(0xCC6A2BFF),
          Color(0xCCFF168F),
          Color(0xCCFFE600),
        ],
        stops: const [0, .32, .67, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    canvas.drawCircle(
      centerA,
      size.longestSide * .42,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: const [Color(0x331AFFE6), Color(0x001AFFE6)],
        ).createShader(Rect.fromCircle(center: centerA, radius: size.longestSide * .42)),
    );
    canvas.drawCircle(
      centerB,
      size.longestSide * .36,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: const [Color(0x33FF48C4), Color(0x00FF48C4)],
        ).createShader(Rect.fromCircle(center: centerB, radius: size.longestSide * .36)),
    );
  }

  @override
  bool shouldRepaint(covariant _TripPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
