import 'dart:io';

import 'package:cardio/core/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_logger_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File logFile(String name) {
      return File('${tempDir.path}${Platform.pathSeparator}$name');
    }

    test('retains only the configured number of in-memory lines', () {
      final logger = AppLogger.forTesting(
        config: const AppLoggerConfig(maxMemoryBufferLines: 3),
        persistToFile: false,
        printer: (_) {},
      );

      for (var i = 0; i < 5; i++) {
        logger.log('Test', 'message $i');
      }

      expect(logger.bufferedLines, hasLength(3));
      expect(logger.bufferedLines.first, contains('message 2'));
      expect(logger.bufferedLines.last, contains('message 4'));
    });

    test('serializes writes and trims oversized log files', () async {
      final file = logFile('app.log');
      final logger = AppLogger.forTesting(
        config: const AppLoggerConfig(
          maxFileBytes: 220,
          retainedFileLinesAfterTrim: 5,
        ),
        fileResolver: () async => file,
        printer: (_) {},
      );

      for (var i = 0; i < 12; i++) {
        logger.log('File', 'entry $i ${'x' * 30}');
      }
      await logger.flush();

      final lines = await file.readAsLines();
      expect(lines, isNotEmpty);
      expect(lines.length, lessThanOrEqualTo(5));
      expect(lines.join('\n'), isNot(contains('entry 0 ')));
      expect(lines.last, contains('entry 11 '));
      expect(await file.length(), lessThanOrEqualTo(220));
    });

    test('trims an existing oversized file when resolving it', () async {
      final file = logFile('existing.log');
      await file.writeAsString(
        List.generate(20, (i) => 'old $i ${'x' * 20}').join('\n'),
      );
      final logger = AppLogger.forTesting(
        config: const AppLoggerConfig(
          maxFileBytes: 120,
          retainedFileLinesAfterTrim: 4,
        ),
        fileResolver: () async => file,
        printer: (_) {},
      );

      final resolvedFile = await logger.resolveLogFile();

      expect(resolvedFile?.path, file.path);
      final lines = await file.readAsLines();
      expect(lines, isNotEmpty);
      expect(lines.length, lessThanOrEqualTo(4));
      expect(lines.last, contains('old 19 '));
      expect(await file.length(), lessThanOrEqualTo(120));
    });
  });
}
