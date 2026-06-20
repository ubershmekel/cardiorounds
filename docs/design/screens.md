# Screens

## Home screen

At the top you see the logo of the app and its name.

### First-run empty state

When the user has never recorded a workout, the home screen shows two hero
options instead of a list:

- **Start recording** — jumps straight to the confirm-record screen
- **Set up your profile** — opens Settings to enter name, max HR, and resting HR

Both options are large, visually prominent cards. The user does not need to fill
in any profile info to start recording.

### Returning user

When past workouts exist, the home screen shows a big "Start recording" button
at the top and a log of past recordings below. Each activity row shows:

▇▆▃ 2025-05-13 · 48 min · 142 avg · 181 max · 6.8k beats

Tapping a past recording opens the activity review screen for that recording.

At the bottom there is a floating nav bar with:

- Home
- Settings
- Record

## Confirm record screen

This screen handles Bluetooth HR device connection before recording starts.

### Layout

Two things sit at the top, above the device list:

- A **sport-type field** (free text, pre-filled with the most recently used
  sport type, with autocomplete from past sport types). The user can change it
  here; it can also be changed on the activity review screen after the workout.
- A single primary **Start** button. It is disabled while no device is selected
  and becomes active the moment one is. There is no per-device Start button.

The device list below is a **selector**, not a launcher: tapping a row picks
that device; the Start button at the top commits to it.

### Device list

Shows a scrollable list of nearby Bluetooth HR devices found by continuous
background scanning. Each row shows:

- A **heart icon** — filled for a previously-used device, outline for one never
  seen before. Recognition is conveyed by the icon shape and a **"Last used"**
  label, not by color. Zone colors are reserved for actual heart rate and are
  never used here.
- **Device name**
- **Signal-strength bars** (1–4 bars; ≥ −60 dBm = 4, ≥ −70 = 3, ≥ −80 = 2, < −80
  = 1), shown when the row is not selected.

When the "Fake heart-rate device" toggle is on (Advanced settings), a
**simulated strap** appears as the first row in this same list and behaves like
any other selectable device.

#### Ordering (stable, never reshuffles)

A list that reorders under your thumb is hard to tap, so order is fixed once and
left alone:

- The list is sorted **once** as it first populates: known devices first, then
  by signal strength.
- After that, **positions are frozen**. Signal changes update the bars in place
  but never reorder a row.
- **Newly discovered devices append to the bottom** in discovery order — even a
  known strap that shows up late lands at the bottom rather than jumping up.
- The **selected device keeps its slot**; selecting it does not move it.

### Selection and live preview

Tapping a row selects it, which immediately connects to that device and streams
live BPM in place of the signal bars — without creating an activity. This lets
the user confirm sensor contact before committing. While a device is selected:

- Scanning pauses; the other (now stale) rows are greyed out.
- Tapping the **selected row again** deselects it, disconnects, and resumes
  scanning.
- Tapping a **different row** switches the selection to that device.

The top **Start** button is enabled as soon as a device is selected — it does
**not** wait for pairing or a first reading. Tapping it reuses the already-open
connection (no reconnect) and hands it straight to the recording screen, which
owns the connecting / reconnecting display. If Start is tapped before the
preview connection finishes, the start is honored as soon as the connection is
ready.

### Auto-selection of a known device

If exactly one device is known from a prior session and it appears in the scan,
it is **auto-selected** (its live preview starts) — but recording never starts
on its own. There is no countdown and no deadline; the user taps Start when
ready. Auto-selection happens at most once per screen visit and not after the
user has interacted with the list.

### States shown on this screen

- Scanning — spinner next to section header; refresh button when idle
- Selected / previewing — live BPM on the selected row, other rows greyed out
- Connecting preview — "Connecting…" on the selected row
- Starting — full-screen spinner while the activity is created; controls
  disabled
- Error — red message above the list; scanning resumes
- No devices found — instructional text with retry button
- Bluetooth off — handled at the OS level before this screen is reached

You can go back or cancel from any state.

## Interrupted recording recovery

If the app detects an activity that was started but never ended (e.g. after a
crash), it shows a prompt on launch:

> "It looks like your last recording was interrupted. Continue where you left
> off?"

