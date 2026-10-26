import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The loaded SharedPreferences instance, backing the app's persisted
/// settings. Overridden with a real instance in main() so the rest of the app
/// can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider not initialized'),
);

/// Loads preferences for startup, failing after [timeout] rather than hanging.
///
/// `SharedPreferences.getInstance` caches its in-flight request and clears it
/// only on error, never on our timeout — so without the reset, "Try again"
/// would just re-await the original hung request and never ask the platform
/// again. The reset also clears the plugin's prefix and allow-list, which this
/// app never sets.
Future<SharedPreferences> loadStartupPreferences({
  required Duration timeout,
}) async {
  try {
    return await SharedPreferences.getInstance().timeout(timeout);
  } on TimeoutException {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    rethrow;
  }
}

const _fakeHrDeviceKey = 'fakeHrDeviceEnabled';

/// Whether the simulated heart-rate strap is offered on the record screen.
/// Defaults to on in debug/web builds; testers can toggle it either way from
/// Advanced settings, and the stored choice wins over the build-type default.
class FakeHrDeviceNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(sharedPreferencesProvider).getBool(_fakeHrDeviceKey) ??
        (kIsWeb || kDebugMode);
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_fakeHrDeviceKey, enabled);
  }
}

final fakeHrDeviceEnabledProvider =
    NotifierProvider<FakeHrDeviceNotifier, bool>(FakeHrDeviceNotifier.new);

const _multiDeviceRecordingKey = 'multiDeviceRecordingEnabled';

/// Whether the record picker allows selecting more than one HR strap for a
/// single session. Off by default; opt in from Advanced settings.
class MultiDeviceRecordingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(sharedPreferencesProvider)
            .getBool(_multiDeviceRecordingKey) ??
        false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_multiDeviceRecordingKey, enabled);
  }
}

final multiDeviceRecordingEnabledProvider =
    NotifierProvider<MultiDeviceRecordingNotifier, bool>(
      MultiDeviceRecordingNotifier.new,
    );
