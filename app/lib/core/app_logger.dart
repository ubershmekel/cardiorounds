import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const String kAppLogFileName = 'cardio_rounds.log';
const int kAppLogMemoryBufferLines = 2000;
const int kAppLogMaxFileBytes = 1 * 1024 * 1024;
const int kAppLogRetainedFileLinesAfterTrim = 5000;

typedef AppLogFileResolver = Future<File> Function();
typedef AppLogDebugPrinter = void Function(String? message);

class AppLoggerConfig {
  const AppLoggerConfig({
    this.fileName = kAppLogFileName,
    this.maxMemoryBufferLines = kAppLogMemoryBufferLines,
    this.maxFileBytes = kAppLogMaxFileBytes,
    this.retainedFileLinesAfterTrim = kAppLogRetainedFileLinesAfterTrim,
  }) : assert(maxMemoryBufferLines > 0),
       assert(maxFileBytes > 0),
       assert(retainedFileLinesAfterTrim > 0);

  final String fileName;
  final int maxMemoryBufferLines;
  final int maxFileBytes;
  final int retainedFileLinesAfterTrim;
}

class AppLogger {
  AppLogger._({
    AppLoggerConfig config = const AppLoggerConfig(),
    AppLogFileResolver? fileResolver,
    AppLogDebugPrinter? printer,
    bool persistToFile = true,
  }) : _config = config,
       _fileResolver = fileResolver,
       _printer = printer ?? debugPrint,
       _persistToFile = persistToFile;

  @visibleForTesting
  AppLogger.forTesting({
    AppLoggerConfig config = const AppLoggerConfig(),
    AppLogFileResolver? fileResolver,
    AppLogDebugPrinter? printer,
    bool persistToFile = true,
  }) : this._(
         config: config,
         fileResolver: fileResolver,
         printer: printer,
         persistToFile: persistToFile,
       );

  static final AppLogger instance = AppLogger._();

  final List<String> _buffer = [];
  final AppLoggerConfig _config;
  final AppLogFileResolver? _fileResolver;
  final AppLogDebugPrinter _printer;
  final bool _persistToFile;
  File? _logFile;
  Future<void> _writeQueue = Future.value();

  void log(String tag, String message) {
    final entry = '${DateTime.now().toIso8601String()} [$tag] $message';
    _printer(entry);
    _buffer.add(entry);
    if (_buffer.length > _config.maxMemoryBufferLines) {
      _buffer.removeRange(0, _buffer.length - _config.maxMemoryBufferLines);
    }
    if (!kIsWeb && _persistToFile) {
      _writeQueue = _writeQueue.then((_) => _appendToFile(entry));
      unawaited(_writeQueue);
    }
  }

  Future<void> _appendToFile(String entry) async {
    try {
      final file = await _resolveFile();
      await file.writeAsString('$entry\n', mode: FileMode.append, flush: true);
      await _trimIfNeeded(file);
    } catch (_) {}
  }

  Future<File> _resolveFile() async {
    if (_logFile != null) return _logFile!;
    if (_fileResolver != null) {
      final file = await _fileResolver();
      await _trimIfNeeded(file);
      _logFile = file;
      return file;
    }
    final dir = await getApplicationDocumentsDirectory();
    final separator = dir.path.endsWith(Platform.pathSeparator)
        ? ''
        : Platform.pathSeparator;
    final file = File('${dir.path}$separator${_config.fileName}');
    await _trimIfNeeded(file);
    _logFile = file;
    return file;
  }

  Future<void> _trimIfNeeded(File file) async {
    if (!await file.exists()) return;
    if (await file.length() <= _config.maxFileBytes) return;
    // Strip NUL bytes and drop the blank lines they leave behind: a rewrite that
    // was killed before its data flushed can leave a run of NUL bytes (the file
    // keeps its new length, but the blocks read back as zeros), which shows up as
    // a big empty gap in the log. Real entries are never blank, so this is safe.
    final lines = [
      for (final line in await file.readAsLines())
        if (line.replaceAll('\x00', '').trim().isNotEmpty)
          line.replaceAll('\x00', ''),
    ];
    var keep = lines.length > _config.retainedFileLinesAfterTrim
        ? lines.sublist(lines.length - _config.retainedFileLinesAfterTrim)
        : lines;

    while (keep.length > 1 &&
        utf8.encode('${keep.join('\n')}\n').length > _config.maxFileBytes) {
      keep = keep.sublist(1);
    }

    // flush so the truncated rewrite is durable before we return; without it a
    // kill here is exactly what produces the NUL-gap this method also cleans up.
    await file.writeAsString(
      keep.isEmpty ? '' : '${keep.join('\n')}\n',
      flush: true,
    );
  }

  Future<File?> resolveLogFile() async {
    if (kIsWeb || !_persistToFile) return null;
    await _writeQueue;
    return _resolveFile();
  }

  @visibleForTesting
  List<String> get bufferedLines => List.unmodifiable(_buffer);

  @visibleForTesting
  Future<void> flush() => _writeQueue;
}

void appLog(String tag, String message) => AppLogger.instance.log(tag, message);
