const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0',
);
const String kAppBuildDate = String.fromEnvironment('APP_BUILD_DATE');
const String kAppBuildHash = String.fromEnvironment('APP_BUILD_HASH');

String appBuildLabel({
  String version = kAppVersion,
  String buildDate = kAppBuildDate,
  String buildHash = kAppBuildHash,
}) {
  final details = [
    if (buildDate.isNotEmpty) 'built $buildDate',
    if (buildHash.isNotEmpty) buildHash,
  ];
  if (details.isEmpty) return version;
  return '$version (${details.join(', ')})';
}
