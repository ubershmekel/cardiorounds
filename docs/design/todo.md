# Todo

Implementation tasks in priority order. Check off when merged to main.

---

## Milestone 1 — Recording + Chart (MVP)

- Flutter project scaffold (package name, app name, theme colors, folder
  structure)
- Add dependencies: Drift, Riverpod, flutter_blue_plus (or equivalent BT HR
  plugin)
- Create Drift database with `devices`, `activities`, `samples`, and `markers`
  tables per data-model.md
- Bluetooth: device picker (scan + list nearby HR devices, save chosen device)
- Bluetooth: auto-connect to last known device on subsequent sessions
- Live HR reading from BT device, persisted as samples in real time
- Recording screen: display current BPM, elapsed time, min/avg/max
- Stop recording flow with confirmation modal
- Recording screen: live HR chart (time on X, BPM on Y) with label tick marks
- Workout review screen: full HR chart with draggable workout_start/end markers
- Workout review screen: display and edit round_start markers on the chart
- Home screen: list of past activities with basic summary row

---

## Milestone 2 — Zones + Settings

- Define zone thresholds from max HR (settings screen input)
- Color the HR chart line by zone (gray / blue / green / orange / pink)
- Settings screen: max HR and resting HR entry, app version
- Zone time breakdown on workout review screen

---

## Milestone 3 — Analysis + History

- Tap-to-tag button writes a `moment` human label during recording
- Load score calculation (extra beats above resting HR)
- Session shape fingerprint (▇▆▃ sparkline stored in activities table)
- Recovery event detection (Z5 → Z3 drop timing)
- Historical activity list with sparkline, load, duration
- Round detection (automatic effort period segmentation)
