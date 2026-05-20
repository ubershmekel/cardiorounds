Here’s a consolidated product/design/algorithm prompt for the future
implementation agent.

Build a heart-rate-based workout analysis system focused primarily on Brazilian
Jiu-Jitsu (BJJ), but flexible enough for interval-style sports and workouts.

The goal is NOT to build a medical app or generic cardio tracker. The goal is to
build a “session dynamics analyzer” that helps athletes understand:

- pacing
- fatigue
- recovery
- workload
- endurance
- session shape
- trends over time

The app should feel:

- insightful
- athlete-focused
- visually satisfying
- coach-like
- grounded in the user’s own historical data

Avoid fake scientific precision and avoid over-medicalizing the experience.

---

# Core Philosophy

The shape of effort over time is more important than calories or average heart
rate.

The app should emphasize:

- how effort evolved
- how recovery evolved
- how the athlete paced themselves
- how this session compares to their own history

The system should prefer:

- relative comparisons to the athlete’s own baseline
- broad trends
- interpretable metrics
- psychologically meaningful summaries

over:

- rigid physiological claims
- universal optimization scores
- pseudo-scientific “readiness” systems

---

# Core Session Concepts

The system should analyze workouts as:

- time-series heart rate data
- segmented effort periods (“rounds”)
- beginning/middle/end pacing
- recovery events

The system should support:

- rolling analysis
- historical comparisons
- session fingerprints
- derived insights

---

# Primary Metrics

## 1. Load Score

A weighted “area under the curve” style workload score.

Count how many heart beats were above the resting heart rate.

If the resting heart rate is 80 bpm, and the workout was 10 minutes, with 180
bpm, that means the extra beat count was 180-80 = 100 per minute so total extra
beats was 100 x 10 = 1000 beats load.

---

## 2. Recovery Metrics

The app should detect recovery events after hard effort periods.

The exact algorithm can evolve later.

Conceptually:

- detect transitions from sustained high effort toward lower zones
- distinguish clean recoveries from prolonged sustained effort
- reject fake recoveries where HR lingers high too long
- reject noisy zone flickers

Potential metrics:

- Typical recovery
- Best recovery
- Recovery trend across session
- Recovery degradation over time

A useful recovery metric:

- time from sustained Z5 to sustained Z3
- or similar multi-zone drop timing

Important:

- only count valid recovery events
- avoid counting prolonged high-zone plateaus as “recovery”

Potential UI:

- “Typical recovery: 1m 14s”
- “Best recovery: 42s”
- “Clean recoveries detected: 6”

Avoid pretending these are medically exact.

---

## 3. Round Detection

Automatically detect likely rolling rounds or effort periods.

Rounds should become first-class entities.

Possible indicators:

- sustained HR elevation
- rapid HR spikes
- recovery valleys between efforts

Each round may have:

- duration
- average HR
- peak HR
- intensity classification
- recovery afterward
- load contribution

Potential classifications:

- light
- technical
- hard
- war

The goal is to map to how athletes actually remember sessions.

---

# Session Shape Analysis

The app should divide workouts into thirds:

- beginning
- middle
- end

This is preferable to quarters because it maps better to athlete perception.

For each third:

- compute load
- compute density
- compute recovery behavior
- compare pacing

Example patterns:

- High → Medium → Low = burnout/explosive start
- Flat = steady pacing
- Low → Medium → High = strong finish

This enables:

- fade detection
- pacing insights
- endurance insights

Potential derived metrics:

- fade score
- strong finish score
- consistency score

Potential visual:

- tiny bar fingerprint like: ▇▆▃

The workout “shape” should become visually recognizable in history lists.

---

# Historical Analysis

The app should heavily emphasize comparisons to the athlete’s own history.

Important historical metrics:

- load trends
- recovery trends
- consistency
- session density
- hardest sessions
- pacing evolution
- rolling intensity trends

Interesting comparisons:

- gi vs no-gi
- open mat vs class
- coach/class type
- morning vs evening sessions

The system should detect:

- accumulated fatigue
- improving endurance
- unusual pacing
- unusually poor recovery
- unusually strong recovery

Avoid making medical claims.

---

# Actionable Insights

Insights should be:

- short
- grounded
- believable
- directly tied to observed patterns

Good examples:

- “You started unusually hard today and faded late.”
- “Recovery slowed after round 5.”
- “This resembled one of your harder sessions.”
- “Your pacing has become more consistent recently.”
- “Recovery was slower than your normal baseline.”
- “Your strongest round occurred late in the session.”

Bad examples:

- fake readiness scores
- medical diagnosis
- generic hydration advice
- overconfident physiological claims

Insights should sound like a thoughtful coach or training journal.

---

# Visual Design Philosophy

The UI should feel:

- clean
- modern
- athletic
- emotionally satisfying
- visually glanceable

The most important visualization is likely:

- a colored HR timeline over the session

Suggested zone colors:

- gray = low/rest/chatting
- blue = light
- green = moderate
- orange = hard
- pink = max intensity

Avoid danger-oriented red coloring.

The timeline should visually replay the session.

---

# History View

Workout history rows should be compact and glanceable.

Potential row structure:

Open Mat — 1h 32m Load: 182 Recovery: 1m 14s Rounds: 7 ▇▆▃

The user should be able to skim months of sessions quickly and intuitively.

---

# Important Constraints

Do NOT:

- overclaim scientific validity
- present fake precision
- present medical advice
- optimize for calorie counting
- optimize for generic cardio training
- treat all sports as steady-state cardio

DO:

- optimize for interval sports
- optimize for athlete intuition
- optimize for pacing/recovery storytelling
- emphasize trends over absolute numbers
- build psychologically meaningful metrics

The app should feel like:

- an intelligent training journal
- a session replay analyzer
- a pacing and recovery coach

not:

- a hospital dashboard
- a calorie tracker
- a fake AI biohacking app
