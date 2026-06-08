// Pure heart-rate analysis. No Flutter, Riverpod, or Drift imports so this can
// be unit-tested in isolation.

class HrStats {
  const HrStats({this.min, this.max, this.avg, this.sampleCount = 0});

  final int? min;
  final int? max;
  final int? avg;
  final int sampleCount;

  bool get isEmpty => sampleCount == 0;

  /// Computes min/avg/max over the positive heart-rate values.
  static HrStats fromHeartRates(Iterable<int?> heartRates) {
    int? min;
    int? max;
    var sum = 0;
    var count = 0;
    for (final hr in heartRates) {
      if (hr == null || hr <= 0) continue;
      if (min == null || hr < min) min = hr;
      if (max == null || hr > max) max = hr;
      sum += hr;
      count++;
    }
    if (count == 0) return const HrStats();
    return HrStats(
      min: min,
      max: max,
      avg: (sum / count).round(),
      sampleCount: count,
    );
  }

  /// Computes min/avg/max over positive heart-rate samples inside an optional
  /// elapsed-time window. The window bounds are inclusive.
  static HrStats fromTimedHeartRates(
    Iterable<({int tMs, int? hr})> samples, {
    int? windowStartMs,
    int? windowEndMs,
  }) {
    return fromHeartRates(
      samples
          .where((sample) {
            if (windowStartMs != null && sample.tMs < windowStartMs) {
              return false;
            }
            if (windowEndMs != null && sample.tMs > windowEndMs) {
              return false;
            }
            return true;
          })
          .map((sample) => sample.hr),
    );
  }
}

/// The vertical (BPM) bounds the chart draws between.
class HrAxisRange {
  const HrAxisRange({required this.minY, required this.maxY});

  final int minY;
  final int maxY;

  int get span => maxY - minY;

  /// Y-axis bounds for a chart given the session's min/max HR.
  ///
  /// The floor is rounded down to a multiple of ten that sits strictly under
  /// the minimum HR (e.g. min 44 -> 40, min 40 -> 30). The ceiling is the next
  /// multiple of ten strictly above the maximum, giving a small headroom.
  /// Falls back to a sensible default when there is no data yet.
  static HrAxisRange forStats({int? minHr, int? maxHr}) {
    if (minHr == null || maxHr == null) {
      return const HrAxisRange(minY: 40, maxY: 200);
    }
    final minY = ((minHr - 1) ~/ 10) * 10;
    final maxY = (maxHr ~/ 10 + 1) * 10;
    return HrAxisRange(minY: minY, maxY: maxY);
  }
}
