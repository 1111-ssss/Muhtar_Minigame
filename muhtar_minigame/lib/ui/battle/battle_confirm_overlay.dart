import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/muhtar_game.dart';

/// Подтверждение боя не расходует ход и не создаёт BattleEngine до согласия.
class BattleConfirmOverlay extends StatefulWidget {
  const BattleConfirmOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  State<BattleConfirmOverlay> createState() => _BattleConfirmOverlayState();
}

class _BattleConfirmOverlayState extends State<BattleConfirmOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.registerWindowCloseHandler(
      MuhtarGame.overlayBattleConfirm,
      widget.game.cancelBattle,
    );
  }

  @override
  void dispose() {
    widget.game.unregisterWindowCloseHandler(MuhtarGame.overlayBattleConfirm);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enemy = widget.game.pendingBattleEnemy;
    if (enemy == null) return const SizedBox.shrink();
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.game.confirmBattle();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.black.withValues(alpha: .72),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFF171923),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFFFC857), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sports_martial_arts,
                        color: Color(0xFFFFC857),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Начать бой с ${enemy.label}?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Можно вступить в бой или отойти и продолжить исследование.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: widget.game.cancelBattle,
                            child: const Text('Отказаться'),
                          ),
                          FilledButton(
                            onPressed: widget.game.confirmBattle,
                            child: const Text('Вступить в бой'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
