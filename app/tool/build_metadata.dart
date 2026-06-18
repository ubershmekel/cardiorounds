import 'dart:io';

Directory get _appDir => File(Platform.script.toFilePath()).parent.parent;
File get _pubspec => File.fromUri(_appDir.uri.resolve('pubspec.yaml'));

void main(List<String> args) {
  if (args.length != 1) {
    _usage();
  }

  switch (args.single) {
    case 'app-version':
      stdout.writeln(_packageVersion());
      return;
    case 'build-hash':
      stdout.writeln(_gitShortHash());
      return;
    case 'build-date':
      stdout.writeln(_utcBuildDate());
      return;
    case 'dart-defines':
      stdout.writeln(_dartDefines());
      return;
    case 'bump-version':
      _bumpVersion();
      return;
    default:
      _usage();
  }
}

void _usage() {
  stderr.writeln(
    'Usage: dart tool/build_metadata.dart '
    '<app-version|build-hash|build-date|dart-defines|bump-version>',
  );
  exitCode = 64;
  throw const _Exit();
}

String _packageVersion() {
  final version = _pubspecVersion();
  return version.split('+').first;
}

String _pubspecVersion() {
  final match = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(_pubspec.readAsStringSync());
  if (match == null) {
    stderr.writeln('Could not find version in pubspec.yaml');
    exit(1);
  }
  return match.group(1)!;
}

String _gitShortHash() {
  final result = Process.runSync('git', [
    'rev-parse',
    '--short',
    'HEAD',
  ], workingDirectory: _appDir.path);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  return result.stdout.toString().trim();
}

String _utcBuildDate() {
  final now = DateTime.now().toUtc();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${now.year.toString().padLeft(4, '0')}-'
      '${twoDigits(now.month)}-'
      '${twoDigits(now.day)}T'
      '${twoDigits(now.hour)}:'
      '${twoDigits(now.minute)}:'
      '${twoDigits(now.second)}Z';
}

String _dartDefines() {
  return [
    '--dart-define=APP_VERSION=${_packageVersion()}',
    '--dart-define=APP_BUILD_HASH=${_gitShortHash()}',
    '--dart-define=APP_BUILD_DATE=${_utcBuildDate()}',
  ].join(' ');
}

void _bumpVersion() {
  final contents = _pubspec.readAsStringSync();
  final match = RegExp(
    r'^version:\s*([^\s+#]+)(?:\+(\d+))?',
    multiLine: true,
  ).firstMatch(contents);
  if (match == null) {
    stderr.writeln('Could not find version in pubspec.yaml');
    exit(1);
  }

  final name = match.group(1)!;
  final currentBuild = int.tryParse(match.group(2) ?? '0');
  if (currentBuild == null) {
    stderr.writeln('Could not parse build number in pubspec.yaml');
    exit(1);
  }

  final nextVersion = '$name+${currentBuild + 1}';
  _pubspec.writeAsStringSync(
    contents.replaceRange(match.start, match.end, 'version: $nextVersion'),
  );
  stdout.writeln('Bumped to $nextVersion');
}

class _Exit implements Exception {
  const _Exit();
}
