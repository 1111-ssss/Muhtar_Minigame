import 'package:flutter/material.dart';

import 'game_symbols.dart';

/// Размер остаётся стабильным, меняются только число, прозрачность и scale.
class AnimatedStat extends StatelessWidget {
  const AnimatedStat({
    required this.symbol,
    required this.value,
    required this.label,
    required this.color,
    this.alwaysVisible = false,
    this.fontSize = 20,
    this.valueText,
    super.key,
  });

  final GameSymbol symbol;
  final int value;
  final String label;
  final Color color;
  final bool alwaysVisible;
  final double fontSize;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: '$label: ${valueText ?? value}',
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduced ? 140 : 252),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: reduced ? 1 : .94,
              end: 1,
            ).animate(animation),
            child: child,
          ),
        ),
        child: value == 0 && !alwaysVisible
            ? const SizedBox.shrink(key: ValueKey('hidden'))
            : Semantics(
                key: ValueKey(value),
                label: '$label: ${valueText ?? value}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon(symbol, color: color, size: fontSize * 1.15),
                    const SizedBox(width: 5),
                    Text(
                      valueText ?? '$value',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
