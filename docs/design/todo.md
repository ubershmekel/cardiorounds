# Todo

Implementation tasks in priority order. Check off when merged to main.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked
- Bluetooth: auto-connect to last known device on subsequent sessions (5-second
  countdown + spinner before falling back to picker)
- Bluetooth: handle disconnect during recording (NULL samples, reconnecting
  banner, auto-reconnect)
- Interrupted recording recovery: detect incomplete activity on launch, prompt
  user to continue or not
- Recording screen: sport-type field pre-filled from last session
- One-minute recovery capture after Stop, before navigating to review

---

## Milestone 2 — Zones + Activity Details

- Define zone thresholds from max HR and resting HR (Karvonen / HRR method)
- Color the HR chart line by zone (gray / blue / green / orange / pink)
- Zone time breakdown on workout review screen
- Activity name and note fields: editable on review screen and activity list
- Sport type: pre-fill from last session, auto-suggest from history

---

## Milestone 3 — Analysis + History

- Tap-to-tag button writes a `moment` point marker during recording
- Load score calculation (extra beats above resting HR, trimmed to `workout`
  window when present)
- Session shape sparkline (3 block chars stored in activities.sparkline)
- Recovery event detection (Z5 → Z3 drop timing); stored as `recovery` span
  markers
- Historical activity list with sparkline, load, duration
- Round detection (automatic effort period segmentation); stored as `round` span
  markers
- Round editing on review screen: drag, resize, add, delete

---

## Milestone 4 — Backup + Export

- Export activity data to a portable file (JSON or CSV)
- Import from backup file
- Google Drive backup / restore
- Share individual workout via share sheet
