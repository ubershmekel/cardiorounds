import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/recording/interrupted_recording.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InterruptedRecording JSON', () {
    test('round-trips through toJson/fromJson', () {
      const original = InterruptedRecording(
        activityId: 7,
        startedAtMs: 1700000000000,
        devicePlatformId: 'strap-1',
        deviceName: 'Polar H10',
      );

      final restored = InterruptedRecording.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.activityId, 7);
      expect(restored.startedAtMs, 1700000000000);
      expect(restored.devicePlatformId, 'strap-1');
      expect(restored.deviceName, 'Polar H10');
    });

    test('returns null when a field is missing', () {
      final json = {
        'activityId': 7,
        'startedAtMs': 1700000000000,
        'deviceName': 'Polar H10',
        // devicePlatformId omitted
      };
      expect(InterruptedRecording.fromJson(json), isNull);
    });

    test('returns null when a field has the wrong type', () {
      final json = {
        'activityId': '7', // should be int
        'startedAtMs': 1700000000000,
        'devicePlatformId': 'strap-1',
        'deviceName': 'Polar H10',
      };
      expect(InterruptedRecording.fromJson(json), isNull);
    });
  });

  group('AppDatabase.lastSampleTMs', () {
    late AppDatabase db;
    late int activityId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final athlete = await db.ensureDefaultAthlete();
      activityId = await db.startActivity(
        athleteId: athlete.id,
        startedAtMs: 1700000000000,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns null when the activity has no samples', () async {
      expect(await db.lastSampleTMs(activityId), isNull);
    });

    test('returns the greatest tMs across samples', () async {
      await db.insertSample(activityId: activityId, tMs: 1000, hr: 100);
      await db.insertSample(activityId: activityId, tMs: 5000, hr: 120);
      await db.insertSample(activityId: activityId, tMs: 3000, hr: 110);

      expect(await db.lastSampleTMs(activityId), 5000);
    });
  });
}
