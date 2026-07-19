# Screens

## Startup states

While startup work runs, the app shows a centered loading indicator. If startup
fails, show a concise blocking error state with:

- **Couldn't start Cardio Rounds**
- A short support message, not the raw exception or stack trace
- **Download logs** as the primary action
- **Try again** as the secondary action

The full startup error is written to app logs for support export.

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
any other selectable device. With multiple-device recording also on, several
distinct simulated straps (with different heart rates) are offered so the flow
can be tested without hardware.

#### Multiple-device selection

When the "Record from multiple devices" toggle is on (Advanced settings), the
list becomes a **multi-select**: tapping a row toggles it in or out of the
selection instead of replacing the previous pick. Each selected row opens its
own live preview and shows its BPM (see below). Scanning keeps running while
devices are selected, so other rows are not greyed out, and new straps can still
be added. The top **Start** button commits to **all selected devices** and is
enabled once each selected device is either connected or still actively
connecting. With the toggle off, selection is single-device exactly as described
below. See [multi-device-recording.md](multi-device-recording.md).

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
the user confirm sensor contact before committing. While a device is selected
(single-device mode):

- Scanning pauses; the other (now stale) rows are greyed out.
- Tapping the **selected row again** deselects it, disconnects, and resumes
  scanning.
- Tapping a **different row** switches the selection to that device.

In multiple-device mode the same live-preview connection happens per selected
device, but several previews are held at once, scanning keeps running, and
tapping a row toggles only that device (others are unaffected). A device that
fails to connect shows an error on its own row and can be retried. Start moves
every selected device into the recording, including devices that are still
connecting, so a selected device is never silently left out.

