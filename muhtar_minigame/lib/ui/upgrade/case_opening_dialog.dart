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
                 .copyWith(level: random.nextInt(3) + 1),
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
       title: const Text('Ящик костей'),
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

enum ArtifactBoxChoice { modifier }

class ArtifactCaseDialog extends StatelessWidget {
  const ArtifactCaseDialog({
    required this.choices,
    this.showModifier = true,
    super.key,
  });
  final List<Artifact> choices;
  final bool showModifier;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ящик артефактов'),
    content: SizedBox(
      width: 980,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showModifier)
              _ModifierChoiceCard(
                onPressed: () =>
                    Navigator.of(context).pop(ArtifactBoxChoice.modifier),
              ),
            for (final artifact in choices) _ArtifactChoiceCard(artifact),
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

class _ModifierChoiceCard extends StatelessWidget {
  const _ModifierChoiceCard({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('choose-modifier'),
    width: 230,
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: OutlinedButton(
        onPressed: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(
            children: [
              Icon(Icons.auto_fix_high, color: Color(0xFFB9A9FF), size: 34),
              SizedBox(height: 10),
              Text(
                'Наложить модификатор на кость',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
              SizedBox(height: 8),
              Text(
                'Сначала прокрутится список модификаторов, затем выберите кость.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ArtifactChoiceCard extends StatelessWidget {
  const _ArtifactChoiceCard(this.artifact);
  final Artifact artifact;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('choose-${artifact.name}'),
    width: 230,
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(artifact),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(
            children: [
              Icon(
                artifactIcon(artifact),
                color: const Color(0xFFFFC857),
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                artifact.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                artifact.rarity.title,
                style: const TextStyle(color: Color(0xFFFFD58E)),
              ),
              const SizedBox(height: 8),
              Text(
                artifact.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ModifierRollDialog extends StatefulWidget {
  const ModifierRollDialog({required this.result, super.key});
  final DiceModifier result;

  @override
  State<ModifierRollDialog> createState() => _ModifierRollDialogState();
}

class _ModifierRollDialogState extends State<ModifierRollDialog>
    with SingleTickerProviderStateMixin {
  static const _winner = 16;
  static const _pitch = 190.0;
  late final AnimationController _controller;
  late final List<DiceModifier> _reel;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    final random = Random();
    final modifiers = DiceModifier.values
        .where((modifier) => modifier != DiceModifier.none)
        .toList();
    _reel = List.generate(
      _winner + 3,
      (index) => index == _winner
          ? widget.result
          : modifiers[random.nextInt(modifiers.length)],
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
      title: const Text('Прокрутка модификатора'),
      content: SizedBox(
        width: 520,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final done = _controller.isCompleted;
            final progress = Curves.easeOutCubic.transform(_controller.value);
            final position = 1 + (_winner - 1) * progress;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 112,
                  child: LayoutBuilder(
                    builder: (context, box) => ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            left:
                                box.maxWidth / 2 -
                                _pitch / 2 -
                                position * _pitch,
                            top: 16,
                            child: Row(
                              children: [
                                for (final modifier in _reel)
                                  SizedBox(
                                    width: _pitch,
                                    child: Center(
                                      child: Text(
                                        modifier.title,
                                        style: const TextStyle(fontSize: 19),
                                      ),
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
                                height: 70,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFB9A9FF),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  done ? widget.result.description : 'Прокручиваем…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: done
                      ? () => Navigator.of(context).pop()
                      : () => _controller.value = 1,
                  child: Text(done ? 'Выбрать кость' : 'Пропустить прокрутку'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class DiceModifierTargetDialog extends StatelessWidget {
  const DiceModifierTargetDialog({required this.dice, super.key});
  final List<Dice> dice;

  @override
  Widget build(BuildContext context) {
    final targets = [
      for (var index = 0; index < dice.length; index++)
        if (dice[index].modifier == DiceModifier.none) index,
    ];
    return AlertDialog(
      title: const Text('Выберите кость из инвентаря'),
      content: SizedBox(
        width: 560,
        child: targets.isEmpty
            ? const Text(
                'Свободных костей нет. Закройте окно и добавьте кость, '
                'чтобы завершить применение модификатора.',
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: targets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, position) {
                  final index = targets[position];
                  final die = dice[index];
                  return OutlinedButton(
                    key: ValueKey('apply-modifier-$index'),
                    onPressed: () => Navigator.of(context).pop(index),
                    child: Row(
                      children: [
                        DiceVisual(dice: die, compact: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${die.name} · уровень ${die.level}',
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Позже'),
        ),
      ],
    );
  }
}
