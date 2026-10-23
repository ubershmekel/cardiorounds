# Activity export and import

Exporting one activity to a portable file, and importing such a file back. One
format does both jobs: a **standard TCX file** that Strava, Garmin Connect,
intervals.icu, TrainingPeaks and others accept as a normal workout, carrying the
full Cardio Rounds data in a namespaced `<Extensions>` block that other apps
ignore.

Per-screen UX lives in [screens.md](screens.md); the storage shape in
[data-model.md](data-model.md).

## Why TCX (and not JSON, FIT, GPX, CSV)

- **TCX** is plain XML, widely accepted with HR-only data, and its schema allows
  `<Extensions>` (any other namespace, validated `lax`) on `Activity`, `Lap` and
  `Trackpoint`. So one file is both a shareable workout and a lossless backup of
  the activity.
- A **native JSON** format would be lossless but no other app reads it; we'd
  still need TCX for sharing, i.e. two formats to design and test.
- **FIT** is the highest-fidelity format but binary, and Dart writer support is
  thin. Revisit only if TCX proves insufficient.
- **GPX** is built around location tracks; HR needs extensions and we don't
  record location yet.
- **CSV** loses structure (sets, athletes, markers).

The importer also reads **plain TCX** from other apps (Garmin, Polar, ...): with
no `cr:` block it imports the standard trackpoints as a single HR stream.

## File layout

```xml
<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase
    xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities>
    <Activity Sport="Other">
      <Id>2026-10-22T07:00:00.000Z</Id>
      <Lap StartTime="2026-10-22T07:00:00.000Z">
        <TotalTimeSeconds>3600</TotalTimeSeconds>
        <DistanceMeters>0</DistanceMeters>
        <Calories>0</Calories>
        <AverageHeartRateBpm><Value>142</Value></AverageHeartRateBpm>
        <MaximumHeartRateBpm><Value>188</Value></MaximumHeartRateBpm>
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>
          <Trackpoint>
            <Time>2026-10-22T07:00:01.000Z</Time>
            <HeartRateBpm><Value>92</Value></HeartRateBpm>
          </Trackpoint>
          <!-- ... -->
        </Track>
      </Lap>
      <Notes>user note</Notes>
      <Extensions>
        <cr:CardioRounds xmlns:cr="https://github.com/ubershmekel/cardiorounds/tcx/v1"
                         formatVersion="1" appVersion="1.2.3+45">
          <cr:Activity startedAtMs="..." durationMs="..." name="..."
                       sportType="kickboxing" shapeStart="4" shapeMid="7" shapeEnd="5"/>
          <!-- Ana's set fills the trackpoints, so its samples live there -->
          <cr:Set kind="hr" primary="true" samples="trackpoints">
            <cr:Device platformId="..." name="Polar H10"/>
            <cr:Athlete name="Ana" restingHeartrate="55" maxHeartrate="190"/>
          </cr:Set>
          <cr:Set kind="hr">
            <cr:Device platformId="..." name="Wahoo TICKR"/>
            <cr:Athlete name="Ben" restingHeartrate="60" maxHeartrate="185"/>
            <cr:T>0 1000 2000 3000</cr:T>
            <cr:Hr>92 - 95 96</cr:Hr>
          </cr:Set>
          <cr:Marker tMs="0" durationMs="3600000" kind="workout"/>
          <cr:Marker tMs="61000" kind="moment" name="Round start"/>
        </cr:CardioRounds>
      </Extensions>
    </Activity>
  </Activities>
</TrainingCenterDatabase>
```

### Standard part (what other apps see)

- **One `<Activity>`** per file. Multiple `<Activity>` elements are legal TCX,
  but other apps handle them inconsistently; extra athletes go in the extension
  instead.
- **Trackpoints** carry the HR stream of the **chosen athlete** (see the picker
  below): that athlete's lowest-id HR set.
  - `Time` = `started_at_ms + t_ms`, UTC ISO-8601 with milliseconds.
  - A NULL `hr` sample becomes a trackpoint with `<Time>` but no
    `<HeartRateBpm>`, so the dropout survives as a gap.
- **Laps**: one lap covering the whole activity. Mapping `round` markers to laps
  is a later enhancement; markers already round-trip via the extension.
- **`Sport`** is `Other`, since TCX only allows Running / Biking / Other. The
  real `sport_type` goes in `cr:Activity`. (Mapping run-like sport types to
  `Running` is a later enhancement.)
- **`Notes`** carries the activity note, so other apps that show notes show it.
- Lap totals (`AverageHeartRateBpm`, `MaximumHeartRateBpm`) are computed from
  the trackpoint stream at export time; `DistanceMeters` and `Calories` are 0.

### Extension part (`cr:` namespace)

- **`formatVersion`** gates parsing. The importer refuses a higher major version
  with a clear message rather than guessing.
- **`cr:Activity`** carries the activity row (minus ids and created/updated
  timestamps, which the importer assigns).
