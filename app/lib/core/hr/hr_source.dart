class HrSample {
  const HrSample({required this.bpm, required this.at});

  final int? bpm;
  final DateTime at;
}

abstract class HeartRateSource {
  String get deviceName;
  String? get devicePlatformId;
  Stream<HrSample> get samples;
  Future<void> dispose();
}
