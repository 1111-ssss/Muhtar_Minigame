import 'package:flutter/foundation.dart';

/// Уведомление, которое показывается всплывающим сообщением в углу экрана.
@immutable
class GameNotification {
  const GameNotification({
    required this.id,
    required this.message,
    required this.type,
  });

  final String id;
  final String message;
  final NotificationType type;
}

enum NotificationType { info, reward, quest, warning }

/// Очередь всплывающих уведомлений. UI слушает через ChangeNotifier.
class NotificationService extends ChangeNotifier {
  final List<GameNotification> _notifications = [];
  int _counter = 0;

  List<GameNotification> get notifications => List.unmodifiable(_notifications);

  void notify(String message, {NotificationType type = NotificationType.info}) {
    _notifications.add(
      GameNotification(id: 'n${_counter++}', message: message, type: type),
    );
    notifyListeners();
  }

  void dismiss(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}
