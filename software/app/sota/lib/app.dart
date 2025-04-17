import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/schedule/pages/schedule_page.dart';

class SotaApp extends StatelessWidget {
  const SotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'СОТА',
      theme: buildAppTheme(),
      home: const SchedulePage(),
    );
  }
}
