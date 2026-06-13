import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

const String kDatabaseFileName = 'cardio_rounds';

@DriftDatabase(tables: [Athletes, Devices, Activities, Samples, Markers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$kDatabaseFileName.sqlite');
  }

  @override
  int get schemaVersion => 1;

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

  Stream<List<SampleRow>> watchSamples(int activityId) {
    return (select(samples)
          ..where((s) => s.activityId.equals(activityId))
          ..orderBy([(s) => OrderingTerm.asc(s.tMs)]))
        .watch();
  }

  Future<int> startActivity({
    required int athleteId,
    required int startedAtMs,
    String? sportType,
  }) {
    return into(activities).insert(
      ActivitiesCompanion.insert(
        athleteId: athleteId,
        startedAtMs: startedAtMs,
        durationMs: 0,
        sportType: Value(sportType),
        createdAtMs: startedAtMs,
        updatedAtMs: startedAtMs,
      ),
    );
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
    final sampleRows = await (select(samples)
          ..where((s) => s.activityId.equals(activityId))
          ..orderBy([(s) => OrderingTerm.asc(s.tMs)]))
        .get();

    final marker = await (select(markers)
          ..where(
            (m) =>
                m.activityId.equals(activityId) & m.kind.equals('workout'),
          )
          ..limit(1))
        .getSingleOrNull();

    final startMs = marker?.tMs;
    final endMs =
        marker == null ? null : marker.tMs + (marker.durationMs ?? 0);

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

  Future<void> insertSample({
    required int activityId,
    required int tMs,
    int? hr,
  }) {
    return into(samples).insert(
      SamplesCompanion.insert(activityId: activityId, tMs: tMs, hr: Value(hr)),
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
