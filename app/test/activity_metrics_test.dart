import 'package:cardio/core/db/database.dart';
import 'package:cardio/features/activity/activity_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Athlete _athlete({required int id, int? maxHr, int? restingHr}) => Athlete(
  id: id,
  name: 'A$id',
  maxHeartrate: maxHr,
  restingHeartrate: restingHr,
  createdAtMs: 0,
);

List<HrSampleRow> _samples(List<(int tMs, int? hr)> pts) => [
  for (final (t, hr) in pts) HrSampleRow(setId: 1, tMs: t, hr: hr),
];

void main() {
  group('zoneSetupForStream (analysis is per stream, never the default)', () {
    // Athlete 1 is the default (lowest id); athletes 2 and 3 are others; 3 has
    // an incomplete profile.
    final athletes = [
      _athlete(id: 1, maxHr: 190, restingHr: 50),
      _athlete(id: 2, maxHr: 180, restingHr: 40),
      _athlete(id: 3),
    ];

    test('resolves a stream against its own attributed athlete', () {
      final setup = zoneSetupForStream(2, athletes);
      expect(setup, isNotNull);
      expect(setup!.maxHr, 180);
      expect(setup.restingHr, 40);
    });

    test('a workout with no stream on the default athlete still scores', () {
      // Neither of these streams belongs to athlete 1 (the default), yet each
      // resolves correctly — the default is never needed for analysis.
      expect(zoneSetupForStream(2, athletes)!.maxHr, 180);
      expect(zoneSetupForStream(3, athletes), isNull); // incomplete profile
    });

    test('an unattributed stream does not borrow the default athlete', () {
      expect(zoneSetupForStream(null, athletes), isNull);
    });

    test('a deleted/missing athlete resolves to null, not the default', () {
      expect(zoneSetupForStream(999, athletes), isNull);
    });
  });

  group('computeExtraBeats (per-stream load)', () {
    // 120 bpm held for exactly one minute.
    final oneMinuteAt120 = _samples([(0, 120), (60000, 120)]);

    test("integrates beats above the stream's own resting HR", () {
      // (120 - 60) bpm * 1 min = 60 beats.
      expect(computeExtraBeats(oneMinuteAt120, restingHr: 60), 60);
    });

    test('is per stream: a lower resting HR yields more extra beats', () {
      final low = computeExtraBeats(oneMinuteAt120, restingHr: 40); // 80
      final high = computeExtraBeats(oneMinuteAt120, restingHr: 80); // 40
      expect(low, 80);
      expect(high, 40);
      expect(low, greaterThan(high!));
    });

    test('needs at least two samples to integrate', () {
      expect(computeExtraBeats(_samples([(0, 120)]), restingHr: 60), isNull);
    });

    test('respects the workout window', () {
      final s = _samples([(0, 200), (60000, 120), (120000, 120)]);
      // Window [60s, 120s] keeps only the trailing 120bpm minute: (120-60)*1.
      expect(
        computeExtraBeats(
          s,
          restingHr: 60,
          windowStartMs: 60000,
          windowEndMs: 120000,
        ),
        60,
      );
    });
  });

  group('shape reference stream without a complete HR profile', () {
    final rising = _samples([
      (0, 100),
      (1000, 110),
      (2000, 120),
      (3000, 150),
      (4000, 160),
      (5000, 170),
    ]);

    test('thirds (the shape) compute with no athlete profile at all', () {
      final thirds = computeThirds(rising);
      expect(thirds, hasLength(3));
      expect(thirds.every((t) => t != null), isTrue);
      // The final third peaks highest — the shape is preserved.
      expect(thirds[2]!, greaterThan(thirds[0]!));
    });

    test('the load metric is omitted (no default fallback) when the primary '
        'stream has an incomplete profile', () {
      // The screen gates the primary stream's load on zoneSetupForStream, which
      // is null for an incomplete profile — so no resting HR, no extra beats,
      // and no silent fall-back to the default athlete.
      final incomplete = [_athlete(id: 3)];
      expect(zoneSetupForStream(3, incomplete), isNull);
    });
  });
}