In single-device mode, the top **Start** button is enabled as soon as a device
is selected — it does **not** wait for pairing or a first reading. Tapping it
reuses the already-open connection (no reconnect) and hands it straight to the
recording screen, which owns the connecting / reconnecting display. If Start is
tapped before the preview connection finishes, the start is honored as soon as
the connection is ready.

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
- Bluetooth off / no permission / unsupported — an explicit notice replaces the
  device list (e.g. "Bluetooth is off…", "…doesn't have permission to use
  Bluetooth…"), so the user knows why nothing is showing

You can go back or cancel from any state.

## Interrupted recording recovery

If a recording was interrupted (the app crashed or was killed mid-recording), a
sentinel file left behind by the live recording is detected on the next launch
and a prompt is shown:

> "Resume recording? A recording on <device> was interrupted <time> ago. Resume
> it, or save what was already recorded as a finished workout?"

**Resume** — reconnects to the same strap in the background (with a
"Reconnecting…" spinner) and reopens the recording screen, continuing the
original activity's timeline. If the strap can't be reconnected, the prompt is
left for a later retry and a message is shown.

For a multiple-device session the prompt names all devices and resume reconnects
to each **best-effort** — it continues with whichever reconnect, and only fails
if none do. See [multi-device-recording.md](multi-device-recording.md).

**Save as finished** — closes the interrupted activity out as a completed
workout (duration set from the primary stream's last recorded sample). The data
is kept, not deleted; the user can review or delete it from history like any
other workout.

The samples recorded before the interruption are never lost — they are written
to the database as they arrive, so recovery only decides whether to keep
recording or finalize what exists. Not offered on web (no local file storage).

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
- Exact live zone stat (for example `Z2.5`) when both max and resting HR are set
  in Settings, shown beside min / avg / max; tapping toggles the stat to HR
  Load, where resting HR is 0% and max HR is 100%, and tapping again returns to
  exact zone
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

### Multiple devices

When more than one device is recording, the single large BPM number is replaced
by a **per-device block** for each strap: a color swatch (matching that device's
chart line), the device name, its current BPM in zone color, its connection
status, and its **own** min/avg/max, exact zone / HR Load stat, and time-in-zone
breakdown. Below the blocks is a single shared chart drawing **one line per
device** (see Chart spec); the per-device blocks double as the chart legend.
Each device's current-BPM zone color, exact zone / HR Load stat, and
time-in-zone are scored against **that stream's attributed athlete's zones**
(the default athlete when unattributed), so re-attributing a strap mid-recording
updates its zones — and clears them if that athlete has no max HR (see
[multi-athlete.md](multi-athlete.md) and
[multi-device-recording.md](multi-device-recording.md)).

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

For a multiple-device activity a **joint comparison chart** at the top draws one
line per device with a legend (color swatch + device name) for at-a-glance
comparison. Below it **each device** gets its own **per-device block**: its own
zone-colored HR chart (a full pan/pinch/tap `ZoomableHrChart`, same as the
single-device view), min/avg/max, time-in-zone breakdown, and **its own
extra-beats load**.

**Analysis on this screen is strictly per stream.** Every profile-dependent
value — zone coloring, time-in-zone, HR-derived metrics, and extra beats — is
scored against **that stream's attributed athlete's** max/resting HR. Unlike the
recording screen, an unattributed stream (or one whose athlete has no valid
max/resting HR) does **not** fall back to the default athlete: it keeps the same
"set up your profile" prompt and simply omits the profile-dependent metrics. The
**default athlete is Home's viewing context, never an Activity-analysis input**,
so a workout scores correctly even when none of its streams belongs to the
default athlete. An attributed stream's prompt opens that exact athlete's
profile; an unattributed stream shows only its athlete picker, since no profile
is relevant until it has an owner. See [multi-athlete.md](multi-athlete.md).

The **workout shape** (per-third max HR) is shown once, computed from the
activity's **reference stream** — the workout's stable **primary sample set**
(lowest set id), labelled with its device name in the multi-stream case. The
shape thirds are profile-free and always render. Any shape/load value that needs
a profile uses the reference stream's **attributed athlete**; if that stream is
unattributed or its profile is incomplete, the shape renders **without** those
values rather than borrowing the default athlete's. See
[multi-device-recording.md](multi-device-recording.md).

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
- **Line**: continuous, colored by zone (see zones.md); breaks at NULL HR gaps.
  With multiple devices the **joint comparison chart** draws one line per
  device, each in a stable per-device palette color instead of zone color (see
  [multi-device-recording.md](multi-device-recording.md)); the **per-device
  charts** below it are each zone-colored against that stream's athlete's zones
  (see [multi-athlete.md](multi-athlete.md))
- **Tap inspection** with multiple devices shows the shared timestamp plus one
  BPM value per device, each tinted in its line color, with a dot on each line
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

These profile fields edit the **default athlete** and **auto-save on blur** —
there is no Save button. Zone colors are unlocked once max HR is set. The
settings screen makes this visible with a short prompt when max HR is absent.

### Advanced

Secondary controls use full-width rows shaped like the settings toggles: icon,
title, short explanatory subtitle, and either a switch or action affordance.
Action rows carry a trailing chevron only when they open another screen, so the
chevron consistently means "navigate". Groups are introduced by a tinted section
band and ordered so developer/support features stay at the bottom:

Directly below the profile fields (no band), **Manage athletes** opens the
athlete-management screen to add, edit, and remove athletes (see
[multi-athlete.md](multi-athlete.md)); it's the one navigation row, so it shows
a chevron.

**Backup**

- **Export database** - downloads a backup file of the current database
- **Restore from database** - replaces the current database with a user-selected
  backup file

**Advanced**

- **Record from multiple devices** — track more than one heart-rate strap in a
  single session; unlocks multi-selection in the picker (see
  [multi-device-recording.md](multi-device-recording.md))
- **Fake heart-rate device** — offer a simulated strap when starting a
  recording, for testing without hardware
- **Export logs** - downloads a log file to share with the devs

**About**

- **App version** - shows the current build label
- **Source on GitHub** - opens the repo in a browser so users can file feedback
  as an issue, inspect the code, or propose a change

## Athlete management screen

A tucked-away screen reached from Advanced → Manage athletes. It edits athletes
**one at a time** (a pager, not a list) using the same name / resting HR / max
HR form as Settings.

- **Navigation**: previous / next athlete, plus a **＋ create** action that
  lands on a new blank athlete. A `2 of 3`-style indicator shows the current
  position.
- **Auto-save**: fields persist on blur and when navigating between athletes; no
  Save button.
- **Delete**: available per athlete, but **disabled when only one athlete
  remains** (the app requires ≥1). Deleting removes that athlete's HR streams
  and any workout recorded only from them; a warning dialog names the concrete
  count (e.g. "12 workouts and all their heart-rate data") and is styled like
  the restore-database dialog. Shared multi-device sessions keep their other
  streams. See [multi-athlete.md](multi-athlete.md).

An athlete picker appears elsewhere (activity meta fields for single-stream
activities, per-device blocks for multi-stream) only when more than one athlete
exists. See [multi-athlete.md](multi-athlete.md).
