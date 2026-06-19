import 'dart:async';

import 'package:flutter/services.dart';

import '../app_logger.dart';
import 'hr_scanner.dart';

/// iOS-native scanner that asks [HrBackgroundCentral] (Swift) to scan for
/// Heart Rate peripherals and polls the results via the existing method channel.
///
/// Because the native central owns the CoreBluetooth stack, using it for
/// scanning means the same [CBCentralManager] that will own the recording
/// connection is already warmed up. When the user picks a device and
/// [NativeBluetoothHeartRateSource.start] is called, the central connects
/// immediately — no tear-down of a FlutterBluePlus connection first.
class NativeHrScanner implements HrScanner {
  static const _channel = MethodChannel('cardiorounds/hr_central');
  static const _pollInterval = Duration(seconds: 2);

  final _results = StreamController<List<ScannedDevice>>.broadcast();
  Timer? _pollTimer;

  @override
  Stream<List<ScannedDevice>> get results => _results.stream;

  @override
  Future<void> start({Duration timeout = const Duration(seconds: 30)}) async {
    appLog('NativeScan', 'Starting native scan');
    await _channel.invokeMethod<void>('scanStart');
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_results.isClosed) return;
    try {
      final raw = await _channel.invokeListMethod<Object>('scanDrain');
      if (raw == null || _results.isClosed) return;
      final devices = raw
          .cast<Map>()
          .map(
            (m) => ScannedDevice(
              platformId: m['id'] as String,
              name: (m['name'] as String?) ?? '',
              rssi: (m['rssi'] as num).toInt(),
            ),
          )
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      _results.add(devices);
    } catch (e) {
      appLog('NativeScan', 'Poll error: $e');
    }
  }

  @override
  Future<void> stop() async {
    appLog('NativeScan', 'Stopping native scan');
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      await _channel.invokeMethod<void>('scanStop');
    } catch (e) {
      appLog('NativeScan', 'Stop error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _results.close();
  }
}
