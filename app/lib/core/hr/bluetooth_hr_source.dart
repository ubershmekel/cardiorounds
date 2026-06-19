import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_logger.dart';
import 'hr_source.dart';

final Guid hrServiceGuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
final Guid hrMeasurementGuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');

const Duration kBtConnectTimeout = Duration(seconds: 10);
const Duration kBtReconnectMaxDelay = Duration(seconds: 30);

Duration bluetoothReconnectDelayForAttempt(int attempt) {
  if (attempt <= 1) return Duration.zero;
  final seconds = math.min(1 << (attempt - 2), kBtReconnectMaxDelay.inSeconds);
  return Duration(seconds: seconds);
}

int? parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) return null;
  final flags = data[0];
  final uint16 = (flags & 0x01) != 0;
  final bpm = uint16
      ? (data.length < 3 ? null : data[1] | (data[2] << 8))
      : (data.length < 2 ? null : data[1]);
  // Treat 0 as null — some monitors emit 0 BPM during sensor contact loss
  // instead of dropping the notification entirely.
  return (bpm == null || bpm <= 0) ? null : bpm;
}

class BluetoothHeartRateSource implements HeartRateSource {
  BluetoothHeartRateSource._(this._device, this._displayName);

  final BluetoothDevice _device;
  final String _displayName;

  final _samples = StreamController<HrSample>.broadcast();
  final _status = StreamController<HrSourceStatus>.broadcast();
  StreamSubscription<List<int>>? _measurementSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<void>? _servicesResetSub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _monitorConnectionState = false;
  bool _reconnectInFlight = false;
  bool _signalLost = false;
  bool _waitingForRecoveredSample = false;
  bool _disposed = false;
  DateTime? _lostAt;

  @override
  String get deviceName => _displayName;

  @override
  String? get devicePlatformId => _device.remoteId.str;

  @override
  Stream<HrSample> get samples => _samples.stream;

  @override
  Stream<HrSourceStatus> get status => _status.stream;

  static Future<BluetoothHeartRateSource> connect(
    String remoteId, {
    String name = '',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(remoteId));
    final displayName = name.isNotEmpty ? name : remoteId;
    final source = BluetoothHeartRateSource._(device, displayName);
    source._connectionSub = device.connectionState.listen(
      source._handleConnectionState,
    );
    source._servicesResetSub = device.onServicesReset.listen((_) {
      source._handleServicesReset();
    });

    try {
      await source._connectAndEnableNotifications(
        timeout: timeout,
        logPrefix: '',
      );
    } catch (_) {
      await source._connectionSub?.cancel();
      await source._servicesResetSub?.cancel();
      await source._measurementSub?.cancel();
      rethrow;
    }

    source._monitorConnectionState = true;
    source._emitStatus(HrSourceStatusKind.connected);
    return source;
  }

  Future<void> _connectAndEnableNotifications({
    required Duration timeout,
    required String logPrefix,
  }) async {
    final prefix = logPrefix.isEmpty ? '' : '$logPrefix ';
    if (!_device.isConnected) {
      appLog(
        'BT',
        '${prefix}Connecting to $_displayName (${_device.remoteId.str})',
      );
      await _device.connect(
        timeout: timeout,
        autoConnect: false,
        license: License.free,
      );
    } else {
      appLog('BT', '$prefix$_displayName already connected');
    }
    appLog('BT', '${prefix}Connected to $_displayName, discovering services');
    await _enableHeartRateNotifications(logPrefix: logPrefix);
  }

  Future<void> _enableHeartRateNotifications({
    required String logPrefix,
  }) async {
    final prefix = logPrefix.isEmpty ? '' : '$logPrefix ';
    final services = await _device.discoverServices();
    appLog(
      'BT',
      '${prefix}Discovered ${services.length} services on $_displayName',
    );
    final measurement = _heartRateMeasurement(services);

    await _measurementSub?.cancel();
    await measurement.setNotifyValue(true);
    _measurementSub = measurement.lastValueStream.listen(
      _handleMeasurement,
      onError: (Object e) {
        appLog('BT', 'Measurement stream error on $_displayName: $e');
        _markSignalLost('measurement stream error');
        _scheduleReconnect();
      },
    );
    appLog('BT', '${prefix}Notifications enabled on $_displayName - ready');
  }

  BluetoothCharacteristic _heartRateMeasurement(
    List<BluetoothService> services,
  ) {
    final hrService = services.firstWhere(
      (s) => s.uuid == hrServiceGuid,
      orElse: () => throw StateError(
        'Device does not advertise the Heart Rate service (0x180D).',
      ),
    );
    return hrService.characteristics.firstWhere(
      (c) => c.uuid == hrMeasurementGuid,
      orElse: () => throw StateError(
        'Device is missing the Heart Rate Measurement characteristic.',
      ),
    );
  }

