import 'package:flutter/material.dart';

import '../../game_logic/notification_service.dart';

/// Всплывающие уведомления: стопка сообщений в правом верхнем углу.
class NotificationsOverlay extends StatefulWidget {
  const NotificationsOverlay(this.notifications, {super.key});

  final NotificationService notifications;

  @override
  State<NotificationsOverlay> createState() => _NotificationsOverlayState();
}

class _NotificationsOverlayState extends State<NotificationsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.notifications.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.notifications.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});

    // Уведомления исчезают сами через 3 секунды.
    for (final n in widget.notifications.notifications) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) widget.notifications.dismiss(n.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final n in widget.notifications.notifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Toast(notification: n),
                ),
            ],
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

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              notification.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
