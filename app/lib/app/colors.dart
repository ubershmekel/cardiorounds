import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF08080F);
  static const Color surface = Color(0xFF12121F);
  static const Color surfaceContainer = Color(0xFF1C1C2E);

  // Accents
  static const Color hotPink = Color(0xFFFF2D7A);
  static const Color hotBlue = Color(0xFF00D4FF);

  // Text / borders
  static const Color onSurfaceVariant = Color(0xFF9090A8);
  static const Color outline = Color(0xFF2A2A40);

  // Zone colors
  static const Color zoneBaseline = Color(0xFF6B6B80); // Z1 — cool gray
  static const Color zoneLight = hotBlue; // Z2 — same as hotBlue
  static const Color zoneModerate = Color(0xFF00E676); // Z3 — neon green
  static const Color zoneHard = Color(0xFFFF6B00); // Z4 — hot orange
  static const Color zoneMax = hotPink; // Z5 — same as hotPink
}
