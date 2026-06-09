import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.hotPink,
    brightness: Brightness.light,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: AppColors.hotPink,
    onPrimary: Colors.black,
    secondary: AppColors.hotBlue,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
    error: AppColors.hotPink,
    onError: Colors.black,
    surfaceContainerHighest: AppColors.surfaceContainer,
    inverseSurface: Colors.white,
    onInverseSurface: Colors.black,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );
}
