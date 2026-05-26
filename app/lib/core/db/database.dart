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
        restingHeartrate: 0,
        maxHeartrate: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return (select(athletes)..where((a) => a.id.equals(id))).getSingle();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: kDatabaseFileName);
}
