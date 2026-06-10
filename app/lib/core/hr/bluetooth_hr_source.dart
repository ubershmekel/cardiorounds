import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_logger.dart';
import 'hr_source.dart';

final Guid hrServiceGuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
final Guid hrMeasurementGuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');

int? parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) return null;
  final flags = data[0];
  final uint16 = (flags & 0x01) != 0;
  if (uint16) {
    if (data.length < 3) return null;
    return data[1] | (data[2] << 8);
  }
  if (data.length < 2) return null;
  return data[1];
}

class BluetoothHeartRateSource implements HeartRateSource {
  BluetoothHeartRateSource._(this._device, this._displayName);

  final BluetoothDevice _device;
  final String _displayName;

  final _samples = StreamController<HrSample>.broadcast();
  StreamSubscription<List<int>>? _measurementSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  bool _disposed = false;

  @override
  String get deviceName => _displayName;

  @override
  String? get devicePlatformId => _device.remoteId.str;

  @override
  Stream<HrSample> get samples => _samples.stream;

  static Future<BluetoothHeartRateSource> connect(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final displayName = _bestName(device);
    appLog('BT', 'Connecting to $displayName (${device.remoteId.str})');
    await device.connect(
      timeout: timeout,
      autoConnect: false,
      license: License.free,
    );
    appLog('BT', 'Connected to $displayName, discovering services');
    final services = await device.discoverServices();
    appLog('BT', 'Discovered ${services.length} services on $displayName');
    final hrService = services.firstWhere(
      (s) => s.uuid == hrServiceGuid,
      orElse: () => throw StateError(
        'Device does not advertise the Heart Rate service (0x180D).',
      ),
    );
    final measurement = hrService.characteristics.firstWhere(
      (c) => c.uuid == hrMeasurementGuid,
      orElse: () => throw StateError(
        'Device is missing the Heart Rate Measurement characteristic.',
      ),
    );
    await measurement.setNotifyValue(true);
    appLog('BT', 'Notifications enabled on $displayName — ready');

    final source = BluetoothHeartRateSource._(device, displayName);
    source._measurementSub = measurement.lastValueStream.listen((data) {
      final bpm = parseHeartRateMeasurement(data);
      source._samples.add(HrSample(bpm: bpm, at: DateTime.now()));
    });
    source._connectionSub = device.connectionState.listen((s) {
      appLog('BT', '$displayName connection state: $s');
      if (s == BluetoothConnectionState.disconnected && !source._disposed) {
        source._samples.add(HrSample(bpm: null, at: DateTime.now()));
      }
    });
    return source;
  }

  static String _bestName(BluetoothDevice device) {
    final name = device.platformName;
    if (name.isNotEmpty) return name;
    return device.remoteId.str;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    appLog('BT', 'Disposing source for $_displayName');
    await _measurementSub?.cancel();
    await _connectionSub?.cancel();
    try {
      await _device.disconnect();
    } catch (_) {
      // best-effort
    }
    await _samples.close();
  }
}
