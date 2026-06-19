# Todo

Implementation tasks in priority order. Delete lines that are done.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked
- Bluetooth: handle disconnect during recording (NULL samples, reconnecting
  banner, auto-reconnect)
- Interrupted recording recovery: detect incomplete activity on launch, prompt
  user to continue or not. Design idea: on recording start, write a small
  sentinel file (e.g. `recording_in_progress.json`) containing the activity ID,
  original startedAtMs, and device platformId. Delete the file when recording
  ends cleanly. On launch, if the file exists the previous session crashed; use
  its contents to reconnect to the same device and resume appending samples to
  the existing activity row (with tMs offsets relative to the original
  startedAtMs). Avoids relying on durationMs==0 as the crash signal, which is
  fragile.
- Tap to tag a moment or label during recording. Tap moments: Recovery start,
  Recovery end, Round start, Round end, Note, Other.
- Allow zoom when trimming chart, also it kind of is stuck sometimes and lags
  and I can't move the right handle, we should fix that and have some visual
  effect when the handle is being dragged.
- Tap-to-tag button writes a `moment` point marker during recording
- Session shape sparkline (3 block chars stored in activities.sparkline)
- Round detection (automatic effort period segmentation); stored as `round` span
  markers
- Recovery event detection button (Z5 → Z3 drop timing); stored as `recovery`
  span markers
- Moment-label editing on review screen: drag, resize, add, delete
- Span analysis like a recovery span would show HR slope, duration, and other
  metrics.
- Export activity data to a portable file (JSON or CSV, or some other format)
- Import from backup file
- Google Drive backup / restore
- Share individual workout via share sheet

Open questions:

- Measure GPS location and do all the related stats?
