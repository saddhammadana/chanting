# Changelog

Notable changes to Chanting. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/). Prayer-content edits are tracked in
the data files' own history rather than listed here.

## [Unreleased]

To be released as 1.0.0, the first public release (`pubspec.yaml` is at
`1.0.0+1`).

### Added

- English edition of the prayer book beside the Thai one, and an English UI.
- Prayer sets: create and edit pages, sharing by QR code or copied code, and
  receiving by camera scan, image, or paste.
- Meditation timer with custom durations, an optional nature sound, and a
  completion bell with its own volume.
- Home dashboard with a daily practice goal, a time-based greeting, pinned
  tiles, a daily recommended prayer, and a first-launch tour.
- Reminders for four times of day, each with its own days of the week.
- Reading screen: text selection with "report this passage", a pinned display
  strip shared by both reading modes, and a choice of page colour.
- Settings hub with search, and separate pages for reading, goal, sound,
  language, and theme.
- Lotus launch screen on Android and iOS, and the same lotus as the loader on the web and in-app.
- Mala chant counter on the reading screen.
- Prayer updates: a corrected prayer book published from the dhamma admin
  reaches an installed app without a new version. Checked when the app opens,
  with a switch and a "check now" button under Settings. This is the app's
  only network request; the bundled prayer book still works offline.
- macOS desktop build.

### Changed

- The numerals inside the practice and meditation rings keep their size when
  the device is set to very large text, instead of outgrowing the ring.

- Dependencies updated, including the local-notification stack behind the
  reminders (flutter_local_notifications 19 to 22, flutter_timezone 4 to 5) and
  routing (go_router 17 to 18).

- Controls that the artwork draws small — the play discs in a prayer set, the
  gold start buttons, the duration chips, the weekday circles and the reset
  pill — now take a full-size touch target without changing what they draw.
- Prayer data is structured into parts and lines, and is maintained in a
  separate admin tool and exported into `assets/data/`.
- Categories are ordered lists of prayer ids, so a prayer can sit in more than
  one category at its own position in each.
- App messages are shown as tinted lotus toasts.
- Times and durations are picked on scroll wheels.
- The macOS app requires macOS 12 or later.

## Before the first public release

Internal builds were numbered up to 1.10.0 until the version was reset to 1.0.0
in August 2026 for the first public release. The source moved to GitHub in
October 2026 as a single import commit, so the history before that, and the
`v1.0.0` tag of the earlier numbering, are not in this repository.

Until that move the app was called SuatMon, with the application id
`th.suatmon.app` and prayer-set share codes starting `SUATMON1.`. It was renamed
Chanting (`th.chanting.app`, `CHANTING1.`) before anything was published, so no
installed copy or shared code carries the old names. The Thai name สวดมนต์ is
unchanged.

[Unreleased]: https://github.com/saddhammadana/chanting/commits/main
