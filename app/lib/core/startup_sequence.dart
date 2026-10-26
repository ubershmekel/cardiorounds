import 'dart:async';

/// The pre-`runApp` startup flow: load what the app needs, then show either the
/// app or the startup failure screen. Every run ends in exactly one of the two,
/// so a failed launch can never leave the native splash up.
///
/// Single-flight: a [start] while one is already running returns the running
/// attempt instead of starting another. Without that, repeated "Try again"
/// taps race each other, and a stale attempt's failure could replace an app a
/// newer attempt already showed.
class StartupSequence<T> {
  StartupSequence({
    required this.load,
    required this.showApp,
    required this.showFailure,
  });

  final Future<T> Function() load;
  final void Function(T loaded) showApp;

  /// `retry` re-enters [start]; the failure screen wires it to "Try again".
  final void Function(
    Object error,
    StackTrace stackTrace,
    Future<void> Function() retry,
  )
  showFailure;

  Future<void>? _inFlight;

  Future<void> start() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<void> _run() async {
    final T loaded;
    try {
      loaded = await load();
    } catch (e, st) {
      showFailure(e, st, start);
      return;
    }
    showApp(loaded);
  }
}
