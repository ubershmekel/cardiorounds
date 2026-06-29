import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';
import 'tables.dart';

part 'database.g.dart';

const String kDatabaseFileName = 'cardio_rounds';

/// Result of starting a recording: the new activity plus its primary HR
/// [SampleSet]. Both ids are returned so callers don't re-query the set.
class StartedActivity {
  const StartedActivity({required this.activityId, required this.hrSetId});
  final int activityId;
  final int hrSetId;
}

@DriftDatabase(tables: [Athletes, Devices, Activities, SampleSets, HrSamples, Markers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$kDatabaseFileName.sqlite');
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      appLog('Migration', 'Creating fresh database schema v$schemaVersion');
      await m.createAll();
      await _createSampleSetIndexes();
    },
    onUpgrade: (m, from, to) async {
      appLog('Migration', 'Upgrading database schema from v$from to v$to');
      try {
        // Foreign keys can't be toggled inside a transaction, so disable them in
        // an exclusive block around the migration and re-check at the end.
        await exclusively(() async {
          await customStatement('PRAGMA foreign_keys = OFF');
          await transaction(() async {
            if (from < 2) {
              await m.createTable(sampleSets);
              await m.createTable(hrSamples);
              // One HR set per existing activity; reuse the activity id as the
              // set id so the sample copy is a trivial 1:1 map. This is a
              // one-time convenience, NOT an invariant — new sets get
              // autoincremented ids.
              await customStatement(
                "INSERT INTO sample_sets (id, activity_id, device_id, kind) "
                "SELECT id, id, device_id, 'hr' FROM activities",
              );
              await customStatement(
                'INSERT INTO hr_samples (set_id, t_ms, hr) '
                'SELECT activity_id, t_ms, hr FROM samples',
              );
              await m.deleteTable('samples');
              // Drop activities.device_id (it moved to sample_sets); rebuilds
              // the table from the current schema.
              await m.alterTable(TableMigration(activities));
              await _createSampleSetIndexes();
              final sets = await customSelect(
                'SELECT COUNT(*) AS c FROM sample_sets',
              ).getSingle();
              final hrRows = await customSelect(
                'SELECT COUNT(*) AS c FROM hr_samples',
              ).getSingle();
              appLog(
                'Migration',
                'v2: created ${sets.data['c']} sample_sets, '
                    'copied ${hrRows.data['c']} hr_samples',
              );
            }
          });
          // customSelect (not customStatement) so the result rows are read and a
          // violation actually fails the migration instead of opening a bad DB.
          final violations = await customSelect(
            'PRAGMA foreign_key_check',
          ).get();
          if (violations.isNotEmpty) {
            throw StateError(
              'Migration to v2 left foreign key violations: '
              '${violations.map((r) => r.data).toList()}',
            );
          }
        });
        appLog('Migration', 'Schema upgrade to v$to complete');
      } catch (e) {
        // Log loudly: the migration runs in a transaction, so it rolled back and
        // the v$from data is intact, but the app can't open until this is fixed.
        appLog('Migration', 'Schema upgrade from v$from to v$to FAILED: $e');
        rethrow;
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createSampleSetIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sample_sets_activity_kind_idx '
      'ON sample_sets (activity_id, kind, id)',
    );
    // One known device contributes at most one set of a given kind per activity,
    // so a reconnect resumes the same set. NULL device_id is exempt.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS sample_sets_activity_device_kind_unique '
      'ON sample_sets (activity_id, device_id, kind) WHERE device_id IS NOT NULL',
    );
    // No index on hr_samples(set_id, t_ms): it's WITHOUT ROWID with that exact
    // primary key, so the PK already is the clustered index.
  }

  Future<Athlete> ensureDefaultAthlete() async {
    final existing = await (select(athletes)..limit(1)).getSingleOrNull();
    if (existing != null) return existing;
    final id = await into(athletes).insert(
      AthletesCompanion.insert(
        name: '',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return (select(athletes)..where((a) => a.id.equals(id))).getSingle();
  }

  Stream<Athlete> watchDefaultAthlete() {
    return (select(athletes)..limit(1)).watchSingle();
  }

  Future<void> updateAthlete({
    required int id,
    String? name,
    int? restingHeartrate,
    int? maxHeartrate,
    bool clearResting = false,
    bool clearMax = false,
  }) {
    return (update(athletes)..where((a) => a.id.equals(id))).write(
      AthletesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        restingHeartrate: clearResting
            ? const Value<int?>(null)
            : (restingHeartrate == null
                  ? const Value.absent()
                  : Value(restingHeartrate)),
        maxHeartrate: clearMax
            ? const Value<int?>(null)
            : (maxHeartrate == null
                  ? const Value.absent()
                  : Value(maxHeartrate)),
      ),
    );
  }

  Stream<List<Activity>> watchActivities() {
    return (select(
      activities,
    )..orderBy([(a) => OrderingTerm.desc(a.startedAtMs)])).watch();
  }

  Stream<Activity> watchActivity(int activityId) {
    return (select(
      activities,
    )..where((a) => a.id.equals(activityId))).watchSingle();
  }

  /// Samples of the activity's primary (first) HR set. With multiple HR sets per
  /// activity (future multi-device), the chart layer chooses which to show; for
  /// now there is exactly one.
  Stream<List<HrSampleRow>> watchSamples(int activityId) {
    final setIds = selectOnly(sampleSets)
      ..addColumns([sampleSets.id])
      ..where(
        sampleSets.activityId.equals(activityId) & sampleSets.kind.equals('hr'),
      )
      ..orderBy([OrderingTerm.asc(sampleSets.id)])
      ..limit(1);
    return (select(hrSamples)
          ..where((s) => s.setId.isInQuery(setIds))
          ..orderBy([(s) => OrderingTerm.asc(s.tMs)]))
        .watch();
  }

  /// The id of the activity's primary (first) HR set.
  Future<int> primaryHrSetId(int activityId) async {
    final row =
        await (select(sampleSets)
              ..where(
                (s) =>
                    s.activityId.equals(activityId) & s.kind.equals('hr'),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.id)])
              ..limit(1))
            .getSingle();
    return row.id;
  }

  /// Creates an activity and its primary HR set in one transaction. [deviceId]
  /// links the recording strap (null for the fake/debug source).
  Future<StartedActivity> startActivity({
    required int athleteId,
    required int startedAtMs,
    String? sportType,
    int? deviceId,
  }) {
    return transaction(() async {
      final activityId = await into(activities).insert(
        ActivitiesCompanion.insert(
          athleteId: athleteId,
          startedAtMs: startedAtMs,
          durationMs: 0,
          sportType: Value(sportType),
          createdAtMs: startedAtMs,
          updatedAtMs: startedAtMs,
        ),
      );
      final hrSetId = await into(sampleSets).insert(
        SampleSetsCompanion.insert(
          activityId: activityId,
          kind: 'hr',
          deviceId: Value(deviceId),
        ),
      );
      return StartedActivity(activityId: activityId, hrSetId: hrSetId);
    });
  }

  Future<void> updateActivity({
    required int activityId,
    String? name,
    String? note,
    String? sportType,
  }) {
    return (update(activities)..where((a) => a.id.equals(activityId))).write(
      ActivitiesCompanion(
        name: name == null
            ? const Value.absent()
            : Value(name.isEmpty ? null : name),
        note: note == null
            ? const Value.absent()
            : Value(note.isEmpty ? null : note),
        sportType: sportType == null
            ? const Value.absent()
            : Value(sportType.isEmpty ? null : sportType),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteActivity(int activityId) {
    return (delete(activities)..where((a) => a.id.equals(activityId))).go();
  }

  Future<void> finalizeActivity({
    required int activityId,
    required int durationMs,
  }) {
    return (update(activities)..where((a) => a.id.equals(activityId))).write(
      ActivitiesCompanion(
        durationMs: Value(durationMs),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Computes max HR for each time-third of the trimmed workout window and
  /// writes them to shapeStart / shapeMid / shapeEnd. Call after finalizing or
  /// after the trim marker changes.
  Future<void> computeAndSaveShape(int activityId) async {
    // Shape is computed from the primary HR set only; aggregating across
    // multiple HR sets would interleave duplicate timestamps. See data-model.md.
    final setId = await primaryHrSetId(activityId);
    final sampleRows =
        await (select(hrSamples)
              ..where((s) => s.setId.equals(setId))
              ..orderBy([(s) => OrderingTerm.asc(s.tMs)]))
            .get();

    final marker =
        await (select(markers)
              ..where(
                (m) =>
                    m.activityId.equals(activityId) & m.kind.equals('workout'),
              )
              ..limit(1))
            .getSingleOrNull();

    final startMs = marker?.tMs;
    final endMs = marker == null ? null : marker.tMs + (marker.durationMs ?? 0);

    final filtered = sampleRows.where((r) {
      if (startMs != null && r.tMs < startMs) return false;
      if (endMs != null && r.tMs > endMs) return false;
      return true;
    }).toList();

    int? s0, s1, s2;
    if (filtered.length >= 3) {
      final t0 = filtered.first.tMs;
      final t1 = filtered.last.tMs;
      if (t0 != t1) {
        final span = (t1 - t0) / 3;
        int? maxInRange(int lo, int hi) {
          int? max;
          for (final r in filtered) {
            if (r.tMs < lo || r.tMs >= hi) continue;
            final hr = r.hr;
            if (hr == null || hr <= 0) continue;
            if (max == null || hr > max) max = hr;
          }
          return max;
        }

        s0 = maxInRange(t0, t0 + span.round());
        s1 = maxInRange(t0 + span.round(), t0 + (span * 2).round());
        s2 = maxInRange(t0 + (span * 2).round(), t1 + 1);
      }
    }

    await (update(activities)..where((a) => a.id.equals(activityId))).write(
      ActivitiesCompanion(
        shapeStart: Value(s0),
        shapeMid: Value(s1),
        shapeEnd: Value(s2),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// The tMs of the most recent sample, or null if the activity has none. Used
  /// to finalize a crashed recording's duration when the user discards it.
  Future<int?> lastSampleTMs(int activityId) async {
    final setId = await primaryHrSetId(activityId);
    final row =
        await (select(hrSamples)
              ..where((s) => s.setId.equals(setId))
              ..orderBy([(s) => OrderingTerm.desc(s.tMs)])
              ..limit(1))
            .getSingleOrNull();
    return row?.tMs;
  }

  Future<void> insertHrSample({
    required int setId,
    required int tMs,
    int? hr,
  }) {
    return into(hrSamples).insert(
      HrSamplesCompanion.insert(setId: setId, tMs: tMs, hr: Value(hr)),
    );
  }

  Stream<Marker?> watchWorkoutMarker(int activityId) {
    return (select(markers)
          ..where(
            (m) => m.activityId.equals(activityId) & m.kind.equals('workout'),
          )
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Inserts or replaces the single `workout` span marker for an activity.
  Future<void> upsertWorkoutMarker({
    required int activityId,
    required int tMs,
    required int durationMs,
  }) {
    return transaction(() async {
      await (delete(markers)..where(
            (m) => m.activityId.equals(activityId) & m.kind.equals('workout'),
          ))
          .go();
      await into(markers).insert(
        MarkersCompanion.insert(
          activityId: activityId,
          tMs: tMs,
          kind: 'workout',
          durationMs: Value(durationMs),
        ),
      );
    });
  }

  Future<Device> upsertDevice({
    required String platformId,
    required String name,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(
      devices,
    )..where((d) => d.platformId.equals(platformId))).getSingleOrNull();
    if (existing != null) {
      await (update(devices)..where((d) => d.id.equals(existing.id))).write(
        DevicesCompanion(name: Value(name), lastConnectedAtMs: Value(nowMs)),
      );
      return existing.copyWith(name: name, lastConnectedAtMs: nowMs);
    }
    final id = await into(devices).insert(
      DevicesCompanion.insert(
        platformId: platformId,
        name: name,
        lastConnectedAtMs: nowMs,
      ),
    );
    return (select(devices)..where((d) => d.id.equals(id))).getSingle();
  }

  /// Every sport type used so far, most recently used first. Used to pre-fill
  /// and auto-complete the sport-type field when starting a new recording.
  Future<List<String>> distinctSportTypes() async {
    final lastUsed = activities.startedAtMs.max();
    final query = selectOnly(activities)
      ..addColumns([activities.sportType, lastUsed])
      ..where(activities.sportType.isNotNull())
      ..groupBy([activities.sportType])
      ..orderBy([OrderingTerm.desc(lastUsed)]);
    final rows = await query.get();
    return [for (final row in rows) ?row.read(activities.sportType)];
  }

  Future<Device?> lastConnectedDevice() {
    return (select(devices)
          ..orderBy([(d) => OrderingTerm.desc(d.lastConnectedAtMs)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Device?> onlyKnownDevice() async {
    // limit(2) so we can distinguish "exactly one" from "one of many" without fetching all rows
    final rememberedDevices =
        await (select(devices)
              ..orderBy([(d) => OrderingTerm.desc(d.lastConnectedAtMs)])
              ..limit(2))
            .get();
    return rememberedDevices.length == 1 ? rememberedDevices.single : null;
  }

  Future<List<Device>> allDevices() => select(devices).get();
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: kDatabaseFileName,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