**Continue** — opens the recording screen for that activity, allowing the user
to stop, review, and save or discard as usual.

**Discard** — deletes the incomplete activity.

## Recording screen

Shown while a workout is in progress. Lives at `/recording/:activityId`.

### States

TBD we might have a "recording paused" state, or a state where a label is
started and not yet ended (for exmample, if the user marks a recovery started or
a round started and has not yet ended that label).

### Display

- Live current heart rate (large, prominent); `--` on signal loss
- Elapsed time (ticking)
- A live HR chart (see Chart spec below)
- Min / avg / max heart rate
- Time-in-zone breakdown (when both max and resting HR are set in Settings)
- A stop button (requires confirmation modal); replaced by a "Recording
  recovery…" label during the recovery period
- A reconnecting banner when BT connection is lost
- Sport type — pre-filled from the picker, editable inline on review

When recording starts, the app writes a diagnostic log line with the app build
label, phone model identifier, iOS version, and platform so support logs can be
correlated with device/OS-specific behavior and app releases.

Future live-action buttons (tap-to-mark a moment, label a round, label a
recovery period) will live here too. See Milestone 3 in `todo.md`.

Zone colors on the chart are active only when both max and resting HR are set.
Otherwise the chart uses a neutral single-color line.

### Bluetooth disconnect during recording

If the BT device disconnects mid-recording:

- Display `--` for current BPM
- Show a persistent banner: "Reconnecting to [Device Name]…"
- Continue recording; write NULL `hr` samples to preserve the time gap
- When reconnection succeeds, hide the banner and resume normal display
- If reconnection fails after a reasonable time, keep the banner; do not stop
  recording unless the user taps stop

The gap in HR data is visible in the chart as a break in the line.

## Activity review screen

Shown for any completed (or interrupted) activity. Read-only by default. Lives
at `/activity/:activityId`.

### Display

- Date, total duration, and sport type in a metadata row
- A pan + pinch-to-zoom HR chart (see Chart spec below)
- Min / avg / max heart rate
- Time-in-zone breakdown — computed over the `workout` span marker window when
  one is set; otherwise over the full duration
- Activity name (editable inline)
- In-depth analysis and advice (Milestone 3+)

### Marker editing

Tap the "edit" icon in the app bar to enter edit mode. While editing, the chart
shows draggable handles on the `workout` span marker so the user can adjust the
workout boundaries — useful when recording started early (e.g. walking to the
mat) or ended late.

Human `round` markers appear as spans on the chart. The user can drag, resize,
add, or delete them here.

Analysis-generated `round` markers are shown in a muted style. Editing one
converts it to a human marker.

## Chart spec

- **X axis**: elapsed time from recording start
- **Y axis**: BPM, auto-scaled with a small margin above the session max; the
  minimum value is a ten-rounded number under the minimum HR (like 40)
- **Grid**: subtle horizontal guide lines every 10 bpm, with sparse Y-axis
  labels so the line remains visually dominant
- **Line**: continuous, colored by zone (see zones.md); breaks at NULL HR gaps
- **Tap inspection**: tapping the plot shows a vertical line at that timestamp
  and a top label with the interpolated BPM value at that x position; tapping
  the label dismisses the line and label
- **Markers**: vertical tick lines at each marker's timestamp; `round` ticks
  span their full duration; `workout` marker boundaries dim the chart outside
  the effort period
- **Recording / Recording recovery behavior**: the chart scrolls so the latest
  reading is always visible on the right; shows the last ~5 minutes by default
  with pinch-to-zoom to choose how much time back is visible. The recording
  chart keeps the newest reading pinned to the right and does not pan.
- **Review behavior**: an untrimmed activity shows the full session at once.
  When a `workout` trim exists, the chart defaults to the trimmed span as its
  visible bounds; pinch-to-zoom and pan can reveal inactive sections, which are
  greyed out outside the `workout` marker boundaries.

## Settings screen

Show:

- Athlete name
- Max Heart Rate (with a "?" button linking to measurement guidance; see
  zones.md)
- Resting Heart Rate (with a "?" button)
- App version, build date, and commit hash when supplied by the build pipeline

Zone colors are unlocked once max HR is set. The settings screen makes this
visible with a short prompt when max HR is absent.
