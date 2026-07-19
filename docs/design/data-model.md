# Data Model

How we store, and query data to make the app reliable and fast.

```sql
CREATE TABLE athletes (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  resting_heartrate INTEGER,        -- NULL until the user sets it
  max_heartrate INTEGER,            -- NULL until the user sets it; zone colors stay locked while NULL
  created_at_ms INTEGER NOT NULL
);

CREATE TABLE devices (
  id INTEGER PRIMARY KEY,
  platform_id TEXT NOT NULL UNIQUE, -- MAC on Android, UUID on iOS
  name TEXT NOT NULL,
  last_connected_at_ms INTEGER NOT NULL
);

CREATE TABLE activities (
  id INTEGER PRIMARY KEY,
  -- No athlete_id: attribution is per-stream, on sample_sets.athlete_id. An
  -- activity's owner is derived from its primary HR set. See multi-athlete.md.
  started_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,

  name TEXT,                       -- optional user-supplied title
  note TEXT,
  sport_type TEXT,
  shape_start INTEGER,             -- 0-9 load value for the first third of the session
  shape_mid   INTEGER,             -- 0-9 load value for the middle third
  shape_end   INTEGER,             -- 0-9 load value for the final third

  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

-- One activity (session) fans out to many sample_sets: one per device, per
-- signal type. A single-device HR recording has exactly one sample_set with
-- kind='hr'. The device association lives here (not on activities) so an
-- activity can span multiple devices.
CREATE TABLE sample_sets (
  id INTEGER PRIMARY KEY,
  activity_id INTEGER NOT NULL,
  device_id INTEGER,               -- NULL if device was deleted
  athlete_id INTEGER,              -- who wore this device; NULL = unattributed
  kind TEXT NOT NULL,              -- 'hr' (future: 'location', 'spo2', ...)
  -- label / color land here when multi-signal UI needs them; additive.

  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id)  REFERENCES devices(id)    ON DELETE SET NULL,
  -- CASCADE: deleting an athlete removes their streams (hr_samples cascade in
  -- turn); the DAO then deletes any activity left with no sets. See
  -- multi-athlete.md.
  FOREIGN KEY (athlete_id) REFERENCES athletes(id)   ON DELETE CASCADE
);

CREATE INDEX sample_sets_activity_kind_idx
ON sample_sets(activity_id, kind, id);

-- One known device contributes at most one set of a given kind per activity, so
-- a mid-session disconnect/reconnect resumes the SAME set (the gap is just NULL
-- hr samples) rather than starting a new one. NULL device_id is exempt.
CREATE UNIQUE INDEX sample_sets_activity_device_kind_unique
ON sample_sets(activity_id, device_id, kind)
WHERE device_id IS NOT NULL;

-- Heart-rate samples. Each signal type gets its own *_samples table because
-- their value columns differ (an HR strap has no GPS). Future signals follow
-- the same shape: (set_id, t_ms, <value columns>), PRIMARY KEY (set_id, t_ms).
--
--   CREATE TABLE location_samples (
--     set_id INTEGER NOT NULL,
--     t_ms INTEGER NOT NULL,
--     lat_e7 INTEGER,        -- latitude * 10,000,000
--     lon_e7 INTEGER,        -- longitude * 10,000,000
--     altitude_cm INTEGER,  -- meters * 100
--     PRIMARY KEY (set_id, t_ms),
--     FOREIGN KEY (set_id) REFERENCES sample_sets(id) ON DELETE CASCADE
--   ) WITHOUT ROWID;
CREATE TABLE hr_samples (
  set_id INTEGER NOT NULL,
  t_ms INTEGER NOT NULL,
  hr INTEGER,              -- bpm; NULL means signal was lost at this timestamp

  PRIMARY KEY (set_id, t_ms),
  FOREIGN KEY (set_id) REFERENCES sample_sets(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- WITHOUT ROWID tables use the PRIMARY KEY as their clustered B-tree, so this
-- index is redundant. Kept here explicitly to document that queries on
-- (set_id, t_ms) are always fast.
CREATE INDEX hr_samples_set_time_idx
ON hr_samples(set_id, t_ms);

CREATE TABLE markers (
  id INTEGER PRIMARY KEY,
  activity_id INTEGER NOT NULL,
  t_ms INTEGER NOT NULL,
  duration_ms INTEGER,             -- NULL = point marker; non-NULL = span marker
  kind TEXT NOT NULL,
  name TEXT,                       -- optional short label or note

  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);

CREATE INDEX markers_activity_time_idx
ON markers(activity_id, t_ms);
```

### Sample sets (multi-device, multi-signal)

A `sample_set` is one time series of one signal type from one source (device)
within an activity. This is the grain that lets a single session record from
several HR devices at once, and leaves room for other signals (location, SpO2,
elevation) without reworking how samples are stored.

- **`kind` lives on the parent** so we can list "every HR stream in this
  activity" without touching child tables. Which `*_samples` table a set's rows
  live in is convention keyed off `kind`, not an enforced foreign key. We
  deliberately do _not_ add `CHECK (kind IN (...))` — a hard check would force a
  table rebuild every time a new signal kind is introduced.
