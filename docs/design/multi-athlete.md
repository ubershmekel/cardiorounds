# Multiple athletes

Recording, storing, and reviewing heart rate for more than one person from the
same phone — a coach recording a room, a couple sharing the app, or a
multi-device session where each strap is a different person. Like
[multi-device recording](multi-device-recording.md), this is a **tucked-away**
capability: the app is single-athlete for everyone who never opens the feature,
and nothing about the default experience changes.

Per-screen UX lives in [screens.md](screens.md); the storage shape in
[data-model.md](data-model.md). This doc is the cross-cutting design.

## Discovery (no global toggle)

Unlike the multi-device toggle, there is no on/off switch. The capability is
always present but invisible until used:

- **Settings → Advanced → "Manage athletes"** sits next to "Record from multiple
  devices" and opens the athlete-management screen.
- An **athlete picker appears only when more than one athlete exists** — a solo
  user never sees it. So adding a second athlete is what "turns the feature on,"
  and deleting back down to one turns it off again.

## Storage: athlete is a property of the stream, not the session

The attribution grain is the **`sample_set`** (one HR stream from one device),
not the activity. A multi-device session can hold several people's streams under
one activity, so a single `activities.athlete_id` can't represent it — it's the
wrong cardinality, not just a denormalization.

- `athlete_id` moves onto `sample_sets` (nullable, FK to `athletes`,
  `ON DELETE CASCADE`) and is **dropped from `activities`**. See
  [data-model.md](data-model.md).
- **An activity's athlete is derived** from its **primary HR set** (lowest
  `sample_sets.id`) whenever a single owner is needed (e.g. a future "whose
  workout" label on the home log). Every activity has ≥1 set, so this is always
  defined.
- `activities.athlete_id` was **write-only** before this change (stored on
  create, never read back — zones came from the single default athlete), so
  relocating it touches almost no read paths.

### The one invariant: at least one athlete always exists

`watchDefaultAthlete()` reads the first athlete row (`LIMIT 1`) and the whole
app treats it as "you" / the default owner. Zero athletes would break it. So:

- The **default athlete** is the lowest-`id` athlete row; it can be edited and
  cleared but the app guarantees one exists (`ensureDefaultAthlete` on startup).
- **Delete is disabled when only one athlete remains.** No "empty the default"
  special case is needed — the pager simply won't let you remove the last one.

## Managing athletes (pager, not a list)

Reached from Advanced settings. Rather than a list, the screen shows **one
athlete at a time** — the same name / resting HR / max HR form used in Settings
— with controls to move to the **previous / next** athlete or **create** a new
one. A `2 of 3`-style position indicator shows where you are.

- **Auto-save, no Save button.** Fields persist on blur and on navigation
  between athletes, matching the recording meta-field pattern
  ([activity_meta_fields.dart](../../app/lib/features/recording/activity_meta_fields.dart)).
  The Settings profile fields adopt the same auto-save (the standalone Save
  button goes away).
- **Create** lands you on a new blank athlete. **Delete** lands you on an
  adjacent one.

### Deleting an athlete

Deletion is destructive by design and removes that athlete's data:

- Delete the athlete's **sample sets** (their HR streams; `hr_samples` cascade),
  then delete any **activity left with no remaining sets** (a session recorded
  only from this athlete), whose markers cascade with it. A **shared** session
  (this athlete plus another) keeps its other streams and survives.
- A **warning dialog states the concrete blast radius** — e.g. _"Delete Dana?
  This permanently deletes 12 workouts and all their heart-rate data. This can't
  be undone."_ — styled in error color like the restore-database dialog. An
  athlete with zero streams deletes with no scary dialog.
- Deleting the last remaining athlete is not offered (see the invariant above).

Mechanically, `ON DELETE CASCADE` on `sample_sets.athlete_id` removes the
streams when the athlete row is deleted; the DAO deletes the now-empty
activities in the same transaction. Athlete deletion is disabled while a
recording is active, so this cascade cannot remove live sample sets that the
recording controller is still writing to.

## Attribution UX (who wore which strap)

Athlete attribution is a property of the **stream**, so it is always the **same
per-stream control**, placed with that stream's identity (**next to the device
name**). The single-stream case is just the N=1 instance of the multi-stream
case — the picker does **not** move to a different place or fold into the shared
activity metadata when a second strap appears. This keeps "this strap is Dana"
next to the strap in every layout and avoids a jarring relocation between one
and two streams.

