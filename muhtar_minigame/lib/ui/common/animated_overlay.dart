import 'package:flutter/material.dart';

import '../../game/muhtar_game.dart';

/// Общая оболочка для полноэкранных окон с единым enter/exit motion.
class AnimatedOverlay extends StatefulWidget {
  const AnimatedOverlay({
    required this.game,
    required this.overlay,
    required this.builder,
    super.key,
  });

  final MuhtarGame game;
  final String overlay;
  final Widget Function(BuildContext context, VoidCallback close) builder;

  @override
  State<AnimatedOverlay> createState() => _AnimatedOverlayState();
}

class _AnimatedOverlayState extends State<AnimatedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _motion;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _motion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.game.registerWindowCloseHandler(widget.overlay, _close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    widget.game.unregisterWindowCloseHandler(widget.overlay);
    _motion.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _controller.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.game.overlays.remove(widget.overlay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _motion,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(_motion),
        child: widget.builder(context, _close),
      ),
    );
  }
}
