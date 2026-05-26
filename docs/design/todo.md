# Todo

Implementation tasks in priority order. Check off when merged to main.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked; iOS: background modes as required
- Bluetooth: device picker (scan + list nearby HR devices, save chosen device)
- Bluetooth: auto-connect to last known device on subsequent sessions (5-second
  countdown + spinner before falling back to picker)
- Bluetooth: handle disconnect during recording (NULL samples, reconnecting
  banner, auto-reconnect)
- Live HR reading from BT device, persisted as samples in real time
- Interrupted recording recovery: detect incomplete activity on launch, prompt
  user to continue or discard
- Recording screen: display current BPM (`--` on signal loss), elapsed time,
  min/avg/max
- Recording screen: sport-type field (free text, pre-filled from last session)
- Stop recording flow with confirmation modal; one-minute recovery capture
  before navigating to review
- Recording screen: live HR chart (time on X, BPM on Y) with neutral color
  (zones unlocked only after max HR is set in Settings)
- Workout review screen: full HR chart; `workout` span marker draggable on
  chart
- Home screen: list of past activities with basic summary row; first-run empty
  state with hero "Start recording" and "Set up profile" options
- Settings screen: athlete name, max HR, resting HR, app version

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
- Round detection (automatic effort period segmentation); stored as `round`
  span markers
- Round editing on review screen: drag, resize, add, delete

---

## Milestone 4 — Backup + Export

- Export activity data to a portable file (JSON or CSV)
- Import from backup file
- Google Drive backup / restore
- Share individual workout via share sheet
