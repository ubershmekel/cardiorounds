import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hr/hr_source.dart';
import 'database.dart';

/// One selected HR source paired with the [HrSampleRow] set it records into.
/// It may already be connected, or it may still be connecting when Start moves
/// from Confirm Record to the recording screen.
class RecordingSource {
  RecordingSource({required HeartRateSource source, required this.setId})
    : source = source,
      sourceFuture = Future.value(source),
      deviceName = source.deviceName,
      devicePlatformId = source.devicePlatformId;

  RecordingSource.pending({
    required this.sourceFuture,
    required this.setId,
    required this.deviceName,
    required this.devicePlatformId,
  }) : source = null;

  final HeartRateSource? source;
  final Future<HeartRateSource> sourceFuture;
  final int setId;
  final String deviceName;
  final String? devicePlatformId;
}

/// Sources chosen on the Confirm Record screen (one per device), consumed by the
/// RecordingController on the next route. Reset to null when recording starts.
final pendingRecordingProvider = StateProvider<List<RecordingSource>?>(
  (_) => null,
);

/// The activityId of the in-progress recording, or null when not recording.
final activeRecordingIdProvider = StateProvider<int?>((_) => null);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Tolerate the restore flow, which closes the db manually before
  // invalidating this provider, so dispose's close() may be a no-op.
  ref.onDispose(() async {
    try {
      await db.close();
    } catch (_) {}
  });
  return db;
});

final startupProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await db.ensureDefaultAthlete();
});

final defaultAthleteProvider = StreamProvider<Athlete>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDefaultAthlete();
});

/// Every athlete, oldest first (the lowest-id row is the default). Drives the
/// athlete-management pager and the >1-athlete attribution pickers.
final athletesProvider = StreamProvider<List<Athlete>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAthletes();
});

/// The blast radius shown in the delete-warning dialog: workouts deleted
/// entirely plus the athlete's total stream count (to distinguish a
/// never-recorded athlete from one with only shared-session streams).
/// autoDispose so it refetches each open, reflecting any re-attribution since.
final athleteDeletionImpactProvider = FutureProvider.autoDispose
    .family<({int soloWorkouts, int streams}), int>((ref, athleteId) {
      return ref.watch(databaseProvider).athleteDeletionImpact(athleteId);
    });

final activitiesProvider = StreamProvider<List<Activity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActivities();
});

final activityProvider = StreamProvider.family<Activity, int>((
  ref,
  activityId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchActivity(activityId);
});

/// Distinct past sport-type labels (most-recent first) for autocomplete.
/// autoDispose so each visit to a field-bearing screen refetches, picking up
/// types added since.
final distinctSportTypesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) {
  return ref.watch(databaseProvider).distinctSportTypes();
});

final samplesProvider = StreamProvider.family<List<HrSampleRow>, int>((
  ref,
  activityId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchSamples(activityId);
});

/// All HR streams for an activity (one per device). Used by the multi-device
/// recording and review screens to draw a line and stats block per device.
final hrSeriesProvider = StreamProvider.family<List<HrSeries>, int>((
  ref,
  activityId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchHrSeries(activityId);
});

final workoutMarkerProvider = StreamProvider.family<Marker?, int>((
  ref,
  activityId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchWorkoutMarker(activityId);
});
