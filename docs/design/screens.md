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

This screen detects the bluetooth heart rate device. Shows the user the status
of the device.

You can go back or cancel.

Once a device is detected you can tap the "Start recording" button which leads
to the recording screen.

## Recording screen

Show:

- The current heart rate
- A button to stop recording (requires confirmation modal)
- A chart of the workout HR over time
- Max heart rate so far
- Min heart rate so far
- Average heart rate
- Button to tag a moment (writes a `moment` human marker at the current
  timestamp)

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
