# Tech Stack

These are the default library choices for future Flutter apps. The goal is a
boring, dependable stack that supports offline-first mobile apps, keeps the UI
snappy, and avoids custom infrastructure unless the app actually needs it.

## Default App Stack

**Flutter** is the default app framework. It gives one codebase for Android,
iOS, and optional web support.

Use Flutter **Material** widgets for the UI system. They are fast to build with,
accessible by default, and easy to customize.

Use **Riverpod** for state management. It keeps dependencies explicit, supports
testable providers, and works well with reactive UI updates.

Use **go_router** for navigation. It supports declarative routing, deep links,
browser URLs on web, and nested routes when needed.

Use **Drift** with **SQLite** for local app data. Drift provides type-safe
queries, migrations, streams, and strong offline-first behavior.

Use **drift_flutter** to open the database. It handles native SQLite bundling
and platform-specific file locations through `driftDatabase(name: ...)`. The
older `sqlite3_flutter_libs` package is now a no-op shim and is not needed
directly — `package:sqlite3` 3.x bundles native libs itself.

Use Drift's web backend when the app targets browsers. This keeps the same
database layer across mobile and web.

Use **shared_preferences** for small local settings only. It is good for simple
flags, timestamps, and lightweight preferences, not primary app data.

Use **path_provider** for app document and cache directories. It is the standard
way to find platform-specific file locations.

Use **build_runner** for code generation. It runs Drift and Riverpod generators
from one standard tool.

Use **flutter_test** for unit and widget tests. It is the default test
foundation for Flutter apps.

Use **flutter_lints** for static analysis by default. The Riverpod-specific lint
plugins (`riverpod_lint` + `custom_lint`) are desirable but their analyzer pin
currently conflicts with `drift_dev`'s analyzer pin on any Riverpod version —
both can't coexist until the ecosystem realigns. Add them later as a focused
change. `flutter_lints` covers the common cases until then.

## Persistence

Use a local database as the source of truth for user-owned app data. For most
non-trivial apps, prefer **Drift** over ad hoc JSON files or raw SQL calls.

Recommended pattern:

- Store domain data in SQLite through Drift tables and DAOs/repositories.
- Expose database reads as streams where the UI should update automatically.
- Watch those streams through Riverpod providers.
- Keep business logic outside widgets so it can be tested without Flutter.
- Use Drift migrations for every schema change after release.
- Use `shared_preferences` only for tiny settings such as feature flags,
  timestamps, onboarding state, or selected theme.

Avoid storing primary app data only in JSON files once the data can grow, be
edited incrementally, or need migrations. JSON import/export is still useful for
backup, restore, debugging, and portability.

## Navigation

Use **go_router** for app navigation by default.

Recommended pattern:

- Define route names and paths in one router file.
- Keep screen construction simple; move loading and business logic into
  providers.
- Prefer URL-friendly routes when web support is planned.
- Use route parameters for entity IDs and query parameters for transient filters
  or modes.
- Prefer hash-based routes to make web hosting simpler.

## Platform Features

Use focused Flutter plugins for standard platform integrations:

- Use **share_plus** for share sheets and exporting files.
- Use **file_picker** for choosing import files from device storage.
- Use **url_launcher** for opening external links.
- Use **path_provider** for app document and cache directories.
- Use **google_sign_in** for Google account sign-in.
- Use **extension_google_sign_in_as_googleapis_auth** when Google sign-in needs
  to authenticate Google API clients.
- Use **googleapis** for Google Drive or other Google API calls.

For cloud backup, keep local data authoritative and treat cloud sync as a
portable backup/restore layer unless the product explicitly needs real-time
multi-device sync. A single user-visible backup file is easier to reason about
than hidden sync state.

## UI Assets And Polish

Use **flutter_svg** for logos and scalable icon assets that are not built into
Material.

Use **cupertino_icons** when iOS-flavored icons are needed.

Use **flutter_launcher_icons** to generate platform app icon assets from source
art.

Use **flutter_native_splash** to generate native launch screens consistently.

Use **flutter_animate** for transitions, emphasis, and small motion details.

Use **confetti** for milestone or success moments.

Animations should never block persistence or navigation. Trigger immediate UI
feedback first, then let database writes or backups complete in the background
when that is safe.

## Testing

Use tests to protect the parts of the app that would be expensive or risky to
debug manually:

- Unit test pure business logic, date math, migrations, import/export, and sync
  decisions.
- Widget test important screens, forms, empty states, and navigation flows.
- Test Drift queries and migrations with an in-memory database.
- Keep platform plugin calls behind small services so most behavior can be
  tested without a device.
