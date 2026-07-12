import 'package:cardio/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Re-attributes a stream to an athlete (or null) the way the picker will once
/// the UI lands; here we poke the column directly to build mixed-owner sessions.
Future<void> _setStreamAthlete(AppDatabase db, int setId, int? athleteId) {
  return db.customStatement('UPDATE sample_sets SET athlete_id = ? WHERE id = ?', [
    athleteId,
    setId,
  ]);
}

Future<int> _hrSampleCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM hr_samples')
      .getSingle();
  return row.data['c'] as int;
}

void main() {
  group('athlete DAO', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('watchAthletes lists every athlete, oldest first', () async {
      final a = await db.ensureDefaultAthlete();
      final b = await db.insertAthlete(name: 'Bob', maxHeartrate: 190);

      final athletes = await db.watchAthletes().first;
      expect(athletes.map((x) => x.id), [a.id, b.id]);
      expect(athletes.last.name, 'Bob');
      expect(athletes.last.maxHeartrate, 190);
    });

    test('default athlete is the lowest id, stable across create/delete', () async {
      final a = await db.ensureDefaultAthlete();
      final b = await db.insertAthlete(name: 'Bob');
      // Adding a later athlete must not change who the default is.
      expect((await db.watchDefaultAthlete().first).id, a.id);
      expect((await db.ensureDefaultAthlete()).id, a.id);

      // After removing the original default, the next-lowest becomes default.
      await db.deleteAthlete(a.id);
      expect((await db.watchDefaultAthlete().first).id, b.id);
      expect((await db.ensureDefaultAthlete()).id, b.id);
    });

    test('insertAthlete defaults to a blank, unset athlete', () async {
      final a = await db.insertAthlete();
      expect(a.name, '');
      expect(a.maxHeartrate, isNull);
      expect(a.restingHeartrate, isNull);
    });

    group('deletion', () {
      late Athlete a;
      late Athlete b;
      late int soloActivity;
      late int sharedActivity;
      late int unattributedActivity;

      setUp(() async {
        a = await db.ensureDefaultAthlete();
        b = await db.insertAthlete(name: 'Bob');
        final d1 = await db.upsertDevice(platformId: 'strap-1', name: 'Polar');
        final d2 = await db.upsertDevice(platformId: 'strap-2', name: 'Wahoo');

        // Solo session: one stream, all A.
        final solo = await db.startActivityWithDevices(
          athleteId: a.id,
          startedAtMs: 0,
          deviceIds: [d1.id],
        );
        soloActivity = solo.activityId;
        await db.insertHrSample(setId: solo.hrSetIds[0], tMs: 0, hr: 100);

        // Shared session: two streams; re-attribute the second to B.
        final shared = await db.startActivityWithDevices(
          athleteId: a.id,
          startedAtMs: 100,
          deviceIds: [d1.id, d2.id],
        );
        sharedActivity = shared.activityId;
        await _setStreamAthlete(db, shared.hrSetIds[1], b.id);
        await db.insertHrSample(setId: shared.hrSetIds[0], tMs: 0, hr: 110);
        await db.insertHrSample(setId: shared.hrSetIds[1], tMs: 0, hr: 120);

        // Session with an unattributed second stream (athlete NULL).
        final mixed = await db.startActivityWithDevices(
          athleteId: a.id,
          startedAtMs: 200,
          deviceIds: [d1.id, d2.id],
        );
        unattributedActivity = mixed.activityId;
        await _setStreamAthlete(db, mixed.hrSetIds[1], null);
        await db.insertHrSample(setId: mixed.hrSetIds[0], tMs: 0, hr: 130);
        await db.insertHrSample(setId: mixed.hrSetIds[1], tMs: 0, hr: 140);
      });

      test('counts only workouts recorded solely from the athlete', () async {
        // Only the solo session is entirely A's; the shared and unattributed
        // ones each keep a non-A stream.
        expect(await db.countWorkoutsOnlyFromAthlete(a.id), 1);
        // Bob only appears as the second stream of a shared session, never alone.
        expect(await db.countWorkoutsOnlyFromAthlete(b.id), 0);
      });

      test('deletes solo workouts but keeps shared sessions', () async {
        await db.deleteAthlete(a.id);

        // A is gone; B remains and is now the default.
        expect((await db.watchAthletes().first).map((x) => x.id), [b.id]);

        final ids = (await db.watchActivities().first).map((x) => x.id).toSet();
        expect(ids.contains(soloActivity), isFalse); // emptied -> deleted
        expect(ids.contains(sharedActivity), isTrue); // B's stream survives
        expect(ids.contains(unattributedActivity), isTrue); // NULL stream survives

        // The shared session keeps exactly its one remaining (Bob's) stream.
        final sharedSets = await db.hrSetsForActivity(sharedActivity);
        expect(sharedSets.map((s) => s.athleteId), [b.id]);
        // The unattributed session keeps its NULL stream.
        final mixedSets = await db.hrSetsForActivity(unattributedActivity);
        expect(mixedSets.map((s) => s.athleteId), [null]);
      });

      test('cascades hr_samples of the removed streams', () async {
        expect(await _hrSampleCount(db), 5);
        await db.deleteAthlete(a.id);
        // Removed: solo (1), shared A-stream (1), unattributed A-stream (1).
        // Kept: shared B-stream (1), unattributed NULL-stream (1).
        expect(await _hrSampleCount(db), 2);
      });

      test('refuses to delete the last remaining athlete', () async {
        await db.deleteAthlete(a.id); // now only Bob is left
        expect(() => db.deleteAthlete(b.id), throwsA(isA<StateError>()));
        expect(await db.watchAthletes().first, hasLength(1));
      });
    });

    group('athleteForActivity (derived owner = primary set)', () {
      test('returns the primary stream owner', () async {
        final a = await db.ensureDefaultAthlete();
        final started = await db.startActivityWithDevices(
          athleteId: a.id,
          startedAtMs: 0,
          deviceIds: [null],
        );
        final owner = await db.athleteForActivity(started.activityId);
        expect(owner?.id, a.id);
      });

      test('is null when the primary stream is unattributed', () async {
        final a = await db.ensureDefaultAthlete();
        final started = await db.startActivityWithDevices(
          athleteId: a.id,
          startedAtMs: 0,
          deviceIds: [null],
        );
        await _setStreamAthlete(db, started.hrSetIds[0], null);
        expect(await db.athleteForActivity(started.activityId), isNull);
      });
    });
  });
}
