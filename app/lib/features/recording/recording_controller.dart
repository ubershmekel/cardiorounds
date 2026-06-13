import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_source.dart';

const Duration kRecordingStatsInterval = Duration(minutes: 1);
const Duration kRecordingStatsSuspensionGap = Duration(seconds: 75);

class RecordingState {
  const RecordingState({
    required this.activityId,
    required this.deviceName,
    required this.startedAt,
    required this.now,
    required this.currentBpm,
    required this.sourceStatus,
    required this.sourceStatusAt,
    required this.sourceStatusMessage,
    required this.reconnectAttempt,
    required this.stopped,
  });

  final int activityId;
  final String deviceName;
  final DateTime startedAt;
  final DateTime now;
  final int? currentBpm;
  final HrSourceStatusKind sourceStatus;
  final DateTime sourceStatusAt;
  final String? sourceStatusMessage;
  final int? reconnectAttempt;
  final bool stopped;

  Duration get elapsed => now.difference(startedAt);
  Duration get sourceStatusAge => now.difference(sourceStatusAt);

  RecordingState copyWith({
    DateTime? now,
    int? currentBpm,
    bool? bpmIsNull,
    HrSourceStatusKind? sourceStatus,
    DateTime? sourceStatusAt,
    String? sourceStatusMessage,
    bool clearSourceStatusMessage = false,
    int? reconnectAttempt,
    bool clearReconnectAttempt = false,
    bool? stopped,
  }) {
    return RecordingState(
      activityId: activityId,
      deviceName: deviceName,
      startedAt: startedAt,
      now: now ?? this.now,
      currentBpm: (bpmIsNull ?? false) ? null : (currentBpm ?? this.currentBpm),
      sourceStatus: sourceStatus ?? this.sourceStatus,
      sourceStatusAt: sourceStatusAt ?? this.sourceStatusAt,
      sourceStatusMessage: clearSourceStatusMessage
          ? null
          : (sourceStatusMessage ?? this.sourceStatusMessage),
      reconnectAttempt: clearReconnectAttempt
          ? null
          : (reconnectAttempt ?? this.reconnectAttempt),
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
           sourceStatus: HrSourceStatusKind.connected,
           sourceStatusAt: DateTime.now(),
           sourceStatusMessage: null,
           reconnectAttempt: null,
           stopped: false,
         ),
       ) {
    appLog('Recording', 'Started activity $activityId on ${source.deviceName}');
    _sub = source.samples.listen(_onSample);
    _statusSub = source.status.listen(_onSourceStatus);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Drives elapsed time in the UI when no HR sample arrives that second.
      if (mounted && !state.stopped) {
        state = state.copyWith(now: DateTime.now());
      }
    });
    _lastStatsTick = DateTime.now();
    _statsTicker = Timer.periodic(kRecordingStatsInterval, (_) {
      final now = DateTime.now();
      final gap = now.difference(_lastStatsTick);
      _lastStatsTick = now;
      // In the 2026-06-12 data-loss log, sample-count messages stopped for
      // about 36 minutes after the BLE disconnect. If this message appears, the
      // Dart timer was suspended and later resumed; if it does not, the app was
      // awake and should have logged one count per minute.
      if (gap > kRecordingStatsSuspensionGap) {
        appLog(
          'Recording',
          'Stats timer resumed after ${gap.inSeconds}s; app was likely suspended',
        );
      }
      // Log samples for easier debugging to see when things are going ok.
      final count = _sampleCount;
      _sampleCount = 0;
      appLog('Recording', '$count samples in last 60s (activity $activityId)');
    });
  }

  final AppDatabase db;
  final HeartRateSource source;
  final DateTime _started;
  late final StreamSubscription<HrSample> _sub;
  late final StreamSubscription<HrSourceStatus> _statusSub;
  late final Timer _ticker;
  late final Timer _statsTicker;
  int _sampleCount = 0;
  late DateTime _lastStatsTick;

  Future<void> _onSample(HrSample sample) async {
    if (state.stopped) return;
    if (sample.bpm == null) {
      appLog(
        'Recording',
        'Null BPM received from ${source.deviceName}; device may have disconnected',
      );
    }
    _sampleCount++;
    final tMs = sample.at.difference(_started).inMilliseconds;
    await db.insertSample(
      activityId: state.activityId,
      tMs: tMs,
      hr: sample.bpm,
    );
    if (mounted) {
      final recovered =
          sample.bpm != null &&
          state.sourceStatus != HrSourceStatusKind.connected;
      state = state.copyWith(
        currentBpm: sample.bpm,
        bpmIsNull: sample.bpm == null,
        now: sample.at,
        sourceStatus: recovered ? HrSourceStatusKind.connected : null,
        sourceStatusAt: recovered ? sample.at : null,
        clearSourceStatusMessage: recovered,
        clearReconnectAttempt: recovered,
      );
    }
  }

  void _onSourceStatus(HrSourceStatus status) {
    if (state.stopped) return;
    if (status.kind == HrSourceStatusKind.reconnecting) {
      appLog(
        'Recording',
        'Signal reconnecting for ${source.deviceName}'
            '${status.attempt == null ? '' : ' (attempt ${status.attempt})'}',
      );
    } else if (status.kind == HrSourceStatusKind.connected) {
      appLog('Recording', 'Signal connected for ${source.deviceName}');
    } else if (status.kind == HrSourceStatusKind.disconnected) {
      appLog(
        'Recording',
        'Signal lost for ${source.deviceName}: ${status.message ?? 'unknown'}',
      );
    }
    if (mounted) {
      state = state.copyWith(
        now: status.at,
        currentBpm: status.kind == HrSourceStatusKind.connected
            ? state.currentBpm
            : null,
        bpmIsNull: status.kind != HrSourceStatusKind.connected,
        sourceStatus: status.kind,
        sourceStatusAt: status.at,
        sourceStatusMessage: status.message,
        clearSourceStatusMessage: status.message == null,
        reconnectAttempt: status.attempt,
        clearReconnectAttempt: status.attempt == null,
      );
    }
  }

  Future<void> stop() async {
    if (state.stopped) return;
    appLog(
      'Recording',
      'Stopping activity ${state.activityId} on ${source.deviceName} after ${state.elapsed.inSeconds}s',
    );
    state = state.copyWith(stopped: true);
    final elapsedMs = DateTime.now().difference(_started).inMilliseconds;
    await db.finalizeActivity(
      activityId: state.activityId,
      durationMs: elapsedMs,
    );
    await _sub.cancel();
    await _statusSub.cancel();
    _ticker.cancel();
    _statsTicker.cancel();
    await source.dispose();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _statsTicker.cancel();
    _sub.cancel();
    _statusSub.cancel();
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