- **The picker is its own athlete dropdown**, not an entry in the activity
  meta-field cluster
  ([activity_meta_fields.dart](../../app/lib/features/recording/activity_meta_fields.dart)).
  It is rendered as its own control near the device name/label and writes that
  stream's `athlete_id`.
- **Single-stream:** one picker beside the sole stream's device name. In the
  recording and review layouts that stream currently has no per-device block
  (the device name is the screen title / the line is the whole chart), so it
  gets a lightweight device-name + athlete-picker row in the same relative
  position the multi-stream blocks occupy.
- **Multi-stream:** the **per-device blocks** already show one block per strap;
  each block's header (which shows the device name) gains the same athlete
  picker.
- **Shown only when >1 athlete exists.** A solo user never sees a picker on any
  screen.

Attribution is editable only on the **recording screen**
([recording_screen.dart](../../app/lib/features/recording/recording_screen.dart))
and the **activity review screen**
([activity_screen.dart](../../app/lib/features/activity/activity_screen.dart)).

- **New recordings** stamp every new stream with the **default athlete**; the
  user re-attributes on either of those two screens. The confirm-record screen
  is intentionally left out of scope — re-attribution there is more than it's
  worth at this point.

## Zones become correct per stream

Today per-device time-in-zone is scored against the single default athlete's
max/resting HR — exact for one person wearing two sensors, only approximate when
the straps are different people (see
[multi-device-recording.md](multi-device-recording.md)). Once each stream
carries its own `athlete_id`, **each per-device block scores against that
person's zones** — the block's **zone-colored chart**, its time-in-zone
breakdown, and its extra-beats load all use that stream's athlete's max/resting
HR. Resolving a stream's zones needs its `athlete_id`, so `watchHrSeries`
exposes `athlete_id` on each `HrSeries`.

### Live coloring vs. review analysis (they resolve zones differently)

The default athlete is the **Home-screen viewing context** — "whose single live
number do we color" — and a live-recording convenience, **not** an
Activity-analysis input. The two screens therefore treat an unattributed or
profile-less stream differently, on purpose:

- **Recording screen (live):** an unattributed strap falls back to the default
  athlete's zones for live coloring, so the number is colored while you record.
  Home's single live HR value likewise uses the default athlete's profile.
- **Activity review screen (analysis):** resolution is **strictly per stream
  with no default fallback**. A stream that is unattributed, or whose athlete
  has no valid max/resting HR, keeps the "set up your profile" prompt and omits
  every profile-dependent value (zones, HR-derived metrics, **extra beats**)
  rather than borrowing the default athlete's. This is what makes a workout
  analyse correctly when **no stream belongs to the default athlete** — the
  default is never read. The locked prompt opens the attributed athlete's
  profile; an unattributed stream shows only its athlete picker, since there is
  no profile to complete until an athlete is assigned.

Extra beats is inherently per-athlete (it integrates HR above that person's
resting HR), so it is a **per-stream** metric shown in each stream's block,
scored against that stream's own athlete.

### The shape's reference stream

Activity-level **workout shape** (per-third max HR) is anchored to the workout's
stable **reference stream — the primary sample set** (lowest `sample_sets.id`),
never "whichever athlete is default or first valid". The shape thirds are
profile-free and always render. Any shape/load value that _does_ need a profile
uses the reference stream's **attributed athlete**; if that stream is
unattributed or its profile is incomplete, the shape renders **without** those
values instead of falling back to the default athlete. `watchHrSeries` omits no
sets: it retains empty sets so device order, including the primary reference
stream, remains stable even when a strap never produced a sample.

> Follow-up: `shape_start/mid/end` are stored on the activity and computed from
> the primary set. If the primary stream is later deleted (a shared session
> losing its primary athlete), those values go stale until recomputed.
> Acceptable for v1; note at the delete site.

## Migration v2 → v3

Additive plus one column drop; see the SQL in [data-model.md](data-model.md).
Copy each activity's `athlete_id` down onto its sample sets, then drop
`activities.athlete_id`. Run with foreign keys disabled and
`PRAGMA foreign_key_check` before re-enabling, covered by a migration test from
a real v2 fixture — same discipline as the v1 → v2 migration.
