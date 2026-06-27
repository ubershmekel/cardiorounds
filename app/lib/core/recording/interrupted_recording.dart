import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';

/// A recording that was live when the app last died. Captured to a flat file
/// (see [RecordingSentinel]) so a crashed session can be detected and resumed
/// on the next launch. Carries the device id needed to reconnect and the
/// original start time so the resumed timeline continues seamlessly.
class InterruptedRecording {
  const InterruptedRecording({
    required this.activityId,
    required this.startedAtMs,
    required this.devicePlatformId,
    required this.deviceName,
  });

  final int activityId;
  final int startedAtMs;
  final String devicePlatformId;
  final String deviceName;

  Map<String, Object?> toJson() => {
    'activityId': activityId,
    'startedAtMs': startedAtMs,
    'devicePlatformId': devicePlatformId,
    'deviceName': deviceName,
  };

  /// Returns null for malformed JSON rather than throwing — a corrupt sentinel
  /// should be ignored (and cleared), never crash startup.
  static InterruptedRecording? fromJson(Map<String, Object?> json) {
    final activityId = json['activityId'];
    final startedAtMs = json['startedAtMs'];
    final devicePlatformId = json['devicePlatformId'];
    final deviceName = json['deviceName'];
    if (activityId is! int ||
        startedAtMs is! int ||
        devicePlatformId is! String ||
        deviceName is! String) {
      return null;
    }
    return InterruptedRecording(
      activityId: activityId,
      startedAtMs: startedAtMs,
      devicePlatformId: devicePlatformId,
      deviceName: deviceName,
    );
  }
}

/// Persists a sentinel file while a recording is live and deletes it on a clean
/// stop. If the file is still present on the next launch, the previous session
/// crashed or was killed mid-recording and can be offered for recovery.
///
/// Why a file instead of inferring from the DB: a just-started activity also
/// has `durationMs == 0`, so the DB alone can't tell "crashed" from "still
/// finalizing". The file's presence is the unambiguous crash signal, and it
/// carries the device id required to reconnect. Recovery is a no-op on web,
/// which has no application-documents directory.
class RecordingSentinel {
  const RecordingSentinel();

  static const _fileName = 'recording_in_progress.json';

  Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> write(InterruptedRecording recording) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(jsonEncode(recording.toJson()));
    } catch (e) {
      appLog('Recovery', 'Failed to write sentinel: $e');
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (file == null) return;
      if (await file.exists()) await file.delete();
    } catch (e) {
      appLog('Recovery', 'Failed to clear sentinel: $e');
    }
  }

  Future<InterruptedRecording?> read() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      return InterruptedRecording.fromJson(raw.cast<String, Object?>());
    } catch (e) {
      appLog('Recovery', 'Failed to read sentinel: $e');
      return null;
    }
  }
}

final recordingSentinelProvider = Provider<RecordingSentinel>(
  (_) => const RecordingSentinel(),
);

/// Read once at launch to decide whether to offer recovery. Invalidate after
/// resuming or discarding so a stale prompt can't reappear.
final interruptedRecordingProvider = FutureProvider<InterruptedRecording?>((
  ref,
) {
  return ref.watch(recordingSentinelProvider).read();
});

/// Set by the recovery flow before navigating to the recording screen, so the
/// [RecordingController] continues the original timeline instead of starting a
/// fresh one. Read and cleared by the recording controller provider.
final resumeStartedAtProvider = StateProvider<DateTime?>((_) => null);
