import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'app_logger.dart';

/// Tag for every startup checkpoint, so one grep pulls a launch's timeline.
const String kStartupLogTag = 'Startup';

/// Upper bound for a single platform-channel call made before `runApp`. These
/// calls normally answer in milliseconds; a handler that never replies would
/// otherwise keep the native splash up forever.
const Duration kStartupPlatformCallTimeout = Duration(seconds: 5);

/// A step running longer than this logs a "still waiting" line, so a hang that
/// ends in a force-close still names the step it was stuck in.
const Duration kStartupSlowStepThreshold = Duration(seconds: 2);

/// If no frame has been rasterized this long after `main()`, log it together
/// with the lifecycle state (a background launch legitimately draws nothing).
const Duration kFirstFrameWatchdogDelay = Duration(seconds: 10);

typedef StartupLog = void Function(String tag, String message);

/// Measures time since `main()` started, for the elapsed column in checkpoints.
final Stopwatch _sinceMain = Stopwatch();

/// Call first thing in `main()`.
void startStartupClock() => _sinceMain.start();

String _elapsed() => '+${_sinceMain.elapsedMilliseconds}ms';

/// Logs a single named checkpoint with time since `main()`.
void startupCheckpoint(String message, {StartupLog log = appLog}) {
  log(kStartupLogTag, '${_elapsed()} $message');
}

/// Runs one startup step with start/done/failed checkpoints around it.
///
/// With [timeout], a step that hasn't finished in time throws a
/// [TimeoutException] (the underlying future is abandoned, not cancelled).
/// Errors are logged and rethrown — the caller decides whether the step is
/// optional.
Future<T> startupStep<T>(
  String name,
  Future<T> Function() body, {
  Duration? timeout,
  Duration slowThreshold = kStartupSlowStepThreshold,
  StartupLog log = appLog,
}) async {
  final watch = Stopwatch()..start();
  startupCheckpoint('$name: start', log: log);
  final slowTimer = Timer(slowThreshold, () {
    startupCheckpoint(
      '$name: still waiting after ${watch.elapsedMilliseconds}ms',
      log: log,
    );
  });
  try {
    final future = body();
    final result = await (timeout == null ? future : future.timeout(timeout));
    startupCheckpoint(
      '$name: done in ${watch.elapsedMilliseconds}ms',
      log: log,
    );
    return result;
  } catch (e) {
    startupCheckpoint(
      '$name: failed after ${watch.elapsedMilliseconds}ms: $e',
      log: log,
    );
    rethrow;
  } finally {
    slowTimer.cancel();
  }
}

/// Routes uncaught framework and async errors into the persistent log.
///
/// Without this, an exception thrown in `main()` before `runApp` only reaches
/// the console, and the launch leaves no trace in exported support logs.
void installStartupErrorLogging() {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    appLog(
      'Error',
      'Flutter error: ${details.exceptionAsString()}\n'
          '${details.stack}',
    );
    previousFlutterOnError?.call(details);
  };
  // Chain rather than replace, so a handler installed earlier (e.g. a crash
  // reporter) still sees the error and decides whether it was handled. With
  // none, report it as handled: it's logged, which is the point here.
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog('Error', 'Uncaught error: $error\n$stack');
    return previousPlatformOnError?.call(error, stack) ?? true;
  };
}

/// Logs when the first frame is rasterized, and warns if it hasn't happened
/// within [kFirstFrameWatchdogDelay].
void watchFirstFrame() {
  var rasterized = false;
  final binding = WidgetsBinding.instance;
  unawaited(
    binding.waitUntilFirstFrameRasterized.then((_) {
      rasterized = true;
      startupCheckpoint('first frame rasterized');
    }),
  );
  Timer(kFirstFrameWatchdogDelay, () {
    if (rasterized) return;
    startupCheckpoint(
      'no first frame yet (lifecycle: ${binding.lifecycleState}, '
      'scheduler: ${SchedulerBinding.instance.schedulerPhase})',
    );
  });
}
