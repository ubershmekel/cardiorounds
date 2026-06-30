import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/recording/interrupted_recording.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InterruptedRecording JSON', () {
    test('round-trips multiple devices through toJson/fromJson', () {
      const original = InterruptedRecording(
        activityId: 7,
        startedAtMs: 1700000000000,
        devices: [
          RecordedDevice(platformId: 'strap-1', name: 'Polar H10'),
          RecordedDevice(platformId: 'strap-2', name: 'Wahoo Tickr'),
        ],
      );

      final restored = InterruptedRecording.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.activityId, 7);
      expect(restored.startedAtMs, 1700000000000);
      expect(restored.devices.map((d) => (d.platformId, d.name)), [
        ('strap-1', 'Polar H10'),
        ('strap-2', 'Wahoo Tickr'),
      ]);
    });

    test('reads a legacy single-device sentinel as a one-device list', () {
      final json = {
        'activityId': 7,
        'startedAtMs': 1700000000000,
        'devicePlatformId': 'strap-1',
        'deviceName': 'Polar H10',
      };

      final restored = InterruptedRecording.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.devices, hasLength(1));
      expect(restored.devices.single.platformId, 'strap-1');
      expect(restored.devices.single.name, 'Polar H10');
    });

    test('returns null when a device entry is malformed', () {
      final json = {
        'activityId': 7,
        'startedAtMs': 1700000000000,
        'devices': [
          {'platformId': 'strap-1'}, // name missing
        ],
      };
      expect(InterruptedRecording.fromJson(json), isNull);
    });

    test('returns null when a field has the wrong type', () {
      final json = {
        'activityId': '7', // should be int
        'startedAtMs': 1700000000000,
        'devices': [
          {'platformId': 'strap-1', 'name': 'Polar H10'},
        ],
      };
      expect(InterruptedRecording.fromJson(json), isNull);
    });
  });

  group('AppDatabase.lastSampleTMs', () {
    late AppDatabase db;
    late int activityId;
    late int hrSetId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final athlete = await db.ensureDefaultAthlete();
      final started = await db.startActivity(
        athleteId: athlete.id,
        startedAtMs: 1700000000000,
      );
      activityId = started.activityId;
      hrSetId = started.hrSetId;
    });

    tearDown(() async {
      await db.close();
    });

    test('returns null when the activity has no samples', () async {
      expect(await db.lastSampleTMs(activityId), isNull);
    });

    test('returns the greatest tMs across samples', () async {
      await db.insertHrSample(setId: hrSetId, tMs: 1000, hr: 100);
      await db.insertHrSample(setId: hrSetId, tMs: 5000, hr: 120);
      await db.insertHrSample(setId: hrSetId, tMs: 3000, hr: 110);

      expect(await db.lastSampleTMs(activityId), 5000);
    });
  });
}
