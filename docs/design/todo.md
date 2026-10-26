# Todo

Implementation tasks in priority order. Delete lines that are done.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked
- Tap to tag a moment or label during recording. Tap moments: Recovery start,
  Recovery end, Round start, Round end, Note, Other.
- Tap-to-tag button writes a `moment` point marker during recording
- Moment-label editing on review screen: drag, resize, add, delete
- Round detection (automatic effort period segmentation); stored as `round` span
  markers
- Recovery event detection button (Z5 → Z3 drop timing); stored as `recovery`
  span markers
- Span analysis like a recovery span would show HR slope, duration, and other
  metrics.
- Export activity as TCX via share sheet, with owner picker (see export.md)
- Import activity TCX file (Cardio Rounds or plain third-party TCX)
- Import from backup file (sqlite db)
- Google Drive backup / restore
- Allow logging "distance" and "speed" for treadmill workouts

## Reliability / diagnostics

- Log trim can drop native log lines: `AppLogger._trimIfNeeded` reads the whole
  file then rewrites it, so a line `NativeAppLog` appends in between is lost.
  Trim runs on the first write of each launch once the log exceeds 1 MB — the
  same window as the `[AppNative]` startup checkpoints. Fix by trimming without
  a read-then-rewrite of the live file (e.g. rotate to a new file, or have
  native and Dart share one writer).
- Verify the startup-hang fix on a real iPhone: a normal launch should log
  `didFinishLaunching` → `scene will connect` → `implicit engine initialized` →
  `Launched` → `runApp` → `first frame rasterized`, with no
  `MissingPluginException`. Then catch a BLE background relaunch
  (`state: background`) followed by opening the app.
- Audit third-party iOS plugins for anything that uses
  `UIApplication.shared.delegate` as a `FlutterPluginRegistry` before a scene
  connects — that would recreate and run the launch engine early, bringing the
  splash hang back.

Open questions:

- Measure GPS location and do all the related stats?
