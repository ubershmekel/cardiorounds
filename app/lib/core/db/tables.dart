import 'package:drift/drift.dart';

class Athletes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get restingHeartrate => integer().named('resting_heartrate')();
  IntColumn get maxHeartrate => integer().named('max_heartrate')();
  IntColumn get createdAtMs => integer().named('created_at_ms')();
}

class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get platformId => text().unique().named('platform_id')();
  TextColumn get name => text()();
  IntColumn get lastConnectedAtMs => integer().named('last_connected_at_ms')();
}

class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get athleteId => integer().named('athlete_id')();
  IntColumn get deviceId => integer()
      .nullable()
      .named('device_id')
      .references(Devices, #id, onDelete: KeyAction.setNull)();
  IntColumn get startedAtMs => integer().named('started_at_ms')();
  IntColumn get durationMs => integer().named('duration_ms')();
  TextColumn get name => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get sportType => text().nullable().named('sport_type')();
  IntColumn get shapeStart => integer().nullable().named('shape_start')();
  IntColumn get shapeMid => integer().nullable().named('shape_mid')();
  IntColumn get shapeEnd => integer().nullable().named('shape_end')();
  IntColumn get createdAtMs => integer().named('created_at_ms')();
  IntColumn get updatedAtMs => integer().named('updated_at_ms')();
}

@DataClassName('SampleRow')
class Samples extends Table {
  IntColumn get activityId => integer()
      .named('activity_id')
      .references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get tMs => integer().named('t_ms')();
  IntColumn get hr => integer().nullable()();

  @override
  Set<Column> get primaryKey => {activityId, tMs};

  @override
  bool get withoutRowId => true;
}

class Markers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer()
      .named('activity_id')
      .references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get tMs => integer().named('t_ms')();
  IntColumn get durationMs => integer().nullable().named('duration_ms')();
  TextColumn get kind => text()();
  TextColumn get name => text().nullable()();
}
