import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
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

final activityProvider =
    StreamProvider.family<Activity, int>((ref, activityId) {
  final db = ref.watch(databaseProvider);
  return db.watchActivity(activityId);
});

final samplesProvider =
    StreamProvider.family<List<SampleRow>, int>((ref, activityId) {
  final db = ref.watch(databaseProvider);
  return db.watchSamples(activityId);
});

final workoutMarkerProvider =
    StreamProvider.family<Marker?, int>((ref, activityId) {
  final db = ref.watch(databaseProvider);
  return db.watchWorkoutMarker(activityId);
});
