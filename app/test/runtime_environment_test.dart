import 'package:cardio/core/runtime_environment.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats native iOS details for activity start logs', () async {
    final info = await runtimeEnvironmentInfo(
      nativeDeviceInfoResolver: () async => {
        'platform': 'ios',
        'osName': 'iOS',
        'osVersion': '18.5',
        'deviceModel': 'iPhone',
        'deviceModelIdentifier': 'iPhone16,2',
      },
      appVersion: '1.2.3',
      buildDate: '2026-06-18T12:34:56Z',
      buildHash: 'abc1234',
    );

    expect(
      info.activityLogLabel,
      'app 1.2.3 (built 2026-06-18T12:34:56Z, abc1234); '
      'device iPhone (iPhone16,2); OS iOS 18.5; platform ios',
    );
  });

  test(
    'falls back to platform and app version when native info is unavailable',
    () async {
      final info = await runtimeEnvironmentInfo(
        nativeDeviceInfoResolver: () async => throw MissingPluginException(),
        appVersion: '1.2.3',
        platformOverride: TargetPlatform.iOS,
      );

      expect(info.activityLogLabel, 'app 1.2.3; platform iOS');
    },
  );
}
