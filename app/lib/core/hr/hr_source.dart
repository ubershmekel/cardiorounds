class HrSample {
  const HrSample({required this.bpm, required this.at});

  final int? bpm;
  final DateTime at;
}

enum HrSourceStatusKind {
  /// Connecting for the first time: selected on Confirm Record and handed to
  /// the recording screen before the connection finished. Distinct from
  /// [reconnecting], which is a previously-live source that dropped.
  connecting,
  connected,
  reconnecting,
  disconnected,
  disposed,
}

class HrSourceStatus {
  const HrSourceStatus({
    required this.kind,
    required this.at,
    this.attempt,
    this.message,
  });

  final HrSourceStatusKind kind;
  final DateTime at;
  final int? attempt;
  final String? message;
}

abstract class HeartRateSource {
  String get deviceName;
  String? get devicePlatformId;
  Stream<HrSample> get samples;
  Stream<HrSourceStatus> get status;
  Future<void> dispose();
}