  void _handleMeasurement(List<int> data) {
    final now = DateTime.now();
    final bpm = parseHeartRateMeasurement(data);
    if (bpm != null && _waitingForRecoveredSample) {
      final lostFor = _lostAt == null ? null : now.difference(_lostAt!);
      appLog(
        'BT',
        'Recovered HR samples from $_displayName'
            '${lostFor == null ? '' : ' after ${lostFor.inSeconds}s without BPM'}',
      );
      _signalLost = false;
      _waitingForRecoveredSample = false;
      _lostAt = null;
      _reconnectAttempt = 0;
      _emitStatus(HrSourceStatusKind.connected);
    }
    _samples.add(HrSample(bpm: bpm, at: now));
  }

  void _handleConnectionState(BluetoothConnectionState s) {
    appLog('BT', '$_displayName connection state: $s');
    if (!_monitorConnectionState || _disposed) return;
    if (s == BluetoothConnectionState.connected) {
      if (_signalLost && !_reconnectInFlight) {
        appLog(
          'BT',
          '$_displayName reconnected at the platform layer; re-enabling notifications',
        );
        _scheduleReconnect();
      }
      return;
    }
    if (s == BluetoothConnectionState.disconnected) {
      // The 2026-06-12 support log showed this exact event at 12:32:27,
      // followed by one null BPM and no reconnect attempt. That meant the app
      // noticed the loss but had no revitalization path. Keep this log paired
      // with _scheduleReconnect logs so future exports show what the app tried.
      _markSignalLost('connection state disconnected');
      _scheduleReconnect();
    }
  }

  void _handleServicesReset() {
    if (_disposed) return;
    appLog(
      'BT',
      '$_displayName services reset; rediscovering heart-rate service',
    );
    _markSignalLost('services reset');
    _scheduleReconnect();
  }

  void _markSignalLost(String reason) {
    if (!_signalLost) {
      _signalLost = true;
      _waitingForRecoveredSample = true;
      _lostAt = DateTime.now();
      _samples.add(HrSample(bpm: null, at: _lostAt!));
      _emitStatus(HrSourceStatusKind.disconnected, message: reason);
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectInFlight || _reconnectTimer != null) return;
    _reconnectAttempt += 1;
    final attempt = _reconnectAttempt;
    final delay = bluetoothReconnectDelayForAttempt(attempt);
    appLog(
      'BT',
      'Reconnect attempt $attempt for $_displayName scheduled in ${delay.inSeconds}s',
    );
    _emitStatus(
      HrSourceStatusKind.reconnecting,
      attempt: attempt,
      message: delay == Duration.zero ? 'now' : 'in ${delay.inSeconds}s',
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_runReconnectAttempt(attempt));
    });
  }

  Future<void> _runReconnectAttempt(int attempt) async {
    if (_disposed || _reconnectInFlight) return;
    _reconnectInFlight = true;
    _emitStatus(
      HrSourceStatusKind.reconnecting,
      attempt: attempt,
      message: 'connecting',
    );
    appLog('BT', 'Reconnect attempt $attempt for $_displayName starting');
    try {
      await _connectAndEnableNotifications(
        timeout: kBtConnectTimeout,
        logPrefix: 'Reconnect attempt $attempt:',
      );
      appLog(
        'BT',
        'Reconnect attempt $attempt for $_displayName re-enabled notifications; waiting for BPM',
      );
      _waitingForRecoveredSample = true;
    } catch (e) {
      appLog('BT', 'Reconnect attempt $attempt for $_displayName failed: $e');
    } finally {
      _reconnectInFlight = false;
    }
    if (!_disposed && _signalLost) {
      _scheduleReconnect();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    appLog('BT', 'Disposing source for $_displayName');
    _reconnectTimer?.cancel();
    await _measurementSub?.cancel();
    await _connectionSub?.cancel();
    await _servicesResetSub?.cancel();
    _emitStatus(HrSourceStatusKind.disposed);
    try {
      await _device.disconnect();
    } catch (_) {
      // best-effort
    }
    await _samples.close();
    await _status.close();
  }

  void _emitStatus(HrSourceStatusKind kind, {int? attempt, String? message}) {
    if (_status.isClosed) return;
    _status.add(
      HrSourceStatus(
        kind: kind,
        at: DateTime.now(),
        attempt: attempt,
        message: message,
      ),
    );
  }
}
