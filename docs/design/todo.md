# Todo

Implementation tasks in priority order. Delete lines that are done.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked
- Bluetooth: handle disconnect during recording (NULL samples, reconnecting
  banner, auto-reconnect)
- Interrupted recording recovery: detect incomplete activity on launch, prompt
  user to continue or not
- Tap to tag a moment or label during recording. Tap moments: Recovery start,
  Recovery end, Round start, Round end, Note, Other.
- Show time when tapping a HR chart not just bpm
- Allow zoom when trimming chart, also it kind of is stuck sometimes and lags
  and I can't move the right handle, we should fix that and have some visual
  effect when the handle is being dragged.
- Tap-to-tag button writes a `moment` point marker during recording
- Session shape sparkline (3 block chars stored in activities.sparkline)
- Historical activity list with sparkline, load, duration
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
