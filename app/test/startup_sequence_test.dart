import 'dart:async';

import 'package:cardio/core/startup_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the sequence showed, and hands out each load's completer so a
/// test controls when (and how) every attempt finishes.
class _Harness {
  final loads = <Completer<int>>[];
  final shown = <String>[];
  Future<void> Function()? retry;

  late final sequence = StartupSequence<int>(
    load: () {
      final c = Completer<int>();
      loads.add(c);
      return c.future;
    },
    showApp: (value) => shown.add('app $value'),
    showFailure: (error, _, retry) {
      shown.add('failure $error');
      this.retry = retry;
    },
  );
}

void main() {
  test('shows the app when loading succeeds', () async {
    final h = _Harness();
    final run = h.sequence.start();
    h.loads.single.complete(1);
    await run;

    expect(h.shown, ['app 1']);
  });

  test(
    'failure shows the failure screen; its retry can then succeed',
    () async {
      final h = _Harness();
      final first = h.sequence.start();
      h.loads.single.completeError('timeout');
      await first;
      expect(h.shown, ['failure timeout']);

      final second = h.retry!();
      h.loads.last.complete(7);
      await second;

      expect(h.loads, hasLength(2));
      expect(h.shown, ['failure timeout', 'app 7']);
    },
  );

  test(
    'retry while an attempt is running joins it instead of racing',
    () async {
      final h = _Harness();
      final first = h.sequence.start();
      h.loads.single.completeError('timeout');
      await first;

      final a = h.retry!();
      final b = h.retry!();
      final c = h.retry!();
      expect(h.loads, hasLength(2), reason: 'one new load for three taps');
      h.loads.last.complete(3);
      await Future.wait([a, b, c]);

      expect(h.shown, ['failure timeout', 'app 3']);
    },
  );
}
