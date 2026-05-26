# App Building Strategy

These are the default conventions and architectural patterns for building this
Flutter app.

This document is meant for non-trivial app work: creating features, changing
architecture, touching persistence, adding platform integrations, or making
broad UI decisions. For tiny edits, follow the surrounding code style.

Follow these conventions unless the existing code or the task gives a clear
reason not to. If you deviate, leave a short note in the implementation or PR
explaining why.

---

## Core Principles

1. **Preserve user data.** Database filenames, schema migrations, and
   backup/restore behavior must be treated carefully.
2. **Keep intent documented.** Code shows how something works; design docs
   explain why it works that way.
3. **Prefer feature-based organization.** Code that changes together should live
   together.
4. **Keep business logic pure.** Logic should be testable without Flutter,
   Riverpod, widgets, or platform APIs.
5. **Use reactive data flow.** Database-backed UI should update automatically
   from Drift streams through Riverpod.
6. **Design for phone, tablet, and web from the start.** Do not assume portrait
   phone is the only layout.
7. **Make slow actions visible.** Any operation that may take noticeable time
   needs feedback.
8. **Centralize fragile choices.** App name, database filename, theme colors,
   emoji style, permissions, and platform setup should not be scattered.

---

## Repo Layout

The Flutter project lives in `app/`, not at the repo root. This keeps
`docs/`, `README.md`, and any future sibling code (firmware, scripts, shared
Dart packages) cleanly separated from Flutter-generated platform folders.

```text
.
├── app/                   ← Flutter project (pubspec.yaml, lib/, android/, ios/, web/)
├── docs/
│   └── design/
└── README.md
```

Run all Flutter commands from inside `app/`:

```bash
cd app
flutter pub get
flutter run
flutter analyze
dart run build_runner build
```

Target platforms are **android**, **ios**, and **web**. Web is kept for
hot-reload iteration on static UI; it cannot exercise the BT or recording
flow. Desktop platforms (windows, macos, linux) were removed; add back with
`flutter create --platforms=windows .` (from inside `app/`) if ever needed.

## Design Docs

Maintain a `docs/design/` folder alongside the code. This is where product and
architecture intent lives.

Suggested files:

```text
docs/design/
  README.md                 ← what this folder is and how to use it
  app-building-strategy.md  ← this file
  data-model.md             ← entities, fields, nullability, derived fields
  screens.md                ← screens, interactions, edge cases
  tech-stack.md             ← dependency choices and rejected alternatives
  todo.md                   ← ordered implementation tasks, MVP first

docs/development.md         ← how to run, test, build, and release
```

### todo.md

This file tracks what remains to be built, in priority order. It is the single
source of truth for "what's next."

Remove tasks when they are completed.

Add a task when you discover work that isn't captured yet.
