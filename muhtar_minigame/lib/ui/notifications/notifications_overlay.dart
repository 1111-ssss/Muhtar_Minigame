import 'dart:async';

import 'package:flutter/material.dart';

import '../../game_logic/notification_service.dart';

/// Компактная стопка плавающих уведомлений внизу по центру экрана.
class NotificationsOverlay extends StatefulWidget {
  const NotificationsOverlay(this.notifications, {super.key});

  final NotificationService notifications;

  @override
  State<NotificationsOverlay> createState() => _NotificationsOverlayState();
}

class _NotificationsOverlayState extends State<NotificationsOverlay> {
  final _listKey = GlobalKey<AnimatedListState>();
  late List<GameNotification> _visible;
  final Set<String> _scheduledDismissals = <String>{};

  @override
  void initState() {
    super.initState();
    _visible = List.of(widget.notifications.notifications);
    widget.notifications.addListener(_onChanged);
    for (final notification in _visible) {
      _scheduleDismissal(notification);
    }
  }

  @override
  void dispose() {
    widget.notifications.removeListener(_onChanged);
    super.dispose();
  }

  void _scheduleDismissal(GameNotification notification) {
    if (!_scheduledDismissals.add(notification.id)) return;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.notifications.dismiss(notification.id);
    });
  }

  void _onChanged() {
    if (!mounted) return;
    final next = widget.notifications.notifications;
    for (final notification in next) {
      _scheduleDismissal(notification);
    }

    final nextIds = next.map((notification) => notification.id).toSet();
    for (var index = _visible.length - 1; index >= 0; index--) {
      if (!nextIds.contains(_visible[index].id)) {
        final removed = _visible.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _ToastTransition(
            notification: removed,
            animation: animation,
          ),
          duration: const Duration(milliseconds: 220),
        );
      }
    }

    final visibleIds = _visible.map((notification) => notification.id).toSet();
    for (final notification in next) {
      if (visibleIds.contains(notification.id)) continue;
      final index = _visible.length;
      _visible.add(notification);
      _listKey.currentState?.insertItem(
        index,
        duration: const Duration(milliseconds: 240),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: SafeArea(
      minimum: const EdgeInsets.only(bottom: 22, left: 16, right: 16),
      child: IgnorePointer(
        child: SizedBox(
          width: 520,
          child: AnimatedList(
            key: _listKey,
            initialItemCount: _visible.length,
            shrinkWrap: true,
            reverse: true,
            itemBuilder: (context, index, animation) => _ToastTransition(
              notification: _visible[index],
              animation: animation,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ToastTransition extends StatelessWidget {
  const _ToastTransition({required this.notification, required this.animation});

  final GameNotification notification;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .18),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Toast(notification: notification),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.notification});

  final GameNotification notification;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (notification.type) {
      NotificationType.reward => (Colors.green, Icons.monetization_on),
      NotificationType.quest => (Colors.purple, Icons.assignment),
      NotificationType.warning => (Colors.orange, Icons.warning),
      NotificationType.info => (Colors.blueGrey, Icons.info),
    };

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xDD171D2B).withValues(alpha: .86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.withValues(alpha: .95), size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  notification.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
