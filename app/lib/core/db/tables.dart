import 'package:drift/drift.dart';

// Schema for the database tables
// See docs/design/data-model.md for the data model.

class Athletes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get restingHeartrate =>
      integer().nullable().named('resting_heartrate')();
  IntColumn get maxHeartrate => integer().nullable().named('max_heartrate')();
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
  // No athlete_id: attribution is per-stream on sample_sets.athlete_id. An
  // activity's owner is derived from its primary HR set. See multi-athlete.md.
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

/// One time series of one signal type (`kind`) from one source (device) within
/// an activity. A single-device HR recording has exactly one set, kind 'hr'.
/// The device association lives here, not on activities, so one session can span
/// multiple devices. See docs/design/data-model.md.
class SampleSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer()
      .named('activity_id')
      .references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get deviceId => integer()
      .nullable()
      .named('device_id')
      .references(Devices, #id, onDelete: KeyAction.setNull)();
  // Who wore this device; null = unattributed. Deleting an athlete cascades
  // away their streams (and the DAO deletes any activity left with no sets).
  IntColumn get athleteId => integer()
      .nullable()
      .named('athlete_id')
      .references(Athletes, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()(); // 'hr' (future: 'location', 'spo2', ...)
}

@DataClassName('HrSampleRow')
class HrSamples extends Table {
  IntColumn get setId => integer()
      .named('set_id')
      .references(SampleSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get tMs => integer().named('t_ms')();
  IntColumn get hr => integer().nullable()();

  @override
  Set<Column> get primaryKey => {setId, tMs};

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
