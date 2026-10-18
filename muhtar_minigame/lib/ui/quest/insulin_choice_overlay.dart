import 'package:flutter/material.dart';

class InsulinChoiceOverlay extends StatelessWidget {
  const InsulinChoiceOverlay({required this.onChoice, super.key});

  final ValueChanged<bool> onChoice;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .78),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E2B),
              border: Border.all(color: const Color(0xFFB8A4FF), width: 2),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vaccines, color: Color(0xFFD3C7FF), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Шиприц инсулина у тебя в руках',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Реши, что сделать с находкой.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 22),
                  _Choice(
                    title: 'Вколоть',
                    subtitle: 'Использовать найденный шприц сейчас.',
                    color: const Color(0xFFC0AEFF),
                    onPressed: () => onChoice(true),
                  ),
                  const SizedBox(height: 10),
                  _Choice(
                    title: 'Оставить в инвентаре',
                    subtitle: 'Сохранить находку для последующего задания.',
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
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.subtitle, required this.color, required this.onPressed});

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(68),
      padding: const EdgeInsets.all(14),
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Row(
      children: [
        Icon(Icons.arrow_forward_rounded, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}
