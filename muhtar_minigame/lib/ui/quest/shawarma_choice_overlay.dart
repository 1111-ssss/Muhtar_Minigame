import 'package:flutter/material.dart';

/// Обязательный выбор сразу после покупки шаурмы.
class ShawarmaChoiceOverlay extends StatelessWidget {
  const ShawarmaChoiceOverlay({required this.onChoice, super.key});

  final ValueChanged<bool> onChoice;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .82),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                border: Border.all(color: const Color(0xFFFFB05C), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(6, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      color: Color(0xFFFFB05C),
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Шаурма у тебя в руках',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Реши, что сделать с покупкой. Выбор изменит следующую встречу с Ильёй.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    _ChoiceButton(
                      icon: Icons.restaurant,
                      title: 'Съесть самому',
                      subtitle: 'Илья узнает, что шаурма исчезла.',
                      color: const Color(0xFFFF9B4A),
                      onPressed: () => onChoice(true),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceButton(
                      icon: Icons.delivery_dining,
                      title: 'Отнести Илье',
                      subtitle: 'Сохраняет шаурму для доставки.',
                      color: const Color(0xFF78F3D0),
                      onPressed: () => onChoice(false),
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

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $subtitle',
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
        side: BorderSide(color: color),
        minimumSize: const Size.fromHeight(66),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    ),
  );
}
