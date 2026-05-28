import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

const String kDatabaseFileName = 'cardio_rounds';

@DriftDatabase(tables: [Athletes, Devices, Activities, Samples, Markers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<Athlete> ensureDefaultAthlete() async {
    final existing = await (select(athletes)..limit(1)).getSingleOrNull();
    if (existing != null) return existing;
    final id = await into(athletes).insert(
      AthletesCompanion.insert(
        name: 'Athlete',
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
    return (select(activities)
          ..orderBy([(a) => OrderingTerm.desc(a.startedAtMs)]))
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

  Future<void> insertSample({
    required int activityId,
    required int tMs,
    int? hr,
  }) {
    return into(samples).insert(
      SamplesCompanion.insert(
        activityId: activityId,
        tMs: tMs,
        hr: Value(hr),
      ),
    );
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
