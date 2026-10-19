import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_logic/game_state.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    required this.gameState,
    required this.hasSave,
    required this.onStart,
    required this.onNewGame,
    required this.onSettings,
    super.key,
  });

  final GameState gameState;
  final bool hasSave;
  final Future<void> Function() onStart;
  final Future<void> Function() onNewGame;
  final Future<void> Function(BuildContext context) onSettings;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _motionDisabled = false;
  late final AnimationController _backdropController;

  @override
  void initState() {
    super.initState();
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionDisabled = MediaQuery.of(context).disableAnimations;
    if (motionDisabled == _motionDisabled) return;

    _motionDisabled = motionDisabled;
    if (motionDisabled) {
      _backdropController.stop(canceled: false);
    } else {
      _backdropController.repeat();
    }
  }

  @override
  void dispose() {
    _backdropController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF070A19),
    body: AnimatedBuilder(
      animation: _backdropController,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0.0, constraints.maxHeight - 44),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'BUBER Adventure',
                          key: ValueKey('main-menu-title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            height: .95,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'УДИВИТЕЛЬНЫЕ ПРИКЛЮЧЕНИЯ\nНЕПРИМЕЧАТЕЛЬНОГО ГЕРОЯ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD1D9E8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        key: const ValueKey('main-menu-panel'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xE6172530),
                          border: Border.all(
                            color: const Color(0xFF3D5668),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 8),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: widget.gameState,
                              builder: (context, _) => _ProgressCard(
                                hasSave: widget.hasSave,
                                playerName: widget.gameState.playerName,
                                level: widget.gameState.level,
                                coins: widget.gameState.coins,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _MenuButton(
                              key: const ValueKey('main-menu-start'),
                              label: widget.hasSave
                                  ? 'Продолжить игру'
                                  : 'Начать игру',
                              caption: widget.hasSave
                                  ? 'Вернуться к последнему сохранению'
                                  : 'Открыть вокзал и начать приключение',
                              icon: widget.hasSave
                                  ? Icons.play_arrow_rounded
                                  : Icons.flag_rounded,
                              primary: true,
                              busy: _busy,
                              onPressed: () => _run(widget.onStart),
                            ),
                            const SizedBox(height: 10),
                            _MenuButton(
                              key: const ValueKey('main-menu-new-game'),
                              label: 'Новая игра',
                              caption:
                                  'Стереть текущий прогресс и начать сначала',
                              icon: Icons.restart_alt_rounded,
                              busy: _busy,
                              onPressed: () => _run(widget.onNewGame),
                            ),
                            const SizedBox(height: 10),
                            _MenuButton(
                              key: const ValueKey('main-menu-settings'),
                              label: 'Настройки',
                              caption: 'Звук, музыка и параметры игры',
                              icon: Icons.settings_outlined,
                              busy: _busy,
                              showBusyIndicator: false,
                              onPressed: () => unawaited(
                                widget.onSettings(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) => CustomPaint(
        key: const ValueKey('main-menu-background'),
        painter: _MainMenuBackdropPainter(
          progress: _backdropController.value,
          reducedMotion: MediaQuery.of(context).disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.hasSave,
    required this.playerName,
    required this.level,
    required this.coins,
  });

  final bool hasSave;
  final String playerName;
  final int level;
  final int coins;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: hasSave
        ? '$playerName, уровень $level, монет: $coins'
        : 'Новый забег, сохранение не найдено',
    child: Container(
      key: const ValueKey('main-menu-progress-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC111923),
        border: Border.all(color: const Color(0xFF35495D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF26384A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF62E6E8)),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: Color(0xFFBCEFF0),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSave ? playerName : 'Новый забег',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSave ? 'Уровень $level' : 'Вокзал ждёт героя',
                  style: const TextStyle(
                    color: Color(0xFF9EB0C2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasSave) ...[
            const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD166)),
            const SizedBox(width: 5),
            Text(
              '$coins',
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.onPressed,
    required this.busy,
    this.showBusyIndicator = true,
    this.primary = false,
    super.key,
  });

  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;
  final bool showBusyIndicator;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? const Color(0xFF101A20)
        : const Color(0xFFE5EDF7);
    final background = primary
        ? const Color(0xFFFFD166)
        : const Color(0xCC182432);
    return Semantics(
      button: true,
      label: '$label. $caption',
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            disabledBackgroundColor: background.withValues(alpha: .45),
            foregroundColor: foreground,
            disabledForegroundColor: foreground.withValues(alpha: .7),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: primary
                    ? const Color(0xFFFFE3A1)
                    : const Color(0xFF52677B),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 27),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy && showBusyIndicator)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(Icons.arrow_forward_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainMenuBackdropPainter extends CustomPainter {
  const _MainMenuBackdropPainter({
    required this.progress,
    required this.reducedMotion,
  });

  final double progress;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final t = reducedMotion ? 0.0 : progress * math.pi * 2;
    final bounds = Offset.zero & size;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070A19),
            Color(0xFF101A38),
            Color(0xFF28162F),
          ],
        ).createShader(bounds),
    );

    _drawGlow(
      canvas,
      Offset(size.width * .14, size.height * .18),
      size.width * .42,
      const Color(0xFF2B8DFF),
      .14,
    );
    _drawGlow(
      canvas,
      Offset(size.width * .88, size.height * .72),
      size.width * .48,
      const Color(0xFFE94DAB),
      .1,
    );

    _drawPerspectiveGrid(canvas, size, t);
    _drawOrbit(canvas, size, t);
    _drawFloatingShards(canvas, size, t);
    _drawStars(canvas, size, t);

    // A soft vignette keeps the moving decoration away from the text readable.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            const Color(0x00070A19),
            const Color(0x30070A19),
            const Color(0xB8070A19),
          ],
          stops: const [.28, .68, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _MainMenuBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.reducedMotion != reducedMotion;

  void _drawGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * .28),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size, double t) {
    final horizon = size.height * .42;
    final gridPaint = Paint()
      ..color = const Color(0x193B7BB8)
      ..strokeWidth = 1;

    for (var index = 0; index <= 9; index++) {
      final fraction = index / 9;
      final y =
          horizon + (math.pow(fraction, 1.65) * size.height * .78).toDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final drift = math.sin(t) * size.width * .018;
    for (var index = -8; index <= 16; index++) {
      final bottomX = index * size.width / 8 + drift;
      canvas.drawLine(
        Offset(size.width / 2, horizon),
        Offset(bottomX, size.height * 1.12),
        gridPaint,
      );
    }
  }

  void _drawOrbit(Canvas canvas, Size size, double t) {
    final center = Offset(size.width * .82, size.height * .25);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x327DD5F6);
    final orbitRect = Rect.fromCenter(
      center: center,
      width: size.width * .42,
      height: size.height * .18,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * .12);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(orbitRect, orbitPaint);
    canvas.drawOval(
      orbitRect.deflate(14),
      orbitPaint..color = const Color(0x1D3CB6D9),
    );
    canvas.restore();

    final pulse = .9 + math.sin(t * 1.4) * .08;
    _drawGlow(canvas, center, 72 * pulse, const Color(0xFF51D9FF), .1);
    canvas.drawCircle(
      center,
      7 * pulse,
      Paint()..color = const Color(0xA89BEAFF),
    );
    canvas.drawCircle(
      center,
      14 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x589BEAFF),
    );
  }

  void _drawFloatingShards(Canvas canvas, Size size, double t) {
    const shards = [
      (x: .12, y: .29, scale: .78, phase: .2, color: Color(0xFF5BE1D0)),
      (x: .91, y: .46, scale: .62, phase: 2.4, color: Color(0xFFFFC46B)),
      (x: .08, y: .76, scale: .48, phase: 4.1, color: Color(0xFFB88CFF)),
      (x: .77, y: .85, scale: .9, phase: 5.3, color: Color(0xFFFF76C8)),
    ];

    for (final shard in shards) {
      final wave = math.sin(t * .75 + shard.phase);
      final center = Offset(
        size.width * shard.x + wave * 10,
        size.height * shard.y + math.cos(t + shard.phase) * 8,
      );
      final width = 24 * shard.scale;
      final height = 12 * shard.scale;
      final path = Path()
        ..moveTo(center.dx, center.dy - height)
        ..lineTo(center.dx + width, center.dy)
        ..lineTo(center.dx, center.dy + height)
        ..lineTo(center.dx - width, center.dy)
        ..close();

      _drawGlow(canvas, center, width * 2.6, shard.color, .06);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = shard.color.withValues(alpha: .32),
      );
      canvas.drawCircle(
        center,
        2.5 * shard.scale,
        Paint()..color = shard.color.withValues(alpha: .62),
      );
    }
  }

  void _drawStars(Canvas canvas, Size size, double t) {
    const stars = [
      (x: .22, y: .12, radius: 1.4, phase: .1),
      (x: .38, y: .23, radius: 1.0, phase: 1.2),
      (x: .59, y: .11, radius: 1.8, phase: 2.6),
      (x: .73, y: .37, radius: 1.1, phase: 3.8),
      (x: .29, y: .71, radius: 1.5, phase: 4.6),
      (x: .87, y: .14, radius: 1.0, phase: 5.4),
    ];

    for (final star in stars) {
      final twinkle = .2 + (math.sin(t * 1.8 + star.phase) + 1) * .14;
      canvas.drawCircle(
        Offset(size.width * star.x, size.height * star.y),
        star.radius,
        Paint()..color = const Color(0xFFB9D8FF).withValues(alpha: twinkle),
      );
    }
  }
}
