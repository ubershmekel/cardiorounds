import 'dart:async';
import 'dart:math';

import 'hr_source.dart';

class FakeHeartRateSource implements HeartRateSource {
  FakeHeartRateSource({
    this.deviceName = 'Synthetic strap',
    this.centerBpm = 132,
    this.amplitude = 14,
    this.periodSeconds = 30,
    this.tickInterval = const Duration(seconds: 1),
    Random? random,
  }) : _random = random ?? Random() {
    _timer = Timer.periodic(tickInterval, _tick);
  }

  @override
  final String deviceName;
  final int centerBpm;
  final int amplitude;
  final double periodSeconds;
  final Duration tickInterval;
  final Random _random;

  final _controller = StreamController<HrSample>.broadcast();
  final _statusController = StreamController<HrSourceStatus>.broadcast();
  late final Timer _timer;
  final DateTime _start = DateTime.now();

  @override
  String? get devicePlatformId => null;

  @override
  Stream<HrSample> get samples => _controller.stream;

  @override
  Stream<HrSourceStatus> get status => _statusController.stream;

  void _tick(Timer _) {
    final now = DateTime.now();
    final elapsedSec = now.difference(_start).inMilliseconds / 1000.0;
    final wave = sin(2 * pi * elapsedSec / periodSeconds);
    final jitter = _random.nextInt(5) - 2;
    final bpm = (centerBpm + wave * amplitude + jitter).round();
    _controller.add(HrSample(bpm: bpm, at: now));
  }

  @override
  Future<void> dispose() async {
    _timer.cancel();
    _statusController.add(
      HrSourceStatus(kind: HrSourceStatusKind.disposed, at: DateTime.now()),
    );
    await _controller.close();
    await _statusController.close();
  }
}
