import 'dart:async';

import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/db/providers.dart';
import 'package:cardio/core/hr/hr_providers.dart';
import 'package:cardio/core/hr/hr_scanner.dart';
import 'package:cardio/core/hr/hr_source.dart';
import 'package:cardio/core/settings/app_settings.dart';
import 'package:cardio/features/recording/confirm_record_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scanner whose results stream the test drives directly.
class FakeHrScanner implements HrScanner {
  final _controller = StreamController<List<ScannedDevice>>.broadcast();
  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<List<ScannedDevice>> get results => _controller.stream;

  @override
  Future<void> start({Duration timeout = const Duration(seconds: 30)}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void emit(List<ScannedDevice> devices) => _controller.add(devices);
}

/// Heart-rate source the test can feed samples to and inspect.
class FakeSource implements HeartRateSource {
  FakeSource(this.deviceName, this.devicePlatformId);

  @override
  final String deviceName;
  @override
  final String? devicePlatformId;

  final _samples = StreamController<HrSample>.broadcast();
  final _status = StreamController<HrSourceStatus>.broadcast();
  bool disposed = false;

  @override
  Stream<HrSample> get samples => _samples.stream;

  @override
  Stream<HrSourceStatus> get status => _status.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _samples.close();
    await _status.close();
  }

  void emitBpm(int bpm) =>
      _samples.add(HrSample(bpm: bpm, at: DateTime.now()));
}

/// Database that fails when starting an activity, to exercise the
/// commit-failure recovery path.
class FailStartActivityDb extends AppDatabase {
  FailStartActivityDb() : super.forTesting(NativeDatabase.memory());

  @override
  Future<int> startActivity({
    required int athleteId,
    required int startedAtMs,
    String? sportType,
  }) async {
    throw Exception('boom');
  }
}

ScannedDevice _device(String id, {int rssi = -60}) =>
    ScannedDevice(platformId: id, name: id, rssi: rssi);

