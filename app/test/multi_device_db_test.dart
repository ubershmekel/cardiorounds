import 'package:cardio/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('multi-device DB', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('startActivityWithDevices makes one HR set per device, in order', () async {
      final athlete = await db.ensureDefaultAthlete();
      final d1 = await db.upsertDevice(platformId: 'strap-1', name: 'Polar');
      final d2 = await db.upsertDevice(platformId: 'strap-2', name: 'Wahoo');

      final started = await db.startActivityWithDevices(
        athleteId: athlete.id,
        startedAtMs: 1000,
        deviceIds: [d1.id, null, d2.id], // middle one is the fake source
      );

      expect(started.hrSetIds, hasLength(3));
      expect(started.hrSetId, started.hrSetIds.first); // primary == first
      final sets = await db.hrSetsForActivity(started.activityId);
      expect(sets.map((s) => s.id), started.hrSetIds);
      expect(sets.map((s) => s.deviceId), [d1.id, null, d2.id]);
      expect(sets.every((s) => s.kind == 'hr'), isTrue);
    });

    test('watchHrSeries groups samples per set with device names', () async {
      final athlete = await db.ensureDefaultAthlete();
      final d1 = await db.upsertDevice(platformId: 'strap-1', name: 'Polar');
      final started = await db.startActivityWithDevices(
        athleteId: athlete.id,
        startedAtMs: 0,
        deviceIds: [d1.id, null],
      );
      final set1 = started.hrSetIds[0];
      final set2 = started.hrSetIds[1];
      await db.insertHrSample(setId: set1, tMs: 0, hr: 100);
      await db.insertHrSample(setId: set1, tMs: 1000, hr: 110);
      await db.insertHrSample(setId: set2, tMs: 0, hr: 90);

      final series = await db.watchHrSeries(started.activityId).first;

      expect(series, hasLength(2));
      expect(series[0].setId, set1);
      expect(series[0].deviceName, 'Polar');
      expect(series[0].samples.map((r) => r.hr), [100, 110]);
      expect(series[1].setId, set2);
      expect(series[1].deviceName, isNull); // fake source, no device
      expect(series[1].samples.map((r) => r.hr), [90]);
    });

    test('watchHrSeries omits sets that have no samples yet', () async {
      final athlete = await db.ensureDefaultAthlete();
      final started = await db.startActivityWithDevices(
        athleteId: athlete.id,
        startedAtMs: 0,
        deviceIds: [null, null],
      );
      await db.insertHrSample(setId: started.hrSetIds[0], tMs: 0, hr: 100);

      final series = await db.watchHrSeries(started.activityId).first;

      expect(series, hasLength(1));
      expect(series.single.setId, started.hrSetIds[0]);
    });
  });
}
