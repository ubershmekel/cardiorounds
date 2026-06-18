import 'dart:async';

import 'package:flutter/services.dart';

import '../app_logger.dart';
import 'hr_source.dart';

/// A heart-rate source backed by the native iOS [HrBackgroundCentral].
///
/// Unlike [BluetoothHeartRateSource] (which receives BLE notifications directly
/// in Dart), this source delegates the connection to native Swift. The native
/// side buffers samples while iOS has the app suspended; this Dart side drains
/// that buffer on a timer and replays it as a normal [HrSample] stream. On
/// resume, the first drain returns the whole backlog at once, so the recording
/// controller writes the missed samples to the DB with their real timestamps.
///
/// See `ios/Runner/HrBackgroundCentral.swift` for why the collection lives in
/// native code: the per-notification append finishes inside the brief CPU
/// window iOS grants a backgrounded `bluetooth-central` app, where waking the
/// whole Flutter engine to run a Dart handler does not.
class NativeBluetoothHeartRateSource implements HeartRateSource {
  NativeBluetoothHeartRateSource._(this._displayName, this._remoteId);

  static const MethodChannel _channel = MethodChannel('cardiorounds/hr_central');

  // How often to pull buffered samples while the app is foregrounded. Has no
  // effect on what's captured in the background — the native buffer fills
  // regardless; this only controls how promptly the UI catches up.
  static const Duration _drainInterval = Duration(seconds: 1);

  final String _displayName;
  final String _remoteId;

  final _samples = StreamController<HrSample>.broadcast();
  final _status = StreamController<HrSourceStatus>.broadcast();
  Timer? _drainTimer;
  bool _disposed = false;
  bool _draining = false;

  @override
  String get deviceName => _displayName;

  @override
  String? get devicePlatformId => _remoteId;

  @override
  Stream<HrSample> get samples => _samples.stream;

  @override
  Stream<HrSourceStatus> get status => _status.stream;

  static Future<NativeBluetoothHeartRateSource> start({
    required String remoteId,
    required String name,
  }) async {
    final source = NativeBluetoothHeartRateSource._(name, remoteId);
    appLog('BT', 'Native central starting for $name ($remoteId)');
    await _channel.invokeMethod<String>('start', {
      'remoteId': remoteId,
      'name': name,
    });
    source._emitStatus(HrSourceStatusKind.connected);
    source._drainTimer = Timer.periodic(
      _drainInterval,
      (_) => source._drain(),
    );
    return source;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('drain');
      if (result == null || _samples.isClosed) return;
      _emitEvents(result['events'] as List<dynamic>? ?? const []);
      _emitSamples(result['samples'] as List<dynamic>? ?? const []);
    } catch (e) {
      appLog('BT', 'Native drain error for $_displayName: $e');
    } finally {
      _draining = false;
    }
  }

  void _emitSamples(List<dynamic> samples) {
    for (final raw in samples) {
      final map = (raw as Map).cast<String, dynamic>();
      final tMs = (map['tMs'] as num).toInt();
      final bpm = map['bpm'] as int?;
      _samples.add(
        HrSample(bpm: bpm, at: DateTime.fromMillisecondsSinceEpoch(tMs)),
      );
    }
  }

  void _emitEvents(List<dynamic> events) {
    for (final raw in events) {
      final map = (raw as Map).cast<String, dynamic>();
      final tMs = (map['tMs'] as num).toInt();
      final at = DateTime.fromMillisecondsSinceEpoch(tMs);
      final kind = switch (map['kind'] as String?) {
        'connected' => HrSourceStatusKind.connected,
        'reconnecting' => HrSourceStatusKind.reconnecting,
        'disconnected' => HrSourceStatusKind.disconnected,
        _ => null,
      };
      if (kind == null) continue;
      _emitStatus(kind, message: map['message'] as String?, at: at);
    }
  }

  void _emitStatus(
    HrSourceStatusKind kind, {
    String? message,
    DateTime? at,
  }) {
    if (_status.isClosed) return;
    _status.add(
      HrSourceStatus(kind: kind, at: at ?? DateTime.now(), message: message),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    appLog('BT', 'Disposing native source for $_displayName');
    _drainTimer?.cancel();
    // Final drain so samples captured between the last tick and stop aren't lost.
    await _drain();
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      appLog('BT', 'Native stop error for $_displayName: $e');
    }
    await _samples.close();
    await _status.close();
  }
}
