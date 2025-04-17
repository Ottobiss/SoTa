import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:developer';

@pragma("vm:entry-point")
Future<void> onNotificationActionReceivedMethod(ReceivedAction action) async {
  if (action.buttonKeyPressed == 'TAKEN') {
    log('✅ Пользователь отметил препарат как принятый!');
  }
}
