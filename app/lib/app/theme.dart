import 'package:flutter/material.dart';

const Color _heartRed = Color(0xFFD32F2F);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _heartRed,
    brightness: Brightness.light,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _heartRed,
    brightness: Brightness.dark,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}
