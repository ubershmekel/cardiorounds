import 'package:cardio/core/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefsValues) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  group('multiDeviceRecordingEnabled', () {
    test('defaults off and persists the chosen value', () async {
      final container = await _container({});
      addTearDown(container.dispose);

      expect(container.read(multiDeviceRecordingEnabledProvider), isFalse);

      await container
          .read(multiDeviceRecordingEnabledProvider.notifier)
          .set(true);

      expect(container.read(multiDeviceRecordingEnabledProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('multiDeviceRecordingEnabled'), isTrue);
    });

    test('reads the stored value on build', () async {
      final container = await _container({'multiDeviceRecordingEnabled': true});
      addTearDown(container.dispose);

      expect(container.read(multiDeviceRecordingEnabledProvider), isTrue);
    });
  });
}
