# Data Model

How we store, and query data to make the app reliable and fast.

```sql
CREATE TABLE athletes (
  id INTEGER PRIMARY KEY,
  name TEXT
);

CREATE TABLE activities (
  id INTEGER PRIMARY KEY,
  athlete_id INTEGER NOT NULL,
  started_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,

  sport_type TEXT,
  sparkline TEXT,

  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE samples (
  activity_id INTEGER NOT NULL,
  t_ms INTEGER NOT NULL,

  hr INTEGER,              -- bpm
  -- lat_e7 INTEGER,          -- latitude * 10,000,000
  -- lon_e7 INTEGER,          -- longitude * 10,000,000
  -- altitude_cm INTEGER,     -- meters * 100
  -- speed_cm_s INTEGER,      -- m/s * 100
  -- cadence INTEGER,

  PRIMARY KEY (activity_id, t_ms),
  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX samples_activity_time_idx
ON samples(activity_id, t_ms);

CREATE TABLE markers (
  id INTEGER PRIMARY KEY,
  activity_id INTEGER NOT NULL,
  t_ms INTEGER NOT NULL,
  kind TEXT NOT NULL,
  note TEXT,

  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);

CREATE INDEX markers_activity_time_idx
ON markers(activity_id, t_ms);
```

### Marker kinds

Example kinds (not exhaustive):

- `workout_start` — adjustable start of the effort period; overrides
  `started_at_ms` for display and analysis
- `workout_end` — adjustable end; overrides raw `duration_ms`
- `round_start` — start of a round, placed by the user or auto-detected by
  analysis
- `moment` — freeform tap during recording, with optional `note`
