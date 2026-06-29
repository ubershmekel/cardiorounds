import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_source.dart';
import '../../core/recording/interrupted_recording.dart';
import '../../core/zones/zones.dart';
import 'live_activity.dart';

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
    this.sentinel = const RecordingSentinel(),
    DateTime? resumeStartedAt,
    ZoneSetup? zoneSetup,
    this.onStopped,
  }) : _started = resumeStartedAt ?? DateTime.now(),
       _zoneSetup = zoneSetup,
       super(
         RecordingState(
           activityId: activityId,
           deviceName: source.deviceName,
           // For a resumed recording, anchor to the original start so sample
           // tMs offsets and elapsed time continue the existing timeline.
           startedAt: resumeStartedAt ?? DateTime.now(),
           now: DateTime.now(),
           currentBpm: null,
           sourceStatus: HrSourceStatusKind.connected,
           sourceStatusAt: DateTime.now(),
           sourceStatusMessage: null,
           reconnectAttempt: null,
           stopped: false,
         ),
       ) {
    final verb = resumeStartedAt == null ? 'Started' : 'Resumed';
    appLog('Recording', '$verb activity $activityId on ${source.deviceName}');
    _writeSentinel(activityId);
    _liveActivity.start(
      activityId: activityId,
      deviceName: source.deviceName,
      startedAt: state.startedAt,
    );
    _updateLiveActivity();
    // Resolve the activity's primary HR set once; samples insert against it.
    // Created by startActivity (fresh) or the original start (resume), so it
    // always exists by the time recording begins.
    _hrSetId = db.primaryHrSetId(activityId);
    _sub = source.samples.listen(_onSample);
    _statusSub = source.status.listen(_onSourceStatus);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Drives elapsed time in the UI when no HR sample arrives that second.
      if (mounted && !state.stopped) {
        state = state.copyWith(now: DateTime.now());
        _updateLiveActivity();
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
  final RecordingSentinel sentinel;
  final VoidCallback? onStopped;
  // Tracks the in-flight sentinel write so a quick stop can await it before
  // clearing — otherwise a late write could land after clear() and resurrect a
  // bogus recovery prompt for an already-stopped recording.
  Future<void>? _sentinelWrite;
  final DateTime _started;
  final ZoneSetup? _zoneSetup;
  final RecordingLiveActivity _liveActivity = const RecordingLiveActivity();
  late final Future<int> _hrSetId;
  late final StreamSubscription<HrSample> _sub;
  late final StreamSubscription<HrSourceStatus> _statusSub;
  late final Timer _ticker;
  late final Timer _statsTicker;
  int _sampleCount = 0;
  late DateTime _lastStatsTick;

  /// Drops a crash sentinel so an interrupted recording can be recovered on the
  /// next launch. Only real BLE devices can be reconnected to, so the fake/debug
  /// source (no platform id) is skipped. Fire-and-forget: a failed write just
  /// means no recovery is offered, which is safe.
  void _writeSentinel(int activityId) {
    final platformId = source.devicePlatformId;
    if (platformId == null) return;
    _sentinelWrite = sentinel.write(
      InterruptedRecording(
        activityId: activityId,
        startedAtMs: state.startedAt.millisecondsSinceEpoch,
        devicePlatformId: platformId,
        deviceName: source.deviceName,
      ),
    );
  }

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
    await db.insertHrSample(
      setId: await _hrSetId,
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
        // Drive elapsed time from the wall clock, not sample.at: native samples
        // arrive in buffered batches with past timestamps, which made the
        // elapsed clock jump backwards (e.g. 0:13 → 0:10 → 0:13).
        now: DateTime.now(),
        sourceStatus: recovered ? HrSourceStatusKind.connected : null,
        sourceStatusAt: recovered ? sample.at : null,
        clearSourceStatusMessage: recovered,
        clearReconnectAttempt: recovered,
      );
      _updateLiveActivity();
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
        // Wall clock, not status.at, to keep elapsed monotonic (see _onSample).
        // sourceStatusAt still uses status.at so signal age stays accurate.
        now: DateTime.now(),
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
      _updateLiveActivity();
    }
  }

  void _updateLiveActivity() {
    final status = switch (state.sourceStatus) {
      HrSourceStatusKind.connected => 'Recording',
      HrSourceStatusKind.reconnecting => 'Reconnecting',
      HrSourceStatusKind.disconnected => 'Signal lost',
      HrSourceStatusKind.disposed => 'Stopped',
    };
    final detail = state.reconnectAttempt == null
        ? state.sourceStatusMessage
        : 'Attempt ${state.reconnectAttempt}';
    _liveActivity.update(
      liveActivitySnapshotFor(
        activityId: state.activityId,
        elapsed: state.elapsed,
        bpm: state.currentBpm,
        status: status,
        statusDetail: detail,
        zone: _zoneSetup?.zoneFor(state.currentBpm),
      ),
    );
  }

  Future<void> stop() async {
    if (state.stopped) return;
    appLog(
      'Recording',
      'Stopping activity ${state.activityId} on ${source.deviceName} after ${state.elapsed.inSeconds}s',
    );
    state = state.copyWith(stopped: true);
    try {
      final elapsedMs = DateTime.now().difference(_started).inMilliseconds;
      await db.finalizeActivity(
        activityId: state.activityId,
        durationMs: elapsedMs,
      );
      await db.computeAndSaveShape(state.activityId);
    } catch (e) {
      appLog('Recording', 'Error finalizing activity ${state.activityId}: $e');
    } finally {
      // Clean stop: drop the crash sentinel so this activity isn't offered for
      // recovery. dispose() without stop() deliberately leaves it in place.
      // Await any in-flight write first so it can't land after the clear.
      await _sentinelWrite;
      await sentinel.clear();
      await _shutdownResources();
      onStopped?.call();
    }
  }

  /// Cancels timers, subscriptions, live activity, and source. Each step is
  /// attempted independently so a failure in one does not block the others.
  Future<void> _shutdownResources() async {
    _ticker.cancel();
    _statsTicker.cancel();
    try {
      await _sub.cancel();
    } catch (e) {
      appLog('Recording', 'HR sub cancel error: $e');
    }
    try {
      await _statusSub.cancel();
    } catch (e) {
      appLog('Recording', 'Status sub cancel error: $e');
    }
    try {
      await _liveActivity.end(activityId: state.activityId);
    } catch (e) {
      appLog('Recording', 'Live activity end error: $e');
    }
    try {
      await source.dispose();
    } catch (e) {
      appLog('Recording', 'Source dispose error: $e');
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _statsTicker.cancel();
    if (!state.stopped) {
      _sub.cancel();
      _statusSub.cancel();
      _liveActivity.end(activityId: state.activityId);
      source.dispose();
    }
    super.dispose();
  }
}

