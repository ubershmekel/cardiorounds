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

/// Live state of one device within a recording: its name, current reading, and
/// connection status. A single-device recording has exactly one of these.
class DeviceRecordingState {
  const DeviceRecordingState({
    required this.setId,
    required this.deviceName,
    required this.currentBpm,
    required this.sourceStatus,
    required this.sourceStatusAt,
    required this.sourceStatusMessage,
    required this.reconnectAttempt,
  });

  final int setId;
  final String deviceName;
  final int? currentBpm;
  final HrSourceStatusKind sourceStatus;
  final DateTime sourceStatusAt;
  final String? sourceStatusMessage;
  final int? reconnectAttempt;

  Duration sourceStatusAge(DateTime now) => now.difference(sourceStatusAt);

  DeviceRecordingState copyWith({
    int? currentBpm,
    bool bpmIsNull = false,
    HrSourceStatusKind? sourceStatus,
    DateTime? sourceStatusAt,
    String? sourceStatusMessage,
    bool clearSourceStatusMessage = false,
    int? reconnectAttempt,
    bool clearReconnectAttempt = false,
  }) {
    return DeviceRecordingState(
      setId: setId,
      deviceName: deviceName,
      currentBpm: bpmIsNull ? null : (currentBpm ?? this.currentBpm),
      sourceStatus: sourceStatus ?? this.sourceStatus,
      sourceStatusAt: sourceStatusAt ?? this.sourceStatusAt,
      sourceStatusMessage: clearSourceStatusMessage
          ? null
          : (sourceStatusMessage ?? this.sourceStatusMessage),
      reconnectAttempt: clearReconnectAttempt
          ? null
          : (reconnectAttempt ?? this.reconnectAttempt),
    );
  }
}

class RecordingState {
  const RecordingState({
    required this.activityId,
    required this.startedAt,
    required this.now,
    required this.devices,
    required this.stopped,
  });

  final int activityId;
  final DateTime startedAt;
  final DateTime now;
  final List<DeviceRecordingState> devices;
  final bool stopped;

  Duration get elapsed => now.difference(startedAt);

  /// The primary (first) device — used by the single-device layout and the
  /// iOS Live Activity.
  DeviceRecordingState get primary => devices.first;

  RecordingState copyWith({
    DateTime? now,
    List<DeviceRecordingState>? devices,
    bool? stopped,
  }) {
    return RecordingState(
      activityId: activityId,
      startedAt: startedAt,
      now: now ?? this.now,
      devices: devices ?? this.devices,
      stopped: stopped ?? this.stopped,
    );
  }
}

