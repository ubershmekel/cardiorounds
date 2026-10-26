import 'dart:async';

import 'package:cardio/core/startup_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;
  void log(String tag, String message) => lines.add('[$tag] $message');

  setUp(() => lines = []);

  test('logs start and done around a successful step', () async {
    final result = await startupStep('Prefs', () async => 42, log: log);

    expect(result, 42);
    expect(lines, hasLength(2));
    expect(lines[0], matches(r'^\[Startup\] \+\d+ms Prefs: start$'));
    expect(lines[1], matches(r'^\[Startup\] \+\d+ms Prefs: done in \d+ms$'));
  });

  test('logs and rethrows a failing step', () async {
    await expectLater(
      startupStep('Prefs', () async => throw StateError('no plugin'), log: log),
      throwsStateError,
    );

    expect(lines.last, contains('Prefs: failed after'));
    expect(lines.last, contains('no plugin'));
  });

  test('times out a step that never completes', () async {
    await expectLater(
      startupStep(
        'Hang',
        () => Completer<void>().future,
        timeout: const Duration(milliseconds: 200),
        slowThreshold: const Duration(milliseconds: 50),
        log: log,
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(lines.any((l) => l.contains('Hang: still waiting after')), isTrue);
    expect(lines.last, contains('Hang: failed after'));
  });

  test('a fast step does not log still waiting', () async {
    await startupStep(
      'Fast',
      () async {},
      slowThreshold: const Duration(milliseconds: 50),
      log: log,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(lines.where((l) => l.contains('still waiting')), isEmpty);
    expect(lines.last, contains('Fast: done in'));
  });
}
