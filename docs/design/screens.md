# Screens

## Home screen

At the top you see the logo of the app and its name.

When you open the app, you have a big start recording button.

At the bottom there is a floating nav bar with:

- Home
- Settings
- Record

You can also see a log of your past recordings. Each activity shows:

▇▆▃ 2025-05-13 · 48 min · 142 avg · 181 max · 6.8k beats

When you tap a past recording, you go to the workout review screen for that
recording.

## Confirm record screen

This screen handles Bluetooth HR device connection before recording starts.

### Auto-connect (returning user)

If the app has a previously connected device, it immediately begins scanning for
it and shows a "Connecting to [Device Name]…" status. Once connected, a "Start
recording" button appears. The user can still tap "Choose a different device" to
open the device picker instead.

If auto-connect does not succeed within ~10 seconds, the device picker opens
automatically.

### Device picker (first time or manual)

Shows a scrollable list of nearby Bluetooth HR devices found by scanning. Each
row shows the device name and signal strength. Tapping a device attempts to
connect. On success the device is saved to the `devices` table and the "Start
recording" button appears.

### States shown on this screen

- Scanning / connecting…
- Connected — [Device Name] — ready to start
- No devices found — retry button
- Bluetooth is off — prompt to enable it

You can go back or cancel from any state.

## Recording screen

Show:

- The current heart rate (large, prominent)
- A button to stop recording (requires confirmation modal)
- A live HR chart (see Chart spec below)
- Max heart rate so far
- Min heart rate so far
- Average heart rate
- Button to tag a moment (writes a `moment` human marker at the current
  timestamp)

## Chart spec

Applies to both the recording screen and workout review screen.

- **X axis**: elapsed time from recording start
- **Y axis**: BPM, auto-scaled with a small margin above the session max, the
  minimum value is a ten-rounded number under the minimum HR (like 40).
- **Line**: continuous, colored by zone (see zones.md).
- **Markers**: vertical tick lines at each marker's timestamp; `round_start`
  ticks are taller than `moment` ticks; `workout_start` / `workout_end` are
  shown as boundary lines that dim the chart outside the effort period
- **Recording screen behavior**: the chart scrolls so the latest reading is
  always visible on the right; shows the last ~5 minutes by default with a
  pinch-to-zoom to see more history
- **Review screen behavior**: the full session is shown at once, fitting the
  width; pinch-to-zoom to inspect detail

## Workout review screen

If you just finished a workout the app still records recovery for another
minute.

Generally we want the review screen to show the same data as the recording
screen. Plus some more in-depth analysis and advice.

### Marker editing on the review screen

To edit markers, tap the "edit" button on the chart first which will make the
marker ui interactive.

The user can adjust the workout boundaries after the fact by dragging
`workout_start` and `workout_end` markers on the chart. This is useful when
recording started early (e.g. while still walking to the mat) or ended late.

Human `round_start` markers placed during recording appear as vertical tick
marks on the chart. The user can drag, add, or delete them here.

Analysis-generated `round_start` markers are shown in a muted style. Editing one
converts it to a human marker.

## Settings screen

Show:

- Max Heart Rate
- Resting Heart Rate
- App version (date of build)
