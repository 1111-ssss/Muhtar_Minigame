import 'package:flutter/material.dart';

import '../../game_logic/game_state.dart';
import '../../game/muhtar_game.dart';
import '../common/animated_stat.dart';
import '../common/game_symbols.dart';

/// HUD: монеты, опыт/уровень, текущая локация и компактные действия.
class HudOverlay extends StatelessWidget {
  const HudOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game.gameState,
      builder: (context, _) {
        final state = game.gameState;
        final completedQuests = state.completedQuests.length;
        return Stack(
          children: [
            Positioned(
              top: 8,
              right: 10,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HudAction(
                      tooltip: 'Инвентарь',
                      icon: Icons.backpack_outlined,
                      onPressed: game.openInventory,
                    ),
                    const SizedBox(width: 6),
                    _HudAction(
                      tooltip: 'Задания',
                      icon: Icons.assignment_outlined,
                      badge: completedQuests,
                      onPressed: game.openQuests,
                    ),
                    const SizedBox(width: 6),
                    _HudAction(
                      tooltip: 'Настройки',
                      icon: Icons.settings_outlined,
                      onPressed: game.openSettings,
                    ),
                  ],
                ),
              ),
            ),
            // Верхняя панель: монеты, опыт, локация.
            Positioned(
              top: 16,
              left: 16,
              right: 178,
              child: SafeArea(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(
                      icon: Icons.monetization_on_outlined,
                      label: '${state.coins}',
                      color: Colors.amber.shade700,
                    ),
                    _Chip(
                      icon: Icons.auto_awesome,
                      label: 'Ур. ${state.level}',
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(
                      key: const ValueKey('hud-xp-bar'),
                      width: 180,
                      child: _XpBar(state: state),
                    ),
                    _HpChip(state: state),
                    _Chip(
                      icon: Icons.map,
                      label: game.world_.location.name,
                      color: Colors.green.shade700,
                      maxWidth: 170,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HudAction extends StatelessWidget {
  const _HudAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              color: Colors.white,
              icon: Icon(icon, size: 23),
              onPressed: onPressed,
            ),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 19,
                    minHeight: 19,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE84D68),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF171923),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.maxWidth = 170,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HpChip extends StatelessWidget {
  const _HpChip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedStat(
        symbol: GameSymbol.heart,
        value: state.playerHp,
        valueText: '${state.playerHp}/${state.playerMaxHp}',
        label: 'Здоровье (максимум ${state.playerMaxHp})',
        color: const Color(0xFFFF6A86),
        alwaysVisible: true,
        fontSize: 16,
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Опыт: ${state.xp}/${state.xpToNext}',
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (state.xp / state.xpToNext).clamp(0.0, 1.0).toDouble(),
            child: Container(color: Colors.cyan),
          ),
        ),
      ),
    );
  }
}
