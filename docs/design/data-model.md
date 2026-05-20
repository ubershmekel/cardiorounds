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
```
