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

A sport-type field is shown at the top (free text, pre-filled with the most
recently used sport type). The user can change it here; it can also be changed
on the activity review screen after the workout.

### Auto-connect (returning user)

If the app has a previously connected device, it immediately begins scanning and
shows a spinner with "Connecting to [Device Name]…" and a countdown. Once
connected, a "Start recording" button appears. The user can tap "Choose a
different device" at any time to open the device picker instead.

If auto-connect does not succeed within 5 seconds, the device picker opens
automatically.

### Device picker (first time or manual)

Shows a scrollable list of nearby Bluetooth HR devices found by scanning. Each
row shows the device name and signal strength. Tapping a device attempts to
connect. On success the device is saved to the `devices` table and the "Start
recording" button appears.

### States shown on this screen

- Scanning / connecting… (spinner + countdown)
- Connected — [Device Name] — ready to start
- No devices found — retry button
- Bluetooth is off — prompt to enable it

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
- **Line**: continuous, colored by zone (see zones.md); breaks at NULL HR gaps
- **Markers**: vertical tick lines at each marker's timestamp; `round` ticks
  span their full duration; `workout` marker boundaries dim the chart outside
  the effort period
- **Recording / Recording recovery behavior**: the chart scrolls so the latest
  reading is always visible on the right; shows the last ~5 minutes by default
  with pinch-to-zoom to see more history
- **Review behavior**: the full session is shown at once, fitting the width;
  pinch-to-zoom to inspect detail

## Settings screen

Show:

- Athlete name
- Max Heart Rate (with a "?" button linking to measurement guidance; see
  zones.md)
- Resting Heart Rate (with a "?" button)
- App version (date of build)

Zone colors are unlocked once max HR is set. The settings screen makes this
visible with a short prompt when max HR is absent.
