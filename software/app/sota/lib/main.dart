import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/notification_service.dart';
import 'notification_controller.dart';
import 'features/schedule/pages/schedule_page.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();

  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onNotificationActionReceivedMethod,
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  runApp(const SotaApp());
}

class SotaApp extends StatelessWidget {
  const SotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'СОТА',
      theme: ThemeData(
        fontFamily: 'Widock',
        scaffoldBackgroundColor: const Color(0xFFF8F0E3),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1F27)),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, letterSpacing: 0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      home: const SchedulePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
