# Contributing

Chanting source code is open-source under the MIT License. Bundled fonts, sound
and artwork have separate terms; read "License and Reuse" in
[README](README.md) before copying assets out of the project.

## Development Setup

Install the Flutter SDK version documented in `README.md`, then run:

```sh
flutter pub get
sh tool/check.sh
```

`tool/check.sh` runs the docs link check, the formatter, the analyzer and the
tests, in the order CI runs them; `task check` is the same thing through
[Taskfile](Taskfile.yml). Add `--coverage` to also hold line coverage to the
minimum CI enforces.

To have Git run it for you before each commit:

```sh
git config core.hooksPath .githooks
```

It is opt-in because the tests take about half a minute; `git commit
--no-verify` skips it once.

The longer developer documentation is not published in this repository yet;
open an issue if something here is not enough to get a change through.

## Code Changes

- Keep the feature-first layout under `lib/features/`.
- One concern per file: a screen, a widget, or a controller, named after what it
  holds. Keep hand-written files under about 1000 lines; when a screen grows,
  move its pieces into that feature's `widgets/` folder as real widgets with
  plain imports, not `part` files.
- Format with `dart format`. CI rejects unformatted files.
- Prefer small, focused changes with tests covering the behavior touched.
- Keep tap targets at 48px and controls named. A new page goes into
  `appScreens()` in `test/app_screens.dart`, which is what the accessibility
  and text-scaling checks sweep; a hand-built control that the artwork draws
  smaller than 48 is wrapped in `TapTarget`.
- Text contrast is checked too. The artwork's gold and its secondary text are
  already under WCAG AA and are recorded as known gaps — do not add an entry to
  let new text join them.
- Keep comments concise and developer-facing comments in English. Keep long
  rationale out of source files.
- Do not add network, analytics, ads, accounts, or backend dependencies without a
  documented owner decision.
- Do not commit keystores, passwords, generated build outputs, or local editor
  state.

## Architecture Choices

The app is deliberately small and some choices differ from a textbook layered
architecture. They are intentional; please open an issue before changing them.

- One class per data concept. `Prayer` is both the JSON shape and the entity.
- `PrayerRepository` is a concrete class with no interface.
- No use-case layer. Business logic lives in Riverpod notifiers
  (`*_controller.dart`).
- Models are hand-written. No freezed, json_serializable, or build_runner;
  `gen-l10n` for UI strings is the one code generator.
- All routes live in `lib/router/app_router.dart`.
- Cross-feature data code goes in `lib/data/`, cross-page widgets in
  `lib/shared/widgets/`.
- Persistence is SharedPreferences only, and new dependencies need an owner
  decision.

## Prayer Data

`assets/data/*.json` is an export. The prayers are kept in a separate content
database and each export overwrites the four files whole, so a hand edit merged
here would be silently undone by the next one — do not send a pull request that
edits them.

Pull requests are welcome for everything around the data: the code that reads it
and the tests that guard it. Three rules hold for those:

- Preserve ids once published; user data refers to prayer and section ids.
- Keep verification status honest. Do not mark Pali, translation, or references
  as verified unless a human has checked them against the source edition.
- Update or add tests when changing schema, ordering, editions, or verification
  rules.

## Localization

UI strings live in `lib/l10n/*.arb`. Keep message keys and metadata blocks in
sync between Thai and English files. Prayer content is separate: each language is a
full edition under `assets/data/`.

## Pull Requests

Before opening a pull request:

```sh
sh tool/check.sh --coverage
```

Add a line to `CHANGELOG.md` under **Unreleased** for any change a user would
notice.

