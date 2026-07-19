import 'package:flutter/material.dart';

import '../../app/colors.dart';

/// Heart-rate zones, ordered low to high. Thresholds are fractions of the
/// athlete's heart-rate reserve (HRR = max HR - resting HR), per Karvonen.
/// See docs/design/zones.md for the user-facing definitions.
enum Zone {
  z1('Z1', 'Baseline', 0.0, 0.60, AppColors.zoneBaseline),
  z2('Z2', 'Sustainable', 0.60, 0.70, AppColors.zoneLight),
  z3('Z3', 'Pushing', 0.70, 0.80, AppColors.zoneModerate),
  z4('Z4', 'Hard', 0.80, 0.90, AppColors.zoneHard),
  z5('Z5', 'All Out', 0.90, double.infinity, AppColors.zoneMax);

  const Zone(
    this.shortLabel,
    this.name,
    this.lowerFraction,
    this.upperFraction,
    this.color,
  );

  /// "Z1", "Z2", etc. — short tag for compact UI.
  final String shortLabel;

  /// Coach-like effort label shown in the UI.
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

  double? hrrFractionFor(int? bpm, {bool clamp = false}) {
    if (bpm == null) return null;
    final fraction = (bpm - restingHr) / hrr;
    if (!clamp) return fraction;
    return fraction.clamp(0.0, 1.0).toDouble();
  }

  double? hrLoadPercentFor(int? bpm) {
    final fraction = hrrFractionFor(bpm, clamp: true);
    return fraction == null ? null : fraction * 100;
  }

  double? floatingZoneFor(int? bpm) {
    final fraction = hrrFractionFor(bpm, clamp: true);
    if (fraction == null) return null;

    for (var i = 0; i < Zone.values.length; i++) {
      final lower = Zone.values[i].lowerFraction;
      final upper = i + 1 < Zone.values.length
          ? Zone.values[i + 1].lowerFraction
          : 1.0;

      if (fraction <= upper || i == Zone.values.length - 1) {
        final zoneStart = (i + 1).toDouble();
        final progress = (fraction - lower) / (upper - lower);
        return zoneStart + progress.clamp(0.0, 1.0).toDouble();
      }
    }

    return (Zone.values.length + 1).toDouble();
  }

  Zone? zoneFor(int? bpm) {
    if (bpm == null) return null;
    final fraction = hrrFractionFor(bpm)!;
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