- **One `cr:Set` per included sample set**, in `sample_sets.id` order. One set
  is marked `primary="true"`: the activity's real primary set (its reference
  stream for shape and owner) when it's in the file, otherwise the set in the
  trackpoints. Each set embeds:
  - `cr:Device` — a snapshot of the device (`platformId`, `name`), absent when
    `device_id` is NULL.
  - `cr:Athlete` — a snapshot of the attributed athlete (`name`, resting/max
    HR), absent when unattributed. **Raw BPM only; zones are never written** —
    they're recomputed from the athlete's settings, as everywhere else.
  - `cr:T` / `cr:Hr` — parallel space-separated lists. `t_ms` offsets from
    `startedAtMs`; `-` marks a NULL sample. Exact original timestamps, so a set
    on a different clock cadence than the trackpoints loses nothing.
  - **Except the set that fills the trackpoints**, which is marked
    `samples="trackpoints"` and has no `cr:T` / `cr:Hr`: its samples are read
    back from the trackpoints, which already hold them (millisecond times, NULLs
    as HR-less trackpoints). Storing them twice would let the copies disagree. A
    single-athlete file therefore has no sample lists in the extension at all.
    The one lossy case is a reading outside TCX's 1–255 bpm range (e.g. `0` from
    a strap with no skin contact), which is written as an HR-less trackpoint and
    so re-imports as NULL.
- **`cr:Marker`** per marker row (activity-level, as in the data model).

Sizes: trackpoints are ~150 bytes each, so about 0.5 MB per hour of 1 Hz HR per
file, plus a few bytes per sample per extra set. Acceptable for a share sheet.

## Export UX

An **Export** action (share icon) in the activity review screen's app bar. It
encodes the file in memory and opens the system share sheet via `share_plus`
(which writes it to a temp file on mobile). Filename:
`cardio-rounds-<yyyy-MM-dd-HHmm>-<name or sport>.tcx`, sanitized.

### Single owner: one tap

If every HR set in the activity belongs to the same owner, Export goes straight
to the share sheet. This is the common case and the only one a solo user ever
sees.

### Several owners: "Whose workout?" picker

If the activity's HR sets belong to **more than one owner**, Export first shows
a small dialog:

- **"Whose workout?"** — one radio option per owner. An owner is an attributed
  athlete (shown by name), or an unattributed stream (shown as "Unassigned
  (<device name>)", each unattributed stream its own option). Defaults to the
  owner of the primary set. The chosen owner's HR fills the standard trackpoints
  and the file is named after the activity, as above.
- **"Include all athletes"** checkbox, **checked by default**.
  - Checked: the `cr:` block includes **every** set, so the file restores the
    whole session on import. Use for your own backup.
  - Unchecked: the `cr:` block includes **only the chosen owner's** sets. Other
    people's heart-rate data doesn't leave the device. Use when sending one
    person their own workout.
  - Activity-level data (name, note, sport type, markers) is included either
    way.
- **Export** / **Cancel** buttons. Export opens the share sheet.

When "Include all athletes" is checked and the chosen owner isn't the primary
set's owner, the chosen owner's set is still the one in the trackpoints, and the
`primary="true"` flag stays on the real primary set, so a re-import is identical
to the original.

### Web

Export works on web too, unlike "Export database": the browser's share dialog
opens where it supports sharing files, otherwise the `.tcx` downloads
(share_plus's download fallback). The picker and checkbox are shown on web too.

## Import UX

Out of scope for the first export PR; designed here so the format supports it.

- Entry point: **Settings → Backup → Import activity**, using `file_picker`
  (`.tcx`).
- **With a `cr:` block:** recreate the activity, its sets, samples and markers.
  The `samples="trackpoints"` set takes its samples from the trackpoints (time
  minus `startedAtMs`; no `HeartRateBpm` → NULL), the same parsing as plain TCX.
  - Devices are matched by `platformId`; unknown devices are created from the
    snapshot.
  - Athletes are matched by exact name; an unmatched athlete is created from the
    snapshot. A matched athlete's existing resting/max HR is **not**
    overwritten.
  - A local activity with the same `startedAtMs` and `durationMs` is flagged as
    a likely duplicate; the user can import anyway or cancel.
- **Without a `cr:` block** (plain TCX from another app): one activity, one HR
  set from the trackpoints, attributed to the default athlete, no device. Time
  offsets are computed from the first trackpoint. Multiple `<Activity>` elements
  import as separate activities.
- Malformed or unreadable files show an error dialog and import nothing (the
  whole import is one transaction).

## Logging

Per AGENTS.md, `appLog` the export (activity id, sets included, sample counts,
bytes written, success/failure) and each import (format version, rows created
per table, duplicate detection, logged-then-rethrown failure).

## Testing

Pure-Dart encoder/decoder under `app/lib/core/export/`, with unit tests:

- Export → import round-trip equals the original (sets, NULL samples, markers,
  athlete/device snapshots), for both checkbox states.
- Excluding other athletes really drops their sets.
- Plain-TCX import from a real third-party fixture.
- Unknown higher `formatVersion` is rejected.

## Location (future)

When location recording lands, the chosen owner's location set fills
`<Position>` (and `<AltitudeMeters>`) on the trackpoints, merged onto the HR
timeline by nearest fix. The extension gets a `cr:Set kind="location"` with its
own `cr:T` / `cr:Lat` / `cr:Lon` lists, so nothing is resampled.

## Files

- [app/lib/core/export/activity_export.dart](../../app/lib/core/export/activity_export.dart)
  — TCX encoder (decoder later)
- [app/lib/features/activity/export_activity.dart](../../app/lib/features/activity/export_activity.dart)
  — export flow and "Whose workout?" dialog
- [app/lib/features/activity/activity_screen.dart](../../app/lib/features/activity/activity_screen.dart)
  — Export action in the app bar
- [app/lib/features/settings/settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
  — Import activity row (later)
