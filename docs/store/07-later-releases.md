# 7. Later releases

Everything above is set up once. An ordinary update is this list.

1. **Bump the version** in `pubspec.yaml` — both `x.y.z` and `+N` if the release
   means something to users, `+N` alone if it does not. See
   [2. Build the .aab](02-build-the-aab.md).
2. **Write the changelog** entry under `## [Unreleased]` in `CHANGELOG.md`.
3. **Decide about the what's-new sheet.** If the release has a notable
   user-facing feature, increment `kWelcomeSheetVersion` in
   `lib/features/prayer_list/widgets/welcome_sheet.dart` and replace the rows of
   `_whatsNew`. Existing users see that sheet once after updating; a fresh
   install gets the home tour instead (`spotlight_tour.dart`), so a feature that
   belongs on the tour needs a stop added in `PrayerListScreen._tourSteps`.
4. **Run the checks**: `sh tool/check.sh`.
5. **Build**: `rm -f android/local.properties && task aab`, with the keystore
   mount uncommented. Verify the artifact.
6. **Re-capture the screenshots** if the app looks different —
   [3. Store assets](03-store-assets.md) — and update the listing copy and the
   release-notes block in [4. Store listing](04-store-listing.md).
7. **Re-check the forms** if a permission, dependency or network call changed —
   [5. App content forms](05-app-content-forms.md).
8. **Create the release** — [6. Create the release](06-create-release.md).

## What usually gets forgotten

- The build number. Play rejects a repeat, and a number already sent to a test
  track is used up.
- `android/local.properties`, rewritten by any host `flutter` command between
  the checks and the build.
- The release notes, left as the `<th>` placeholder. The counter under the box
  reading *0 language* is the tell.
- The screenshots, after a UI change nobody thought was visible enough to
  matter.
