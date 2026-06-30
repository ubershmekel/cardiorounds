import 'package:cardio/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// The v1 schema verbatim (activities carried device_id; samples were keyed by
/// activity_id). We build it with raw SQL so the migration runs against a real
/// v1 database rather than a hand-mocked one.
const _v1Schema = '''
CREATE TABLE athletes (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  resting_heartrate INTEGER,
  max_heartrate INTEGER,
  created_at_ms INTEGER NOT NULL
);
CREATE TABLE devices (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  platform_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  last_connected_at_ms INTEGER NOT NULL
);
CREATE TABLE activities (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  athlete_id INTEGER NOT NULL,
  device_id INTEGER REFERENCES devices (id) ON DELETE SET NULL,
  started_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  name TEXT,
  note TEXT,
  sport_type TEXT,
  shape_start INTEGER,
  shape_mid INTEGER,
  shape_end INTEGER,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE TABLE samples (
  activity_id INTEGER NOT NULL REFERENCES activities (id) ON DELETE CASCADE,
  t_ms INTEGER NOT NULL,
  hr INTEGER,
  PRIMARY KEY (activity_id, t_ms)
) WITHOUT ROWID;
CREATE TABLE markers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL REFERENCES activities (id) ON DELETE CASCADE,
  t_ms INTEGER NOT NULL,
  duration_ms INTEGER,
  kind TEXT NOT NULL,
  name TEXT
);
''';

/// Opens a raw v1 database with seed data, then wraps it in [AppDatabase] so the
/// 1 -> 2 migration runs on first use.
AppDatabase _openMigratedFromV1() {
  final raw = sqlite3.openInMemory();
  raw.execute(_v1Schema);
  raw.execute(
    "INSERT INTO athletes (id, name, created_at_ms) VALUES (1, '', 0)",
  );
  raw.execute(
    "INSERT INTO devices (id, platform_id, name, last_connected_at_ms) "
    "VALUES (1, 'strap-1', 'Polar H10', 0)",
  );
  // Activity 10 recorded on a device; activity 20 on the fake source (no device).
  raw.execute(
    'INSERT INTO activities '
    '(id, athlete_id, device_id, started_at_ms, duration_ms, created_at_ms, updated_at_ms) '
    'VALUES (10, 1, 1, 100, 5000, 100, 100), (20, 1, NULL, 200, 3000, 200, 200)',
  );
  raw.execute(
    'INSERT INTO samples (activity_id, t_ms, hr) VALUES '
    '(10, 1000, 100), (10, 2000, 110), (20, 500, 80), '
    '(999, 1234, 60)',
  );
  raw.execute('PRAGMA user_version = 1');
  return AppDatabase.forTesting(NativeDatabase.opened(raw));
}

void main() {
  group('migration v1 -> v2', () {
    late AppDatabase db;

    setUp(() async {
      db = _openMigratedFromV1();
      // Force the migration to run before assertions.
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'creates one HR sample_set per activity, reusing the activity id',
      () async {
        final sets = await db
            .customSelect(
              'SELECT id, activity_id, device_id, kind FROM sample_sets ORDER BY id',
            )
            .get();
        expect(sets.map((r) => r.data), [
          {'id': 10, 'activity_id': 10, 'device_id': 1, 'kind': 'hr'},
          {'id': 20, 'activity_id': 20, 'device_id': null, 'kind': 'hr'},
        ]);
      },
    );

    test('re-points every reachable sample to its set', () async {
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM hr_samples')
          .getSingle();
      expect(count.data['c'], 3);

      expect(await db.lastSampleTMs(10), 2000);
      expect(await db.lastSampleTMs(20), 500);

      final samples = await db.watchSamples(10).first;
      expect(samples.map((s) => (s.tMs, s.hr)), [(1000, 100), (2000, 110)]);
    });

    test('drops orphaned v1 samples whose activity no longer exists', () async {
      final orphan = await db
          .customSelect('SELECT * FROM hr_samples WHERE set_id = 999')
          .get();
      expect(orphan, isEmpty);
    });

    test(
      'drops the old samples table and the activities.device_id column',
      () async {
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='samples'",
            )
            .get();
        expect(tables, isEmpty);

        final cols = await db
            .customSelect('PRAGMA table_info(activities)')
            .get();
        expect(cols.any((c) => c.data['name'] == 'device_id'), isFalse);
      },
    );

    test('passes foreign_key_check after migrating', () async {
      final violations = await db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(violations, isEmpty);
    });
  });
}
