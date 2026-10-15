import 'package:flutter/material.dart';

import '../../game/muhtar_game.dart';
import '../../game_logic/location_transition.dart';

/// Полноэкранный переход: затемнение, название новой локации и обратное fade.
class LocationTransitionOverlay extends StatefulWidget {
  const LocationTransitionOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  State<LocationTransitionOverlay> createState() =>
      _LocationTransitionOverlayState();
}

class _LocationTransitionOverlayState extends State<LocationTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _titleController;
  late Animation<double> _titleSlide;

  LocationTransitionState _transition = const LocationTransitionState.idle();

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _titleSlide = const AlwaysStoppedAnimation(-1.4);
    widget.game.locationTransition.addListener(_onTransitionChanged);
  }

  @override
  void dispose() {
    widget.game.locationTransition.removeListener(_onTransitionChanged);
    _titleController.dispose();
    super.dispose();
  }

  void _onTransitionChanged() {
    final next = widget.game.locationTransition.value;
    if (!mounted) {
      _transition = next;
      return;
    }

    setState(() => _transition = next);
    switch (next.phase) {
      case LocationTransitionPhase.titleDrop:
        _titleSlide = _titleController.drive(
          Tween<double>(begin: -1.4, end: 0),
        );
        _titleController.forward(from: 0);
      case LocationTransitionPhase.titleExit:
        _titleSlide = _titleController.drive(Tween<double>(begin: 0, end: 1.4));
        _titleController.forward(from: 0);
      case LocationTransitionPhase.idle:
      case LocationTransitionPhase.fadeOut:
      case LocationTransitionPhase.titleHold:
      case LocationTransitionPhase.fadeIn:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = _transition.phase;
    final active = phase != LocationTransitionPhase.idle;
    final showTitle =
        phase == LocationTransitionPhase.titleDrop ||
        phase == LocationTransitionPhase.titleHold ||
        phase == LocationTransitionPhase.titleExit;
    final blackVisible = phase != LocationTransitionPhase.fadeIn && active;

    return IgnorePointer(
      ignoring: !active,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: blackVisible ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: const ColoredBox(color: Colors.black),
          ),
          if (showTitle)
            AnimatedBuilder(
              animation: _titleController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.sizeOf(context).height * _titleSlide.value,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20242C),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFFFC857),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(5, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    _transition.locationName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