final recordingControllerProvider = StateNotifierProvider.autoDispose
    .family<RecordingController, RecordingState, int>((ref, activityId) {
      // keepAlive ensures recording continues even when no widget is watching
      // (e.g. user navigated to the Home tab). Released in onStopped so Riverpod
      // can dispose the controller once the user navigates away after stopping.
      final keepAlive = ref.keepAlive();
      final db = ref.watch(databaseProvider);
      final athlete = ref.read(defaultAthleteProvider).valueOrNull;
      // Picker writes here before navigating to the recording screen. Fall back to
      // a synthetic source if someone deep-links into /recording/:id directly.
      final source = ref.read(pendingHrSourceProvider) ?? FakeHeartRateSource();
      // Non-null when the recovery flow is resuming a crashed recording; anchors
      // the controller to the original start time instead of now.
      final resumeStartedAt = ref.read(resumeStartedAtProvider);
      // Clear the slots AFTER this provider finishes initializing. Mutating
      // another provider inline would trip Riverpod's "providers can't modify
      // each other during build" guard.
      Future.microtask(() {
        try {
          ref.read(pendingHrSourceProvider.notifier).state = null;
          ref.read(resumeStartedAtProvider.notifier).state = null;
        } catch (_) {
          // Container may be disposed by then; safe to swallow.
        }
      });
      return RecordingController(
        db: db,
        source: source,
        activityId: activityId,
        sentinel: ref.read(recordingSentinelProvider),
        resumeStartedAt: resumeStartedAt,
        zoneSetup: zoneSetupFor(
          maxHr: athlete?.maxHeartrate,
          restingHr: athlete?.restingHeartrate,
        ),
        onStopped: keepAlive.close,
      );
    });
