import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hr/hr_source.dart';
import 'database.dart';

/// Source chosen by the user on the Confirm Record screen, consumed by the
/// RecordingController on the next route. Reset to null when recording stops.
final pendingHrSourceProvider = StateProvider<HeartRateSource?>((_) => null);

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

final workoutMarkerProvider = StreamProvider.family<Marker?, int>((
  ref,
  activityId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchWorkoutMarker(activityId);
});