class RecordingController extends StateNotifier<RecordingState> {
  RecordingController({
    required this.db,
    required this.sources,
    required int activityId,
    this.sentinel = const RecordingSentinel(),
    DateTime? resumeStartedAt,
    ZoneSetup? zoneSetup,
    this.onStopped,
  }) : assert(sources.isNotEmpty, 'a recording needs at least one source'),
       _started = resumeStartedAt ?? DateTime.now(),
       _zoneSetup = zoneSetup,
       super(
         RecordingState(
           activityId: activityId,
           // For a resumed recording, anchor to the original start so sample
           // tMs offsets and elapsed time continue the existing timeline.
           startedAt: resumeStartedAt ?? DateTime.now(),
           now: DateTime.now(),
           devices: [
             for (final s in sources)
               DeviceRecordingState(
                 setId: s.setId,
                 deviceName: s.source.deviceName,
                 currentBpm: null,
                 sourceStatus: HrSourceStatusKind.connected,
                 sourceStatusAt: DateTime.now(),
                 sourceStatusMessage: null,
                 reconnectAttempt: null,
               ),
           ],
           stopped: false,
         ),
       ) {
    final names = sources.map((s) => s.source.deviceName).join(', ');
    final verb = resumeStartedAt == null ? 'Started' : 'Resumed';
    appLog('Recording', '$verb activity $activityId on $names');
    _writeSentinel(activityId);
    _liveActivity.start(
      activityId: activityId,
      deviceName: sources.first.source.deviceName,
      startedAt: state.startedAt,
    );
    _updateLiveActivity();
    // A negative setId is the deep-link fallback marker (see provider): resolve
    // the activity's primary HR set lazily. Real sources carry a valid set id.
    _setIds = [
      for (final s in sources)
        s.setId >= 0 ? Future.value(s.setId) : db.primaryHrSetId(activityId),
    ];
    for (var i = 0; i < sources.length; i++) {
      final index = i;
      _sampleSubs.add(sources[i].source.samples.listen((s) => _onSample(index, s)));
      _statusSubs.add(
        sources[i].source.status.listen((s) => _onSourceStatus(index, s)),
      );
    }

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
  final List<RecordingSource> sources;
  final RecordingSentinel sentinel;
  final VoidCallback? onStopped;
  // Tracks the in-flight sentinel write so a quick stop can await it before
  // clearing — otherwise a late write could land after clear() and resurrect a
  // bogus recovery prompt for an already-stopped recording.
  Future<void>? _sentinelWrite;
  final DateTime _started;
  final ZoneSetup? _zoneSetup;
  final RecordingLiveActivity _liveActivity = const RecordingLiveActivity();
  late final List<Future<int>> _setIds;
  final List<StreamSubscription<HrSample>> _sampleSubs = [];
  final List<StreamSubscription<HrSourceStatus>> _statusSubs = [];
  late final Timer _ticker;
  late final Timer _statsTicker;
  int _sampleCount = 0;
  late DateTime _lastStatsTick;

  /// Drops a crash sentinel so an interrupted recording can be recovered on the
  /// next launch. Only real BLE devices can be reconnected to, so the fake/debug
  /// source (no platform id) is skipped. Fire-and-forget: a failed write just
  /// means no recovery is offered, which is safe.
  void _writeSentinel(int activityId) {
    final devices = [
      for (final s in sources)
        if (s.source.devicePlatformId case final platformId?)
          RecordedDevice(platformId: platformId, name: s.source.deviceName),
    ];
    if (devices.isEmpty) return;
    _sentinelWrite = sentinel.write(
      InterruptedRecording(
        activityId: activityId,
        startedAtMs: state.startedAt.millisecondsSinceEpoch,
        devices: devices,
      ),
    );
  }

  /// Replaces the [index]-th device's state via [update] and advances the shared
  /// clock. No-op once disposed.
  void _updateDevice(
    int index,
    DeviceRecordingState Function(DeviceRecordingState) update, {
    DateTime? now,
  }) {
    if (!mounted) return;
    final devices = [...state.devices];
    devices[index] = update(devices[index]);
    state = state.copyWith(now: now ?? DateTime.now(), devices: devices);
    _updateLiveActivity();
  }

  Future<void> _onSample(int index, HrSample sample) async {
    if (state.stopped) return;
    final source = sources[index].source;
    if (sample.bpm == null) {
      appLog(
        'Recording',
        'Null BPM received from ${source.deviceName}; device may have disconnected',
      );
    }
    _sampleCount++;
    final tMs = sample.at.difference(_started).inMilliseconds;
    await db.insertHrSample(
      setId: await _setIds[index],
      tMs: tMs,
      hr: sample.bpm,
    );
    _updateDevice(index, (d) {
      final recovered =
          sample.bpm != null && d.sourceStatus != HrSourceStatusKind.connected;
      return d.copyWith(
        currentBpm: sample.bpm,
        bpmIsNull: sample.bpm == null,
        sourceStatus: recovered ? HrSourceStatusKind.connected : null,
        sourceStatusAt: recovered ? sample.at : null,
        clearSourceStatusMessage: recovered,
        clearReconnectAttempt: recovered,
      );
      // Drive elapsed time from the wall clock, not sample.at: native samples
      // arrive in buffered batches with past timestamps, which made the elapsed
      // clock jump backwards (e.g. 0:13 → 0:10 → 0:13).
    });
  }

  void _onSourceStatus(int index, HrSourceStatus status) {
    if (state.stopped) return;
    final source = sources[index].source;
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
    _updateDevice(index, (d) {
      return d.copyWith(
        currentBpm: status.kind == HrSourceStatusKind.connected
            ? d.currentBpm
            : null,
        bpmIsNull: status.kind != HrSourceStatusKind.connected,
        sourceStatus: status.kind,
        // sourceStatusAt uses status.at so signal age stays accurate; the shared
        // clock (state.now) stays on the wall clock to keep elapsed monotonic.
        sourceStatusAt: status.at,
        sourceStatusMessage: status.message,
        clearSourceStatusMessage: status.message == null,
        reconnectAttempt: status.attempt,
        clearReconnectAttempt: status.attempt == null,
      );
    });
  }

  void _updateLiveActivity() {
    final primary = state.primary;
    final status = switch (primary.sourceStatus) {
      HrSourceStatusKind.connected => 'Recording',
      HrSourceStatusKind.reconnecting => 'Reconnecting',
      HrSourceStatusKind.disconnected => 'Signal lost',
      HrSourceStatusKind.disposed => 'Stopped',
    };
    final detail = primary.reconnectAttempt == null
        ? primary.sourceStatusMessage
        : 'Attempt ${primary.reconnectAttempt}';
    _liveActivity.update(
      liveActivitySnapshotFor(
        activityId: state.activityId,
        elapsed: state.elapsed,
        bpm: primary.currentBpm,
        status: status,
        statusDetail: detail,
        zone: _zoneSetup?.zoneFor(primary.currentBpm),
      ),
    );
  }

  Future<void> stop() async {
    if (state.stopped) return;
    appLog(
      'Recording',
      'Stopping activity ${state.activityId} after ${state.elapsed.inSeconds}s',
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

  /// Cancels timers, subscriptions, live activity, and sources. Each step is
  /// attempted independently so a failure in one does not block the others.
  Future<void> _shutdownResources() async {
    _ticker.cancel();
    _statsTicker.cancel();
    for (final sub in [..._sampleSubs, ..._statusSubs]) {
      try {
        await sub.cancel();
      } catch (e) {
        appLog('Recording', 'Subscription cancel error: $e');
      }
    }
    try {
      await _liveActivity.end(activityId: state.activityId);
    } catch (e) {
      appLog('Recording', 'Live activity end error: $e');
    }
    for (final s in sources) {
      try {
        await s.source.dispose();
      } catch (e) {
        appLog('Recording', 'Source dispose error: $e');
      }
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _statsTicker.cancel();
    if (!state.stopped) {
      for (final sub in [..._sampleSubs, ..._statusSubs]) {
        sub.cancel();
      }
      _liveActivity.end(activityId: state.activityId);
      for (final s in sources) {
        s.source.dispose();
      }
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
      // Picker (or recovery) writes here before navigating to the recording
      // screen. Fall back to a single synthetic source if someone deep-links
      // into /recording/:id directly; setId -1 means "resolve the primary set".
      final pending = ref.read(pendingRecordingProvider);
      final sources = (pending != null && pending.isNotEmpty)
          ? pending
          : [RecordingSource(source: FakeHeartRateSource(), setId: -1)];
      // Non-null when the recovery flow is resuming a crashed recording; anchors
      // the controller to the original start time instead of now.
      final resumeStartedAt = ref.read(resumeStartedAtProvider);
      // Clear the slots AFTER this provider finishes initializing. Mutating
      // another provider inline would trip Riverpod's "providers can't modify
      // each other during build" guard.
      Future.microtask(() {
        try {
          ref.read(pendingRecordingProvider.notifier).state = null;
          ref.read(resumeStartedAtProvider.notifier).state = null;
        } catch (_) {
          // Container may be disposed by then; safe to swallow.
        }
      });
      return RecordingController(
        db: db,
        sources: sources,
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
