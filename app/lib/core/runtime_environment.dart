import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'build_info.dart';

typedef NativeDeviceInfoResolver = Future<Map<String, Object?>?> Function();

class RuntimeEnvironmentInfo {
  const RuntimeEnvironmentInfo({
    required this.platform,
    required this.appVersion,
    this.osName,
    this.osVersion,
    this.deviceModel,
    this.deviceModelIdentifier,
  });

  final String platform;
  final String appVersion;
  final String? osName;
  final String? osVersion;
  final String? deviceModel;
  final String? deviceModelIdentifier;

  String get activityLogLabel {
    final os = _joinNonEmpty([osName, osVersion], separator: ' ');
    final device = _joinNonEmpty([
      deviceModel,
      if (deviceModelIdentifier != null) '($deviceModelIdentifier)',
    ], separator: ' ');
    return [
      'app $appVersion',
      if (device != null) 'device $device',
      if (os != null) 'OS $os',
      'platform $platform',
    ].join('; ');
  }
}

Future<RuntimeEnvironmentInfo> runtimeEnvironmentInfo({
  NativeDeviceInfoResolver? nativeDeviceInfoResolver,
  String appVersion = kAppVersion,
  String buildDate = kAppBuildDate,
  String buildHash = kAppBuildHash,
  TargetPlatform? platformOverride,
}) async {
  final nativeInfo = kIsWeb
      ? null
      : await _tryReadNativeInfo(nativeDeviceInfoResolver ?? _readNativeInfo);
  final platform =
      _stringValue(nativeInfo?['platform']) ??
      (platformOverride ?? defaultTargetPlatform).name;
  return RuntimeEnvironmentInfo(
    platform: platform,
    appVersion: appBuildLabel(
      version: appVersion,
      buildDate: buildDate,
      buildHash: buildHash,
    ),
    osName: _stringValue(nativeInfo?['osName']),
    osVersion: _stringValue(nativeInfo?['osVersion']),
    deviceModel: _stringValue(nativeInfo?['deviceModel']),
    deviceModelIdentifier: _stringValue(nativeInfo?['deviceModelIdentifier']),
  );
}

Future<Map<String, Object?>?> _tryReadNativeInfo(
  NativeDeviceInfoResolver resolver,
) async {
  try {
    return await resolver();
  } catch (_) {
    return null;
  }
}

Future<Map<String, Object?>?> _readNativeInfo() async {
  final plugin = DeviceInfoPlugin();
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      final info = await plugin.iosInfo;
      return {
        'platform': 'ios',
        'osName': info.systemName,
        'osVersion': info.systemVersion,
        'deviceModel': info.model,
        'deviceModelIdentifier': info.utsname.machine,
      };
    case TargetPlatform.android:
      final info = await plugin.androidInfo;
      return {
        'platform': 'android',
        'osName': 'Android',
        'osVersion': info.version.release,
        'deviceModel': info.model,
        'deviceModelIdentifier': info.device,
      };
    default:
      return null;
  }
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _joinNonEmpty(List<String?> values, {required String separator}) {
  final nonEmpty = [for (final value in values) ?_stringValue(value)];
  if (nonEmpty.isEmpty) return null;
  return nonEmpty.join(separator);
}
