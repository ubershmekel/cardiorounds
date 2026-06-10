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
  athlete_id INTEGER NOT NULL,
  device_id INTEGER,               -- NULL if device was deleted
  started_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,

  name TEXT,                       -- optional user-supplied title
  note TEXT,
  sport_type TEXT,
  shape_start INTEGER,             -- 0-9 load value for the first third of the session
  shape_mid   INTEGER,             -- 0-9 load value for the middle third
  shape_end   INTEGER,             -- 0-9 load value for the final third

  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,

  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL
);

CREATE TABLE samples (
  activity_id INTEGER NOT NULL,
  t_ms INTEGER NOT NULL,

  hr INTEGER,              -- bpm; NULL means signal was lost at this timestamp
  -- lat_e7 INTEGER,          -- latitude * 10,000,000
  -- lon_e7 INTEGER,          -- longitude * 10,000,000
  -- altitude_cm INTEGER,     -- meters * 100
  -- speed_cm_s INTEGER,      -- m/s * 100
  -- cadence INTEGER,

  PRIMARY KEY (activity_id, t_ms),
  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- WITHOUT ROWID tables use the PRIMARY KEY as their clustered B-tree, so this
-- index is redundant. Kept here explicitly to document that queries on
-- (activity_id, t_ms) are always fast.
CREATE INDEX samples_activity_time_idx
ON samples(activity_id, t_ms);

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

### Marker kinds

A marker with `duration_ms = NULL` is a point in time. A marker with a non-NULL
`duration_ms` spans a time range from `t_ms` to `t_ms + duration_ms`.

| Kind       | Type  | Description                                                                                                                                 |
| ---------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `workout`  | span  | The effort window. Overrides `started_at_ms` / `duration_ms` for display and analysis. At most one per activity; enforced in the DAO layer. |
| `round`    | span  | A single round or effort period, placed by the user or auto-detected.                                                                       |
| `recovery` | span  | A detected recovery event (e.g. Z5 → Z3 drop).                                                                                              |
| `moment`   | point | Freeform tap during recording, with optional `name`.                                                                                        |

### Settings storage

`max_heartrate` and `resting_heartrate` are stored on the `athletes` row. The UI
in v0 treats the app as single-athlete (one implicit athlete is created on first
launch), but the DB is intentionally designed for multiple athletes to avoid a
painful migration later.

### Load score window

The load score (extra beats above resting HR) is computed over the `workout`
span marker window when one exists, otherwise over the full `duration_ms`.

## Files

- [app/lib/core/db/tables.dart](../../app/lib/core/db/tables.dart)
