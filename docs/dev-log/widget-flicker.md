# Widget Flicker Bug

Cautionary tale: the Home/Activity screens flickered on web (zone colors
blinking ~6×/sec). A comment in `recording_screen.dart` claimed Drift's web
query streams emit "occasional empty emissions during heavy sample writes," so
the first fix filtered empty athlete lists. Logging the raw stream disproved it
— emissions were never empty; the same non-empty list was re-emitting at frame
rate. A second log (with a stack trace) on the athlete write caught the real
cause: `AthleteProfileFields` wrote to the row unconditionally on `dispose`, and
the write re-fired the query stream, rebuilt the tree, unmounted the widget, and
wrote again — a write→rebuild→write loop that also blanked the athlete data. The
lesson: the log found in minutes what the plausible comment hid. See the "Beware
the write→rebuild→write loop with Drift streams" section in
`docs/design/app-building-strategy.md`.
