import 'dart:async';

import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/db/providers.dart';
import 'package:cardio/core/hr/hr_source.dart';
import 'package:cardio/features/recording/recording_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A heart-rate source the test drives directly. No platform id, so the
/// controller skips writing a crash sentinel (no file I/O in unit tests).
class _FakeSource implements HeartRateSource {
  _FakeSource(this.deviceName);

  @override
  final String deviceName;
  @override
  String? get devicePlatformId => null;

  final _samples = StreamController<HrSample>.broadcast();
  final _status = StreamController<HrSourceStatus>.broadcast();

  @override
  Stream<HrSample> get samples => _samples.stream;
  @override
  Stream<HrSourceStatus> get status => _status.stream;

  void emit(int bpm) => _samples.add(HrSample(bpm: bpm, at: DateTime.now()));

  @override
  Future<void> dispose() async {
    await _samples.close();
    await _status.close();
  }
}

void main() {
  // Initialize the binding so the Live Activity / sentinel method-channel calls
  // throw the caught MissingPluginException instead of an uninitialized error.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records each source into its own HR set', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final athlete = await db.ensureDefaultAthlete();
    final started = await db.startActivityWithDevices(
      athleteId: athlete.id,
      startedAtMs: 0,
      deviceIds: [null, null],
    );

    final a = _FakeSource('Strap A');
    final b = _FakeSource('Strap B');
    final controller = RecordingController(
      db: db,
      sources: [
        RecordingSource(source: a, setId: started.hrSetIds[0]),
        RecordingSource(source: b, setId: started.hrSetIds[1]),
      ],
      activityId: started.activityId,
    );

    // Two live device states are tracked.
    expect(controller.state.devices.map((d) => d.deviceName), [
      'Strap A',
      'Strap B',
    ]);

    a.emit(120);
    b.emit(95);
    // Let the async sample inserts complete.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.devices[0].currentBpm, 120);
    expect(controller.state.devices[1].currentBpm, 95);

    final series = await db.watchHrSeries(started.activityId).first;
    expect(series, hasLength(2));
    expect(series[0].samples.single.hr, 120);
    expect(series[1].samples.single.hr, 95);

    // stop() cancels timers/subscriptions so nothing outlives the test.
    await controller.stop();
  });
}
