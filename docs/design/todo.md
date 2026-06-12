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
- One-minute recovery capture after Stop, before navigating to review

---

## Milestone 2 — Analysis + History

- Tap-to-tag button writes a `moment` point marker during recording
- Session shape sparkline (3 block chars stored in activities.sparkline)
- Recovery event detection (Z5 → Z3 drop timing); stored as `recovery` span
  markers
- Historical activity list with sparkline, load, duration
- Round detection (automatic effort period segmentation); stored as `round` span
  markers
- Round editing on review screen: drag, resize, add, delete

---

## Milestone 3 — Backup + Export

- Export activity data to a portable file (JSON or CSV)
- Import from backup file
- Google Drive backup / restore
- Share individual workout via share sheet
