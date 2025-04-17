import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'pillbox_channel',
          channelName: 'Напоминания',
          channelDescription: 'Уведомления о приёме препаратов',
          defaultColor: const Color(0xFF1A1F27),
          importance: NotificationImportance.High,
          channelShowBadge: true,
        )
      ],
      debug: true,
    );

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> testNow() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1000,
        channelKey: 'pillbox_channel',
        title: '🔔 Тест уведомления',
        body: 'Ха! Оно работает! Я так и знал!',
      ),
    );
  }

  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    for (var weekday in weekdays) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id + weekday,
          channelKey: 'pillbox_channel',
          title: title,
          body: body,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'TAKEN',
            label: 'Принято',
            actionType: ActionType.Default,
          ),
        ],
        schedule: NotificationCalendar(
          weekday: weekday,
          hour: hour,
          minute: minute,
          second: 0,
          millisecond: 0,
          repeats: true,
        ),
      );
    }
  }
}
