# AGENTS.md

## Project Notes

- The app lives in `app/` and is a Flutter/Dart project. Run Dart and Flutter
  commands from that directory unless the task explicitly targets repo-level
  files.
- Keep business logic outside widgets when practical, and cover it with focused
  unit tests under `app/test/`.
- Do not edit generated output or build artifacts unless the user explicitly
  asks for regeneration.

## Design–implementation sync

- `docs/design/` has all the design documents. Keep them in sync with the code.
  If there is a gap then an explicit decision needs to be made by the human on
  whether to update the design or the implementation.
- For example, `docs/design/screens.md` is the authoritative description of
  every screen's UX. Keep it in sync with the implementation: when a screen's
  behaviour or visual structure changes, update the relevant section in that
  file in the same PR/commit.
- When adding a new screen or a significant new state to an existing screen,
  write its section in `screens.md` before or alongside the code — not after.

## Web Platform

- Web is a UI playground and fast iteration target, not a production build.
  Bluetooth and file-system features show fake data or a popup.
- Do not hide UI behind `kIsWeb` guards — always show the controls. So the
  layout and flow are still testable in a browser.

## iOS builds & deployment

- **Xcode Cloud handles CI/CD.** Pushing to `main` triggers a cloud build and upload to App Store Connect automatically — no need to run `flutter build ipa` or upload manually.

## Logging

- App logging is centralized in `app/lib/core/app_logger.dart`; use
  `appLog(tag, message)` instead of ad hoc `print` or `debugPrint` calls.
- Keep logger policy values as named constants near the top of
  `app_logger.dart`. Do not hide retention counts, byte limits, file names, or
  timing thresholds as literals in the middle of methods.
- When changing logger retention behavior, update or add tests in
  `app/test/app_logger_test.dart`.
- Preserve a useful export window for user support logs. Small limits such as a
  few hundred lines are usually too short for Bluetooth and workout-session
  debugging.
- File-backed logging should be best-effort and must not break app flows if log
  persistence fails.
