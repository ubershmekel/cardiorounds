import 'package:flutter/material.dart';

/// Heart-rate zones, ordered low to high. Thresholds are fractions of the
/// athlete's heart-rate reserve (HRR = max HR - resting HR), per Karvonen.
/// See docs/design/zones.md for the user-facing definitions.
enum Zone {
  z1('Z1', 'Rest', 0.0, 0.60, Color(0xFF9E9E9E)),
  z2('Z2', 'Light', 0.60, 0.70, Color(0xFF2196F3)),
  z3('Z3', 'Moderate', 0.70, 0.80, Color(0xFF4CAF50)),
  z4('Z4', 'Hard', 0.80, 0.90, Color(0xFFFF9800)),
  z5('Z5', 'Max', 0.90, double.infinity, Color(0xFFE91E63));

  const Zone(
    this.shortLabel,
    this.name,
    this.lowerFraction,
    this.upperFraction,
    this.color,
  );

  /// "Z1", "Z2", etc. — short tag for compact UI.
  final String shortLabel;

  /// "Rest", "Light", "Moderate", "Hard", "Max".
  final String name;

  /// Lower bound of this zone as a fraction of HRR. Z1 starts at 0
  /// (i.e. resting HR or below).
  final double lowerFraction;

  /// Upper bound of this zone, expressed as a fraction of HRR. A BPM whose
  /// HRR fraction is strictly less than this value falls in this zone.
  /// Z5 uses infinity so anything ≥ 0.90 lands there.
  final double upperFraction;

  /// Chart line / chip color for this zone.
  final Color color;
}

/// Per-athlete zone math. Construct via [zoneSetupFor] which returns null
/// when zones can't be computed (missing max or resting HR, or invalid pair).
class ZoneSetup {
  const ZoneSetup({required this.maxHr, required this.restingHr});

  final int maxHr;
  final int restingHr;

  int get hrr => maxHr - restingHr;

  Zone? zoneFor(int? bpm) {
    if (bpm == null) return null;
    final fraction = (bpm - restingHr) / hrr;
    for (final z in Zone.values) {
      if (fraction < z.upperFraction) return z;
    }
    return Zone.z5;
  }

  /// Lowest BPM that falls in [z]. For Z1 this is the resting heart rate.
  int lowerBpmFor(Zone z) {
    return (restingHr + z.lowerFraction * hrr).round();
  }
}

ZoneSetup? zoneSetupFor({required int? maxHr, required int? restingHr}) {
  if (maxHr == null || restingHr == null) return null;
  if (maxHr <= restingHr) return null;
  return ZoneSetup(maxHr: maxHr, restingHr: restingHr);
}
