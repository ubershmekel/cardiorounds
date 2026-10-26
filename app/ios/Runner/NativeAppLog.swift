import Foundation

/// Appends to the *same* log file the Dart side writes (`cardio_rounds.log` in
/// the app's Documents directory), in the same `<ISO8601> [tag] message` format.
///
/// The point is diagnostic: native log lines carry a timestamp captured at the
/// moment the event fires. If `[BTNative]` lines appear with timestamps that
/// march through a window where the Dart `[Recording]` lines fell silent, that
/// is direct proof the native BLE callbacks ran while iOS had the Flutter engine
/// suspended. If the native lines stop too, that's equally decisive evidence the
/// whole process was frozen.
enum NativeAppLog {
  // Serial queue so concurrent native callers don't interleave bytes. (Writes
  // can still in principle interleave with the Dart logger's writes to the same
  // file, but each side writes one whole line per call, so corruption is rare
  // and this is a diagnostic, not a system of record.)
  private static let queue = DispatchQueue(label: "cardiorounds.nativelog")

  private static let formatter: DateFormatter = {
    let f = DateFormatter()
    // Matches Dart's DateTime.toIso8601String() closely enough to sort/interleave
    // (local time, no zone suffix; milliseconds rather than microseconds).
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  private static let fileURL: URL? = {
    let dirs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return dirs.first?.appendingPathComponent("cardio_rounds.log")
  }()

  /// `sync: true` returns only after the line is handed to the OS, so it
  /// survives the process being killed right after (e.g. a force-close of a
  /// launch that hangs). Use it for rare checkpoints, not per-sample logging.
  static func log(_ tag: String, _ message: String, sync: Bool = false) {
    let line = "\(formatter.string(from: Date())) [\(tag)] \(message)\n"
    if sync {
      queue.sync { append(line) }
    } else {
      queue.async { append(line) }
    }
  }

  private static func append(_ line: String) {
    guard let url = fileURL, let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      handle.seekToEndOfFile()
      handle.write(data)
    } else {
      // File may not exist yet if Dart hasn't logged this launch.
      try? data.write(to: url, options: .atomic)
    }
  }
}
