import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';

void main() {
  test('notification service queues, dismisses and clears messages', () {
    final service = NotificationService();
    var changes = 0;
    service.addListener(() => changes++);

    service.notify('Готово');
    service.notify('Награда', type: NotificationType.reward);

    expect(service.notifications, hasLength(2));
    expect(service.notifications.first.id, 'n0');
    expect(service.notifications.last.type, NotificationType.reward);
    expect(service.notifications.map((item) => item.message), [
      'Готово',
      'Награда',
    ]);

    service.dismiss('n0');
    expect(service.notifications, hasLength(1));
    expect(service.notifications.single.message, 'Награда');

    service.dismiss('missing');
    expect(service.notifications, hasLength(1));

    service.clear();
    expect(service.notifications, isEmpty);
    expect(changes, 5);
  });
}
