/// Returns the activity duration that should be shown to the user.
///
/// When a workout marker exists, its start and end represent the trimmed
/// workout window inside the raw recording. Bounds are clamped so older or
/// inconsistent marker data cannot display a negative duration or a value past
/// the recorded activity.
int effectiveActivityDurationMs({
  required int activityDurationMs,
  int? workoutStartMs,
  int? workoutDurationMs,
}) {
  if (workoutStartMs == null || workoutDurationMs == null) {
    return activityDurationMs;
  }

  final rawDuration = activityDurationMs < 0 ? 0 : activityDurationMs;
  final start = workoutStartMs.clamp(0, rawDuration).toInt();
  final end = (workoutStartMs + workoutDurationMs)
      .clamp(start, rawDuration)
      .toInt();
  return end - start;
}
