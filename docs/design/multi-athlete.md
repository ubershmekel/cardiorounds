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
  `sample_sets.id`) whenever a single owner is needed (e.g. a future
  "whose workout" label on the home log). Every activity has ≥1 set, so this is
  always defined.
- `activities.athlete_id` was **write-only** before this change (stored on
  create, never read back — zones came from the single default athlete), so
  relocating it touches almost no read paths.

### The one invariant: at least one athlete always exists

`watchDefaultAthlete()` reads the first athlete row (`LIMIT 1`) and the whole app
treats it as "you" / the default owner. Zero athletes would break it. So:

- The **default athlete** is the lowest-`id` athlete row; it can be edited and
  cleared but the app guarantees one exists (`ensureDefaultAthlete` on startup).
- **Delete is disabled when only one athlete remains.** No "empty the default"
  special case is needed — the pager simply won't let you remove the last one.

## Managing athletes (pager, not a list)

Reached from Advanced settings. Rather than a list, the screen shows **one
athlete at a time** — the same name / resting HR / max HR form used in Settings —
with controls to move to the **previous / next** athlete or **create** a new one.
A `2 of 3`-style position indicator shows where you are.

- **Auto-save, no Save button.** Fields persist on blur and on navigation between
  athletes, matching the recording meta-field pattern
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
- A **warning dialog states the concrete blast radius** — e.g. *"Delete Dana?
  This permanently deletes 12 workouts and all their heart-rate data. This can't
  be undone."* — styled in error color like the restore-database dialog. An
  athlete with zero streams deletes with no scary dialog.
- Deleting the last remaining athlete is not offered (see the invariant above).

Mechanically, `ON DELETE CASCADE` on `sample_sets.athlete_id` removes the streams
when the athlete row is deleted; the DAO deletes the now-empty activities in the
same transaction.

## Attribution UX (who wore which strap)

- **Single-stream activity (the common case):** a single athlete picker in the
  activity meta-field cluster
  ([activity_meta_fields.dart](../../app/lib/features/recording/activity_meta_fields.dart)),
  shown only when >1 athlete exists. It writes the sole stream's `athlete_id`.
- **Multi-stream activity:** attribution belongs on the **per-device blocks**
  (recording + review), where there is already one block per strap. Each block
  gets an athlete dropdown. "This strap is Dana" lives with the strap, not in the
  shared activity metadata.
- **New recordings** stamp every new stream with the **default athlete**; the
  user re-attributes afterward (or per device on the confirm-record screen, a
  later refinement).

## Zones become correct per stream

Today per-device time-in-zone is scored against the single default athlete's
max/resting HR — exact for one person wearing two sensors, only approximate when
the straps are different people (see
[multi-device-recording.md](multi-device-recording.md)). Once each stream carries
its own `athlete_id`, **each per-device block scores against that person's
zones**. Activity-level shape and load score still come from the primary set and
its athlete.

> Follow-up: `shape_start/mid/end` and the load score are stored on the activity
> and computed from the primary set. If the primary stream is later deleted (a
> shared session losing its primary athlete), those values go stale until
> recomputed. Acceptable for v1; note at the delete site.

## Migration v2 → v3

Additive plus one column drop; see the SQL in [data-model.md](data-model.md).
Copy each activity's `athlete_id` down onto its sample sets, then drop
`activities.athlete_id`. Run with foreign keys disabled and
`PRAGMA foreign_key_check` before re-enabling, covered by a migration test from a
real v2 fixture — same discipline as the v1 → v2 migration.
