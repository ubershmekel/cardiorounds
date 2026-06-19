import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_logger.dart';
import 'bluetooth_hr_source.dart';
import 'hr_scanner.dart';

class BluetoothHrScanner implements HrScanner {
  BluetoothHrScanner();

  final Set<DeviceIdentifier> _seen = {};
  final _results = StreamController<List<ScannedDevice>>.broadcast();
  StreamSubscription<List<ScanResult>>? _sub;

  @override
  Stream<List<ScannedDevice>> get results => _results.stream;

  @override
  Future<void> start({Duration timeout = const Duration(seconds: 30)}) async {
    appLog('BTScan', 'Starting scan (timeout: ${timeout.inSeconds}s)');
    _seen.clear();
    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((batch) {
      var changed = false;
      for (final r in batch) {
        if (_seen.add(r.device.remoteId)) {
          changed = true;
          appLog(
            'BTScan',
            'Found device: ${r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str} RSSI=${r.rssi}',
          );
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

  List<ScannedDevice> _dedupedSorted() {
    final byId = <DeviceIdentifier, ScanResult>{};
    for (final r in FlutterBluePlus.lastScanResults) {
      byId[r.device.remoteId] = r;
    }
    return byId.values
        .map(
          (r) => ScannedDevice(
            platformId: r.device.remoteId.str,
            name: r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.device.remoteId.str,
            rssi: r.rssi,
          ),
        )
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  @override
  Future<void> stop() async {
    appLog('BTScan', 'Stopping scan');
    await FlutterBluePlus.stopScan();
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _results.close();
  }
}
