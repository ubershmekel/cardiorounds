# Todo

Implementation tasks in priority order. Delete lines that are done.

---

## Milestone 1 — Recording + Chart (MVP)

- Android: foreground service with a persistent notification to keep recording
  running while the phone is locked
- Tap to tag a moment or label during recording. Tap moments: Recovery start,
  Recovery end, Round start, Round end, Note, Other.
- Tap-to-tag button writes a `moment` point marker during recording
- Moment-label editing on review screen: drag, resize, add, delete
- Round detection (automatic effort period segmentation); stored as `round` span
  markers
- Recovery event detection button (Z5 → Z3 drop timing); stored as `recovery`
  span markers
- Span analysis like a recovery span would show HR slope, duration, and other
  metrics.
- Share individual workout via share sheet
- Export activity data to a portable file (JSON or CSV, or some other format)
- Import activity export file
- Import from backup file (sqlite db)
- Google Drive backup / restore
- Allow logging "distance" and "speed" for treadmill workouts

Open questions:

- Measure GPS location and do all the related stats?
