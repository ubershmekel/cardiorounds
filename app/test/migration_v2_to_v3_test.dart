import 'package:cardio/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// The v2 schema verbatim: athlete attribution lived on `activities.athlete_id`
/// and `sample_sets` had no `athlete_id`. Built with raw SQL so the migration
/// runs against a real v2 database rather than a hand-mocked one.
const _v2Schema = '''
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
CREATE TABLE sample_sets (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL REFERENCES activities (id) ON DELETE CASCADE,
  device_id INTEGER REFERENCES devices (id) ON DELETE SET NULL,
  kind TEXT NOT NULL
);
CREATE TABLE hr_samples (
  set_id INTEGER NOT NULL REFERENCES sample_sets (id) ON DELETE CASCADE,
  t_ms INTEGER NOT NULL,
  hr INTEGER,
  PRIMARY KEY (set_id, t_ms)
) WITHOUT ROWID;
CREATE TABLE markers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL REFERENCES activities (id) ON DELETE CASCADE,
  t_ms INTEGER NOT NULL,
  duration_ms INTEGER,
  kind TEXT NOT NULL,
  name TEXT
);
CREATE INDEX sample_sets_activity_kind_idx
  ON sample_sets (activity_id, kind, id);
CREATE UNIQUE INDEX sample_sets_activity_device_kind_unique
  ON sample_sets (activity_id, device_id, kind) WHERE device_id IS NOT NULL;
''';

/// Opens a raw v2 database with seed data, then wraps it in [AppDatabase] so the
/// 2 -> 3 migration runs on first use.
AppDatabase _openMigratedFromV2() {
  final raw = sqlite3.openInMemory();
  raw.execute(_v2Schema);
  // Two athletes, plus an activity attributed to a third that does not exist
  // (v2 had no FK on activities.athlete_id, so real data can dangle).
  raw.execute(
    "INSERT INTO athletes (id, name, created_at_ms) VALUES "
    "(1, 'Alice', 0), (2, 'Bob', 0)",
  );
  raw.execute(
    "INSERT INTO devices (id, platform_id, name, last_connected_at_ms) VALUES "
    "(1, 'strap-1', 'Polar H10', 0), (2, 'strap-2', 'Wahoo Tickr', 0)",
  );
  raw.execute(
    'INSERT INTO activities '
    '(id, athlete_id, started_at_ms, duration_ms, created_at_ms, updated_at_ms) '
    'VALUES (10, 1, 100, 5000, 100, 100), (20, 2, 200, 3000, 200, 200), '
    '(30, 1, 300, 4000, 300, 300), (40, 99, 400, 1000, 400, 400)',
  );
  // Activity 30 is multi-device (two sets); 40 is attributed to the missing
  // athlete 99.
  raw.execute(
    "INSERT INTO sample_sets (id, activity_id, device_id, kind) VALUES "
    "(100, 10, 1, 'hr'), (200, 20, NULL, 'hr'), "
    "(301, 30, 1, 'hr'), (302, 30, 2, 'hr'), (400, 40, NULL, 'hr')",
  );
  raw.execute(
    'INSERT INTO hr_samples (set_id, t_ms, hr) VALUES '
    '(100, 1000, 100), (100, 2000, 110), (200, 500, 80), '
    '(301, 1000, 150), (302, 1000, 130), (400, 500, 90)',
  );
  raw.execute('PRAGMA user_version = 2');
  return AppDatabase.forTesting(NativeDatabase.opened(raw));
}

Future<Map<int, int?>> _athleteBySet(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT id, athlete_id FROM sample_sets ORDER BY id')
      .get();
  return {
    for (final r in rows) r.data['id'] as int: r.data['athlete_id'] as int?,
  };
}

void main() {
  group('migration v2 -> v3', () {
    late AppDatabase db;

    setUp(() async {
      db = _openMigratedFromV2();
      // Force the migration to run before assertions.
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('back-fills each stream from its activity athlete', () async {
      expect(await _athleteBySet(db), {
        100: 1, // activity 10 -> Alice
        200: 2, // activity 20 -> Bob
        301: 1, // activity 30 (multi-device) -> Alice
        302: 1, // both streams of activity 30 -> Alice
        400: null, // activity 40's athlete 99 doesn't exist -> NULL, not a FK error
      });
    });

    test('drops activities.athlete_id', () async {
      final cols = await db.customSelect('PRAGMA table_info(activities)').get();
      expect(cols.any((c) => c.data['name'] == 'athlete_id'), isFalse);
    });

    test('leaves hr_samples untouched', () async {
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM hr_samples')
          .getSingle();
      expect(count.data['c'], 6);
      final samples = await db.watchSamples(10).first;
      expect(samples.map((s) => (s.tMs, s.hr)), [(1000, 100), (2000, 110)]);
    });

    test('passes foreign_key_check after migrating', () async {
      final violations = await db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(violations, isEmpty);
    });

    test('deleting an athlete cascades to their streams', () async {
      // The migrated athlete_id carries ON DELETE CASCADE, so removing Alice
      // removes every stream she wore (and their hr_samples), leaving Bob's and
      // the unattributed stream behind.
      await db.customStatement('DELETE FROM athletes WHERE id = 1');

      expect(await _athleteBySet(db), {200: 2, 400: null});
      final remaining = await db
          .customSelect('SELECT set_id FROM hr_samples ORDER BY set_id')
          .get();
      expect(remaining.map((r) => r.data['set_id']).toSet(), {200, 400});
    });
  });
}
