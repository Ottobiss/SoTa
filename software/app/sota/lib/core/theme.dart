import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF8F0E3),
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1F27)),
    useMaterial3: true,
    fontFamily: 'Widock',
  );
}
