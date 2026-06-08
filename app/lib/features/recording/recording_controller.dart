import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_source.dart';

class RecordingState {
  const RecordingState({
    required this.activityId,
    required this.deviceName,
    required this.startedAt,
    required this.now,
    required this.currentBpm,
    required this.stopped,
  });

  final int activityId;
  final String deviceName;
  final DateTime startedAt;
  final DateTime now;
  final int? currentBpm;
  final bool stopped;

  Duration get elapsed => now.difference(startedAt);

  RecordingState copyWith({
    DateTime? now,
    int? currentBpm,
    bool? bpmIsNull,
    bool? stopped,
  }) {
    return RecordingState(
      activityId: activityId,
      deviceName: deviceName,
      startedAt: startedAt,
      now: now ?? this.now,
      currentBpm: (bpmIsNull ?? false) ? null : (currentBpm ?? this.currentBpm),
      stopped: stopped ?? this.stopped,
    );
  }
}

class RecordingController extends StateNotifier<RecordingState> {
  RecordingController({
    required this.db,
    required this.source,
    required int activityId,
  }) : _started = DateTime.now(),
       super(
         RecordingState(
           activityId: activityId,
           deviceName: source.deviceName,
           startedAt: DateTime.now(),
           now: DateTime.now(),
           currentBpm: null,
           stopped: false,
         ),
       ) {
    _sub = source.samples.listen(_onSample);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !state.stopped) state = state.copyWith(now: DateTime.now());
    });
  }

  final AppDatabase db;
  final HeartRateSource source;
  final DateTime _started;
  late final StreamSubscription<HrSample> _sub;
  late final Timer _ticker;

  Future<void> _onSample(HrSample sample) async {
    if (state.stopped) return;
    final tMs = sample.at.difference(_started).inMilliseconds;
    await db.insertSample(
      activityId: state.activityId,
      tMs: tMs,
      hr: sample.bpm,
    );
    if (mounted) {
      state = state.copyWith(
        currentBpm: sample.bpm,
        bpmIsNull: sample.bpm == null,
        now: sample.at,
      );
    }
  }

  Future<void> stop() async {
    if (state.stopped) return;
    state = state.copyWith(stopped: true);
    final elapsedMs = DateTime.now().difference(_started).inMilliseconds;
    await db.finalizeActivity(
      activityId: state.activityId,
      durationMs: elapsedMs,
    );
    await _sub.cancel();
    _ticker.cancel();
    await source.dispose();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sub.cancel();
    if (!state.stopped) {
      source.dispose();
    }
    super.dispose();
  }
}

final recordingControllerProvider = StateNotifierProvider.autoDispose
    .family<RecordingController, RecordingState, int>((ref, activityId) {
  final db = ref.watch(databaseProvider);
  // Picker writes here before navigating to the recording screen. Fall back to
  // a synthetic source if someone deep-links into /recording/:id directly.
  final source = ref.read(pendingHrSourceProvider) ?? FakeHeartRateSource();
  // Clear the slot AFTER this provider finishes initializing. Mutating another
  // provider inline would trip Riverpod's "providers can't modify each other
  // during build" guard.
  Future.microtask(() {
    try {
      ref.read(pendingHrSourceProvider.notifier).state = null;
    } catch (_) {
      // Container may be disposed by then; safe to swallow.
    }
  });
  return RecordingController(
    db: db,
    source: source,
    activityId: activityId,
  );
});
