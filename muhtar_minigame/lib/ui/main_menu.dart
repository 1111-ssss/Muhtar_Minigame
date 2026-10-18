import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_logic/game_state.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    required this.gameState,
    required this.hasSave,
    required this.onStart,
    required this.onNewGame,
    super.key,
  });

  final GameState gameState;
  final bool hasSave;
  final Future<void> Function() onStart;
  final Future<void> Function() onNewGame;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  bool _busy = false;

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
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1114), Color(0xFF151B2B), Color(0xFF231B2D)],
        ),
      ),
      child: CustomPaint(
        painter: const _MainMenuBackdropPainter(),
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
                        const _MenuEyebrow(),
                        const SizedBox(height: 26),
                        const Text(
                          'МУХТАР',
                          key: ValueKey('main-menu-title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            height: .95,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'MINIGAME',
                          style: TextStyle(
                            color: Color(0xFF62E6E8),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'ИЗОМЕТРИЧЕСКАЯ RPG О КУБИКАХ,\nМОНЕТАХ И НЕОЖИДАННЫХ КВЕСТАХ',
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
                        AnimatedBuilder(
                          animation: widget.gameState,
                          builder: (context, _) => _ProgressCard(
                            hasSave: widget.hasSave,
                            playerName: widget.gameState.playerName,
                            level: widget.gameState.level,
                            coins: widget.gameState.coins,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 12),
                        _MenuButton(
                          key: const ValueKey('main-menu-new-game'),
                          label: 'Новая игра',
                          caption: 'Стереть текущий прогресс и начать сначала',
                          icon: Icons.restart_alt_rounded,
                          busy: _busy,
                          onPressed: () => _run(widget.onNewGame),
                        ),
                        const SizedBox(height: 30),
                        const _ControlsHint(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MenuEyebrow extends StatelessWidget {
  const _MenuEyebrow();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF202C3C).withValues(alpha: .84),
      border: Border.all(color: const Color(0xFF52677B)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        'ОДИНОЧНАЯ ИГРА  •  OFFLINE',
        style: TextStyle(
          color: Color(0xFFFFD166),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xCC111923),
      border: Border.all(color: const Color(0xFF35495D)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF26384A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF62E6E8)),
          ),
          child: const Icon(
            Icons.person_pin_rounded,
            color: Color(0xFFBCEFF0),
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSave ? playerName : 'Новый забег',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasSave ? 'Уровень $level' : 'Вокзал ждёт героя',
                style: const TextStyle(color: Color(0xFF9EB0C2), fontSize: 12),
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
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.onPressed,
    required this.busy,
    this.primary = false,
    super.key,
  });

  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;
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
              if (busy)
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

class _ControlsHint extends StatelessWidget {
  const _ControlsHint();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF8195A9)),
      const SizedBox(width: 6),
      const Text(
        'ТАП ДЛЯ ДВИЖЕНИЯ',
        style: TextStyle(
          color: Color(0xFF9BAABD),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
      Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0xFF52677B),
      ),
      const Icon(Icons.keyboard_alt_rounded, size: 16, color: Color(0xFF8195A9)),
      const SizedBox(width: 6),
      const Text(
        'WASD / СТРЕЛКИ',
        style: TextStyle(
          color: Color(0xFF9BAABD),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    ],
  );
}

class _MainMenuBackdropPainter extends CustomPainter {
  const _MainMenuBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x223D6070)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), gridPaint);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        gridPaint,
      );
    }

    final tilePaint = Paint()..color = const Color(0x164FD1D4);
    final tiles = [
      (Offset(size.width * .08, size.height * .18), 84.0),
      (Offset(size.width * .85, size.height * .25), 118.0),
      (Offset(size.width * .16, size.height * .82), 128.0),
      (Offset(size.width * .78, size.height * .78), 72.0),
    ];
    for (final (center, width) in tiles) {
      final path = Path()
        ..moveTo(center.dx, center.dy - width / 2)
        ..lineTo(center.dx + width, center.dy)
        ..lineTo(center.dx, center.dy + width / 2)
        ..lineTo(center.dx - width, center.dy)
        ..close();
      canvas.drawPath(path, tilePaint);
    }

    final railPaint = Paint()
      ..color = const Color(0x187C5B8E)
      ..strokeWidth = 3;
    final railY = size.height * .88;
    canvas.drawLine(Offset(0, railY), Offset(size.width, railY), railPaint);
    canvas.drawLine(
      Offset(0, railY + 14),
      Offset(size.width, railY + 14),
      railPaint,
    );
    for (var x = -20.0; x < size.width + 80; x += 46) {
      canvas.drawLine(
        Offset(x, railY - 8),
        Offset(x + 26, railY + 22),
        railPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MainMenuBackdropPainter oldDelegate) => false;
}
