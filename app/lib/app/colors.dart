import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF08080F);
  static const Color surface = Color(0xFF12121F);
  static const Color surfaceContainer = Color(0xFF1C1C2E);

  // Text / borders
  static const Color onSurfaceVariant = Color(0xFF9090A8);
  static const Color outline = Color(0xFF2A2A40);

  // Zone colors
  static const Color zoneBaseline = Color(0xFF4E6179); // Z1 — cool gray
  static const Color zoneLight = Color(0xFF009DF4); // Z2 — same as hotBlue
  static const Color zoneModerate = Color(0xFF01C653); // Z3 — neon green
  static const Color zoneHard = Color(0xFFFD6C00); // Z4 — hot orange
  static const Color zoneMax = Color(0xFFF71B6D); // Z5 — same as hotPink

  // Accents
  static const Color hotPink = zoneMax;
  static const Color hotBlue = zoneLight;
}
