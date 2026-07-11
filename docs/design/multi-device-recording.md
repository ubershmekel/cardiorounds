# Multiple-device recording

Recording heart rate from more than one strap in a single session — e.g. two
sensors on one athlete to compare, or several people trained together. This is
the cross-cutting design; per-screen UX lives in [screens.md](screens.md) and
the storage shape in [data-model.md](data-model.md).

## Opt-in

Off by default. An Advanced setting, **"Record from multiple devices"**
(`multiDeviceRecordingEnabled`, persisted in SharedPreferences like the
fake-device toggle), unlocks multi-selection in the picker. With it off,
everything behaves exactly as the single-device app does today. The
single-device paths and layouts are never removed — the multi paths are gated by
this setting (in the picker) and by `sources.length > 1` (in recording/review).

## Storage

One activity fans out to one `sample_set` per device (`kind = 'hr'`), each with
its own `hr_samples` stream. See [data-model.md](data-model.md). A single-device
session is the same model with exactly one set. Each set carries its
`device_id`; the device is the stream's identity for coloring and legends.

## Selection and preview (picker)

When the setting is on, the device list becomes a multi-select. Tapping a row
**toggles** it in/out of the selection. Consistent with the existing
single-device flow, selecting a device immediately opens a **live preview
connection** to it and streams its BPM — so the user can confirm sensor contact
on each strap before committing. Differences from single-select:

- Several preview connections are held at once (one per selected device). Some
  phones handle concurrent BLE links less reliably; a device that fails to
  connect surfaces an error on its row and can be retried, without affecting the
  others.
- Scanning keeps running while devices are selected (you need to keep finding
  more), so rows are not greyed out as "stale".

On **Start**, every selected device is included in the recording. Preview
connections that are already live are handed straight to recording (no
disconnect/reconnect). Selected devices that are still connecting move to the
recording screen as pending streams and start writing samples into their
assigned HR set once they connect.

## Recording (N sources)

One `RecordingController` drives N `(source, setId)` pairs. Each source's
samples are written to its own set via `insertHrSample(setId)`; each source's
connection status is tracked independently. The recording state is therefore a
list of per-device entries (name, current BPM, connection status) plus the
shared session fields (start time, elapsed, stopped).

- **Stop / finalize**: the activity duration, shape (`shape_start/mid/end`), and
  load score are activity-level values, so they use the **primary set** (the
  first HR set). Secondary streams remain intact and are still shown in the
  chart and per-device stats.
- **Live Activity** (iOS): shows the primary device only for v1. A multi-device
  summary in the Dynamic Island is a later refinement.

### Per-device stats

Each device shows its **own** min / avg / max and **time-in-zone** breakdown,
both live and on review — these are per-stream, not aggregated. Min/avg/max are
plain BPM stats. Time-in-zone is scored against the single athlete's max/resting
HR (the only zones we have): exact for one-athlete-multi-sensor, approximate
when the devices are different people, until per-device `athlete_id` exists. The
per-device color swatch + name head each block.

The activity-level **duration**, **shape** (per-third max HR), and **load
score** (extra beats) are single-athlete analysis defaults. They are still shown
on the multi-device review — computed from the **primary** device and labelled
with its name — rather than hidden.

## Native central (iOS): one central, many peripherals

On iOS the recording connection is owned by the native `HrBackgroundCentral`
(Swift) so samples keep buffering while iOS suspends the app. There is exactly
**one** `CBCentralManager` — the OS only gives you one — but it must drive **N
peripherals independently**. Everything downstream of the central is keyed by the
device's `CBPeripheral.identifier` (its UUID):

- **Buffers are per device.** Each connected strap has its own sample and event
  buffer. `didUpdateValueFor` routes the parsed BPM into the buffer for
  `peripheral.identifier` — samples from two straps are **never** merged into one
  stream. Merging is the bug this section exists to prevent: without per-device
  keying, two `NativeBluetoothHeartRateSource` drainers race over one shared
  buffer and each chart shows an interleave of both straps.
- **`start` / `drain` / `stop` carry a `remoteId`** and touch only that device's
  slot. Starting a second device does not clear the first's buffer; stopping one
  device cancels only that peripheral's connection and stops its auto-reconnect,
  leaving the others recording.
- **Reconnect is per peripheral.** `didDisconnectPeripheral` re-connects only if
  that specific id is still a wanted target; a device removed via `stop` does not
  auto-reconnect.
- **The hardware scan is shared.** The single scan feeds both the discovery
  picker and the recording connect-fallback; it stops only when no device still
  needs it (no discovery scan running and every recording target is connected or
  connecting).
- **Restore adopts all peripherals.** A BLE relaunch (`willRestoreState`) re-adopts
  every peripheral iOS hands back, not just the first.

This keying is also what the upcoming **multiple-athletes** work builds on: a set
already carries its `device_id`, and per-device streams map cleanly onto a future
per-device `athlete_id`. Nothing here aggregates across devices, so adding
athletes is a labelling/attribution change, not a stream-routing one.

## Crash recovery (all devices)

The crash sentinel records **all** devices in the session
(`devices: [{platformId, name}]`), not just one. On the next launch the resume
prompt names all of them and reconnects to each **best-effort**: it resumes with
whichever devices reconnect, and only fails if none do. The interrupted
activity's existing sets are matched back to their devices by `platformId` to
recover each `setId`. "Save as finished" keeps every stream. The sentinel JSON
is backward compatible — an old single-device sentinel
(`devicePlatformId`/`deviceName`) is read as a one-element list.

## Charts (multi-series)

When an activity has more than one HR stream, the chart draws **one line per
device**:

- Each line uses a stable **per-device palette color** (assigned by set order).
  This color is the device's identity across the live per-device rows, the
  chart, and the legend.
- **Zone-colored lines** are a single-stream feature — in multi-series mode each
  line uses its per-device palette color instead (zone color would collide).
  Zone coloring is unchanged for single-device activities.
- **Tap-to-read inspection** works in multi-series mode: a tap shows the shared
  timestamp and one BPM value per device (each tinted in its line color, with a
  dot on each line), interpolated at that time.
- The Y axis is scaled to cover all series. A **legend** (color swatch + device
  name) identifies the lines on the review screen; on the live screen the
  per-device rows serve as the legend.

Single-device charts are visually and behaviorally identical to today.
