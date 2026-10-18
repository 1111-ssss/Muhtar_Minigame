import 'package:flutter/material.dart';

/// Небольшое подтверждение для предмета, лежащего на карте.
///
/// В отличие от [SearchOverlay] это не мини-игра на десять нажатий: игрок
/// сначала осматривает находку, а затем сам решает, забрать её или оставить.
class PotatoPickupOverlay extends StatelessWidget {
  const PotatoPickupOverlay({
    required this.onPickUp,
    required this.onClose,
    super.key,
  });

  final VoidCallback onPickUp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xB8070A10),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Semantics(
            key: const ValueKey('potato-pickup-dialog'),
            container: true,
            namesRoute: true,
            label: 'Диалог: картошка найдена на Мосту',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF171D2B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE1A45B),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x553C2418),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'НАХОДКА НА МОСТУ',
                              style: TextStyle(
                                color: Color(0xFFFFD48A),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('potato-pickup-close'),
                            tooltip: 'Оставить картошку',
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white70,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(
                        height: 112,
                        width: 150,
                        child: CustomPaint(painter: _PotatoPickupPainter()),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Картошка',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Кто-то оставил её прямо на настиле. Можно подобрать находку и отнести её сотруднику ПВЗ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        key: const ValueKey('potato-pickup'),
                        onPressed: onPickUp,
                        icon: const Icon(Icons.backpack_rounded),
                        label: const Text('Подобрать картошку'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE1A45B),
                          foregroundColor: const Color(0xFF2C1C18),
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const ValueKey('potato-pickup-cancel'),
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0x668E9AAF)),
                        ),
                        child: const Text('Оставить на месте'),
                      ),
                    ],
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

class _PotatoPickupPainter extends CustomPainter {
  const _PotatoPickupPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .58);
    final shadow = Paint()..color = const Color(0x663C2418);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 3, center.dy + 19),
        width: 88,
        height: 18,
      ),
      shadow,
    );

    final potato = Paint()..color = const Color(0xFFC98A4B);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 92, height: 66),
      potato,
    );
    potato.color = const Color(0xFFE3B56C);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 20, center.dy - 14),
        width: 26,
        height: 12,
      ),
      potato,
    );
    potato.color = const Color(0xFF5D3D2A);
    for (final hole in const [
      Offset(-18, -3),
      Offset(13, 10),
      Offset(20, -15),
    ]) {
      canvas.drawCircle(center + hole, 3, potato);
    }

    final leaf = Paint()..color = const Color(0xFF6FAE62);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 29, center.dy - 32),
        width: 24,
        height: 12,
      ),
      leaf,
    );
    canvas.drawLine(
      Offset(center.dx + 16, center.dy - 20),
      Offset(center.dx + 29, center.dy - 32),
      Paint()
        ..color = const Color(0xFF4B7C4A)
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _PotatoPickupPainter oldDelegate) => false;
}
