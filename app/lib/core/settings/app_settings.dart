import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The loaded SharedPreferences instance, backing the app's persisted
/// settings. Overridden with a real instance in main() so the rest of the app
/// can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider not initialized'),
);

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
