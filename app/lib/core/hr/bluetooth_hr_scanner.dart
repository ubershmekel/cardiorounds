import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_logger.dart';
import 'bluetooth_hr_source.dart';

class BluetoothHrScanner {
  BluetoothHrScanner();

  final Set<DeviceIdentifier> _seen = {};
  final _results = StreamController<List<ScanResult>>.broadcast();
  StreamSubscription<List<ScanResult>>? _sub;

  Stream<List<ScanResult>> get results => _results.stream;

  Future<void> start({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    appLog('BTScan', 'Starting scan (timeout: ${timeout.inSeconds}s)');
    _seen.clear();
    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((batch) {
      var changed = false;
      for (final r in batch) {
        if (_seen.add(r.device.remoteId)) {
          changed = true;
          appLog('BTScan', 'Found device: ${r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str} RSSI=${r.rssi}');
        }
      }
      if (changed) {
        _results.add(_dedupedSorted());
      }
    });
    await FlutterBluePlus.startScan(
      withServices: [hrServiceGuid],
      timeout: timeout,
    );
  }

  List<ScanResult> _dedupedSorted() {
    final byId = <DeviceIdentifier, ScanResult>{};
    for (final r in FlutterBluePlus.lastScanResults) {
      byId[r.device.remoteId] = r;
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> stop() async {
    appLog('BTScan', 'Stopping scan');
    await FlutterBluePlus.stopScan();
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }
}
