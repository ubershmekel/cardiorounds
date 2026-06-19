class ScannedDevice {
  const ScannedDevice({
    required this.platformId,
    required this.name,
    required this.rssi,
  });

  final String platformId;
  final String name;
  final int rssi;
}

abstract class HrScanner {
  Stream<List<ScannedDevice>> get results;
  Future<void> start({Duration timeout = const Duration(seconds: 30)});
  Future<void> stop();
  Future<void> dispose();
}