- **Per-stream athlete is the attribution grain.** A second device may be a
  second sensor on the same athlete _or_ a second person in a group session, so
  `athlete_id` lives on `sample_sets` (nullable), never on the activity. An
  activity's owner is derived from its primary set. See
  [multi-athlete.md](multi-athlete.md).
- **Device deletion stays graceful.** `device_id` is on `sample_sets` and off
  the sample primary key, so `ON DELETE SET NULL` still works. (Putting
  `device_id` in a `WITHOUT ROWID` sample PK was rejected: PK columns cannot be
  NULL.)

### Activity-level shape with multiple HR sets

`shape_start` / `shape_mid` / `shape_end` are computed from the **primary HR set
only** (the first `kind='hr'` set, i.e. lowest `sample_sets.id`). Aggregating
across multiple HR sets would mix duplicate timestamps from different devices
and corrupt the thirds. If per-stream shape is ever needed it moves to
`sample_sets`.

### Marker kinds

A marker with `duration_ms = NULL` is a point in time. A marker with a non-NULL
`duration_ms` spans a time range from `t_ms` to `t_ms + duration_ms`.

| Kind       | Type  | Description                                                                                                                                 |
| ---------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `workout`  | span  | The effort window. Overrides `started_at_ms` / `duration_ms` for display and analysis. At most one per activity; enforced in the DAO layer. |
| `round`    | span  | A single round or effort period, placed by the user or auto-detected.                                                                       |
| `recovery` | span  | A detected recovery event (e.g. Z5 → Z3 drop).                                                                                              |
| `moment`   | point | Freeform tap during recording, with optional `name`.                                                                                        |

Markers are **activity-level** (one timeline per session). This is correct for
`workout`, and acceptable for `round` / `recovery` while sets share a clock. If
a single activity ever represents multiple people, analysis markers (`recovery`,
auto-`round`) gain a nullable `set_id` for per-stream scope; until then we don't
generate per-person markers.

### Settings storage

`max_heartrate` and `resting_heartrate` are stored on the `athletes` row. The
app is single-athlete by default (one implicit athlete created on first launch),
and the DB was always designed for multiple athletes. The tucked-away
multi-athlete UI (Advanced → Manage athletes) surfaces the extra rows; see
[multi-athlete.md](multi-athlete.md). The app guarantees **≥1 athlete always
exists** — `watchDefaultAthlete()` reads the lowest-`id` row as the default, and
deleting the last athlete is not offered.

### Load score window

The load score (extra beats above resting HR) is computed over the `workout`
span marker window when one exists, otherwise over the full `duration_ms`.

### Migration v1 → v2 (introduce `sample_sets`)

v1 stored one implicit HR stream per activity (`activities.device_id` +
`samples` keyed by `activity_id`). v2 splits that into `sample_sets` +
`hr_samples`:

```sql
-- One HR set per existing activity. Reuse the activity id as the set id so the
-- sample copy below is a trivial 1:1 map with no lookup table.
INSERT INTO sample_sets (id, activity_id, device_id, kind)
SELECT id, id, device_id, 'hr' FROM activities;

INSERT INTO hr_samples (set_id, t_ms, hr)
SELECT s.activity_id, s.t_ms, s.hr
FROM samples s
INNER JOIN activities a ON a.id = s.activity_id;
```

Reusing `id` is a **one-time migration convenience, not an invariant**: new
activities get autoincremented set ids that won't equal their activity id, so no
query or display code may assume `set_id == activity_id`.

The join intentionally drops orphaned v1 samples whose parent activity no longer
exists. v1 did not consistently enable SQLite foreign key enforcement, so real
databases can contain those rows after an activity delete; v2 cannot attach them
to a valid `sample_sets` row.

Some real databases can also report v1 while already missing
`activities.device_id`. In that shape, migrate the HR set with
`device_id = NULL` instead of failing; the samples remain attached to their
activity, but the old device association is no longer recoverable from the
database.

`samples` is rebuilt, not renamed — its primary key and foreign key both change
from `activity_id` to `set_id`, which `ALTER TABLE ... RENAME` cannot do. Drop
`activities.device_id` in the same migration (a table rebuild). Run the schema
changes with foreign keys disabled, then `PRAGMA foreign_key_check` before
re-enabling, and cover the whole path with a migration test from a real v1
schema fixture.

### Migration v2 → v3 (per-stream `athlete_id`)

Move athlete attribution from the activity onto the stream:

```sql
-- Add the column, back-fill each set from its parent activity's old athlete,
-- then drop activities.athlete_id.
ALTER TABLE sample_sets ADD COLUMN athlete_id INTEGER
  REFERENCES athletes(id) ON DELETE CASCADE;

UPDATE sample_sets
SET athlete_id = (SELECT a.athlete_id FROM activities a WHERE a.id = activity_id);
```

Dropping `activities.athlete_id` is a table rebuild (SQLite can't drop a column
in place on older engines). Run the whole migration with foreign keys disabled
inside an exclusive block, `PRAGMA foreign_key_check` before re-enabling, and
cover it with a migration test from a real v2 schema fixture — same discipline
as v1 → v2. See [multi-athlete.md](multi-athlete.md).

## Files

- [app/lib/core/db/tables.dart](../../app/lib/core/db/tables.dart)
