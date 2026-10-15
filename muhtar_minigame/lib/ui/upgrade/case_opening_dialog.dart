import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/artifact.dart';
import '../../domain/dice.dart';
import '../../domain/game_content.dart';
import '../battle/dice_visual.dart';
import '../common/game_symbols.dart';

/// Лента создаётся один раз. Результат уже выдан моделью и занимает заранее
/// известную позицию; resize и rebuild не меняют содержимое или награду.
class DiceCaseDialog extends StatefulWidget {
  const DiceCaseDialog({required this.result, super.key});
  final Dice result;
  @override
  State<DiceCaseDialog> createState() => _DiceCaseDialogState();
}

class _DiceCaseDialogState extends State<DiceCaseDialog>
    with SingleTickerProviderStateMixin {
  static const _winner = 24;
  static const _pitch = 104.0;
  late final AnimationController _controller;
  late final List<Dice> _reel;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    final random = Random();
    _reel = List.generate(
      30,
      (index) => index == _winner
          ? widget.result
          : GameContent
                .diceCatalog[random.nextInt(GameContent.diceCatalog.length)]
                .copyWith(level: random.nextInt(6) + 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('Кейс кости'),
      content: SizedBox(
        width: 480,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final done = _controller.isCompleted;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 140,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final progress = Curves.easeOutCubic.transform(
                        _controller.value,
                      );
                      final position = 2 + (_winner - 2) * progress;
                      return ClipRect(
                        child: Stack(
                          children: [
                            Positioned(
                              left:
                                  box.maxWidth / 2 -
                                  _pitch / 2 -
                                  position * _pitch,
                              top: 18,
                              child: Row(
                                children: [
                                  for (final die in _reel)
                                    SizedBox(
                                      width: _pitch,
                                      child: Column(
                                        children: [
                                          DiceVisual(dice: die),
                                          const SizedBox(height: 8),
                                          Text('Ур. ${die.level}'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.primary,
                                size: 30,
                              ),
                            ),
                            Center(
                              child: IgnorePointer(
                                child: Container(
                                  width: _pitch,
                                  height: 124,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFFFCD76),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  done
                      ? '${widget.result.name} · уровень ${widget.result.level}'
                      : 'Открываем…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: done
                      ? () => Navigator.of(context).pop()
                      : () => _controller.value = 1,
                  child: Text(done ? 'Готово' : 'Пропустить прокрутку'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ArtifactCaseDialog extends StatelessWidget {
  const ArtifactCaseDialog({required this.choices, super.key});
  final List<Artifact> choices;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Выберите один артефакт'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final artifact in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  key: ValueKey('choose-${artifact.name}'),
                  onPressed: () => Navigator.of(context).pop(artifact),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          artifactIcon(artifact),
                          color: const Color(0xFFFFC857),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artifact.title,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                artifact.description,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Выбрать позже'),
      ),
    ],
  );
}