void main() {
  late AppDatabase db;
  late FakeHrScanner scanner;
  late ProviderContainer container;
  // Connector hook the tests can swap per case.
  late Future<HeartRateSource> Function(String id, String name) connect;

  Future<void> setUpContainer({
    AppDatabase? database,
    bool fakeStrap = false,
  }) async {
    SharedPreferences.setMockInitialValues({'fakeHrDeviceEnabled': fakeStrap});
    final prefs = await SharedPreferences.getInstance();
    db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
    scanner = FakeHrScanner();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        hrScannerFactoryProvider.overrideWithValue(() => scanner),
        hrConnectorProvider.overrideWithValue((id, name) => connect(id, name)),
      ],
    );
  }

  tearDown(() async {
    // The screen transfers source ownership on Start; dispose any handed-off
    // source so its stream/timers don't outlive the test.
    await container.read(pendingHrSourceProvider)?.dispose();
    container.dispose();
    // The DB is created here and injected via overrideWithValue, so the
    // provider's onDispose never runs — close it explicitly to avoid drift's
    // "created multiple times" warning leaking across tests.
    await db.close();
  });

  // Minimal app with a recording placeholder so context.go() has a target.
  Widget buildApp() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ConfirmRecordScreen()),
        GoRoute(
          path: '/record/recording/:activityId',
          builder: (_, state) =>
              Text('recording-${state.pathParameters['activityId']}'),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // Pump a few short frames to flush async init / futures without hanging on
  // the screen's periodic re-scan timer (which never settles).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  // The screen awaits StreamSubscription.cancel()/StreamController.close() in
  // its select/deselect/start flows; those futures only resolve in real async,
  // not under tester.pump's fake clock. So drive taps through runAsync, then
  // pump to rebuild the UI and finish any route transition.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Unmount the screen so its timers/subscriptions are cancelled before the
  // test ends.
  Future<void> teardownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('select connects, previews BPM, and Start hands off the source', (
    tester,
  ) async {
    await setUpContainer();
    late FakeSource connected;
    connect = (id, name) async => connected = FakeSource(name, id);

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('Strap')]);
    await settle(tester);

    // Start is disabled until a device is selected.
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start')).onPressed,
      isNull,
    );

    await tap(tester, find.text('Strap'));
    connected.emitBpm(72);
    await settle(tester);

    expect(find.text('72 BPM'), findsOneWidget);
    expect(scanner.stopCount, greaterThan(0)); // scanning paused on select
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNotNull);

    await tap(tester, find.widgetWithText(FilledButton, 'Start'));

    expect(find.textContaining('recording-'), findsOneWidget);
    expect(container.read(pendingHrSourceProvider), same(connected));
    expect(container.read(activeRecordingIdProvider), isNotNull);
    expect(connected.disposed, isFalse); // ownership transferred, not disposed
    expect(await db.allDevices(), hasLength(1)); // device remembered
  });

  testWidgets('Start tapped before the connection is ready fires once ready', (
    tester,
  ) async {
    await setUpContainer();
    final completer = Completer<HeartRateSource>();
    connect = (id, name) => completer.future;

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('Strap')]);
    await settle(tester);

    await tap(tester, find.text('Strap'));
    expect(find.text('Connecting…'), findsOneWidget);

    // Start is enabled while connecting and remembers the intent.
    await tap(tester, find.widgetWithText(FilledButton, 'Start'));
    expect(find.textContaining('recording-'), findsNothing); // not yet

    await tester.runAsync(() async {
      completer.complete(FakeSource('Strap', 'Strap'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('recording-'), findsOneWidget);
    expect(container.read(activeRecordingIdProvider), isNotNull);
  });

  testWidgets('Start failure keeps the connection and stays retryable', (
    tester,
  ) async {
    await setUpContainer(database: FailStartActivityDb());
    late FakeSource connected;
    connect = (id, name) async => connected = FakeSource(name, id);

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('Strap')]);
    await settle(tester);

    await tap(tester, find.text('Strap'));
    await tap(tester, find.widgetWithText(FilledButton, 'Start'));

    expect(find.textContaining('Could not start'), findsOneWidget);
    expect(connected.disposed, isFalse); // connection preserved
    expect(container.read(pendingHrSourceProvider), isNull);
    // Still selected and not busy, so Start is enabled again.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNotNull,
    );

    await teardownScreen(tester);
  });

  testWidgets('tapping the selected device again deselects and resumes scan', (
    tester,
  ) async {
    await setUpContainer();
    final sources = <FakeSource>[];
    connect = (id, name) async {
      final s = FakeSource(name, id);
      sources.add(s);
      return s;
    };

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('Strap')]);
    await settle(tester);

    await tap(tester, find.text('Strap'));
    final startsAfterSelect = scanner.startCount;

    await tap(tester, find.text('Strap')); // tap again to deselect

    expect(sources.single.disposed, isTrue);
    expect(scanner.startCount, greaterThan(startsAfterSelect)); // resumed
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNull, // nothing selected
    );

    await teardownScreen(tester);
  });

  testWidgets('switching selection disposes the previous preview', (
    tester,
  ) async {
    await setUpContainer();
    final byId = <String, FakeSource>{};
    connect = (id, name) async => byId[id] = FakeSource(name, id);

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('A'), _device('B')]);
    await settle(tester);

    await tap(tester, find.text('A'));
    await tap(tester, find.text('B'));

    expect(byId['A']!.disposed, isTrue);
    expect(byId['B']!.disposed, isFalse);

    await teardownScreen(tester);
  });

  testWidgets('list is sorted known-first then by signal, newcomers append', (
    tester,
  ) async {
    // Two known devices so the lone-known auto-select does not fire.
    await setUpContainer();
    await db.upsertDevice(platformId: 'KnownB', name: 'KnownB');
    await db.upsertDevice(platformId: 'KnownX', name: 'KnownX');

    await tester.pumpWidget(buildApp());
    await settle(tester);
    // First population: a known quiet device plus two louder unknowns.
    scanner.emit([
      _device('U1', rssi: -50),
      _device('U2', rssi: -70),
      _device('KnownB', rssi: -90),
    ]);
    await settle(tester);

    double dy(String name) => tester.getTopLeft(find.text(name)).dy;
    // Known first regardless of signal, then unknowns by descending signal.
    expect(dy('KnownB'), lessThan(dy('U1')));
    expect(dy('U1'), lessThan(dy('U2')));

    // New batch: a new device, and U2 now louder than U1. Order must not
    // reshuffle; NewC appends at the bottom.
    scanner.emit([
      _device('U1', rssi: -80),
      _device('U2', rssi: -40),
      _device('KnownB', rssi: -90),
      _device('NewC', rssi: -30),
    ]);
    await settle(tester);

    expect(dy('KnownB'), lessThan(dy('U1')));
    expect(dy('U1'), lessThan(dy('U2'))); // U2 stayed put despite louder signal
    expect(dy('U2'), lessThan(dy('NewC'))); // appended last

    await teardownScreen(tester);
  });

  testWidgets('lone known device is auto-selected (preview only)', (
    tester,
  ) async {
    await setUpContainer();
    await db.upsertDevice(platformId: 'MyStrap', name: 'MyStrap');
    late FakeSource connected;
    var connectCalls = 0;
    connect = (id, name) async {
      connectCalls++;
      return connected = FakeSource(name, id);
    };

    await tester.pumpWidget(buildApp());
    await settle(tester);
    scanner.emit([_device('MyStrap')]);
    await settle(tester);

    expect(connectCalls, 1); // auto-selected -> preview connected
    expect(find.textContaining('recording-'), findsNothing); // never auto-starts
    expect(container.read(activeRecordingIdProvider), isNull);
    expect(connected.disposed, isFalse);

    await teardownScreen(tester);
  });

  testWidgets('simulated strap appears as a selectable row when enabled', (
    tester,
  ) async {
    await setUpContainer(fakeStrap: true);
    connect = (id, name) async => FakeSource(name, id);

    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('Simulated Bluetooth strap'), findsOneWidget);

    await tap(tester, find.text('Simulated Bluetooth strap'));

    // Selecting it enables Start without any real connection.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNotNull,
    );

    await teardownScreen(tester);
  });
}
