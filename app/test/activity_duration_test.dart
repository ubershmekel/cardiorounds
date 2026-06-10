import 'package:cardio/features/activity/activity_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveActivityDurationMs', () {
    test('uses the raw activity duration when there is no workout marker', () {
      expect(effectiveActivityDurationMs(activityDurationMs: 60000), 60000);
    });

    test(
      'uses the trimmed workout duration when marker bounds are present',
      () {
        expect(
          effectiveActivityDurationMs(
            activityDurationMs: 60000,
            workoutStartMs: 10000,
            workoutDurationMs: 30000,
          ),
          30000,
        );
      },
    );

    test('clamps trimmed bounds to the recorded activity duration', () {
      expect(
        effectiveActivityDurationMs(
          activityDurationMs: 60000,
          workoutStartMs: 50000,
          workoutDurationMs: 30000,
        ),
        10000,
      );
    });

    test(
      'does not return a negative duration for inconsistent marker data',
      () {
        expect(
          effectiveActivityDurationMs(
            activityDurationMs: 60000,
            workoutStartMs: 30000,
            workoutDurationMs: -10000,
          ),
          0,
        );
      },
    );
  });
}
