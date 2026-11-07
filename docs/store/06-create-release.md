# 6. Create the release

Putting the `.aab` on a track and sending it to Google. This is the only step
that changes what the public sees, and the last two clicks in it are hard to
take back.

Console path: **Test and release → Production** (or a test track) →
**Create new release**. If a draft already exists the button is disabled and the
draft is at **Releases → Edit release** instead; Play allows one draft per track.

### Which track

| Track | Who gets it | Use it for |
| --- | --- | --- |
| Internal testing | up to 100 named testers, no review wait | a build you want on a real phone in minutes |
| Closed testing | a named tester list or Google Group | the 12-testers-for-14-days gate, and anything you want feedback on before launch |
| Open testing | anyone who opts in from the store page | a public beta; ratings from it do not affect the public rating |
| Production | everyone in the chosen countries | the release |

Every track but internal goes through review. This app's closed track is named
**alpha** and holds `1 (1.0.0)`; production access has been granted, so a
release no longer has to pass through a test track first.

The page has two stages across the top: **1 Create release** and **2 Preview and
confirm**.

## Stage 1 — Create release

### App bundles

A panel headed *"N of 3 enhancements active"*, then the upload area. The three
enhancements are Play's own offers, not requirements:

| Enhancement | State for this app |
| --- | --- |
| Releases are signed by Google Play | **active** — this is Play App Signing, see [1. Account and signing](01-account-and-signing.md) |
| Automatic protection | off — Play's anti-tamper wrapper |
| Automatic app text translation | off — machine-translating the app's own strings |

Below that, **Drop app bundles here to upload**, with **Upload** and **Add from
library**.

- **Upload** / drag and drop — for a bundle Play has never seen.
- **Add from library** — picks a bundle already uploaded to this app. Use it
  when the file is on Play but the draft is empty, which happens if a previous
  draft was discarded.

To check what Play actually holds, go to **Test and release → Latest releases
and bundles → All app bundles** (`bundle-explorer-selector`). It lists every
version code with its upload date and release status, and it is the only
trustworthy answer to "did my upload land?" — the draft page shows an empty drop
zone whether the upload failed or was simply never made.

> **Uploading it without touching the mouse.** The browser-automation bridge
> caps a file at 10 MB and this bundle is about 83 MB, so the file cannot be
> handed to the page that way. It can still be done, because the bridge never
> has to carry the bytes: press **Upload** in the page, then drive the macOS
> open panel with AppleScript — Chrome reads the file itself. Done on
> 7 November 2026; three things have to be right.
>
> - **The Console tab must be the active tab in its window.** Chrome does not
>   open a file picker for a background tab, and the click looks like it did
>   nothing. `tell application "Google Chrome" to set active tab index of
>   window 1 to <n>` first.
> - **Do not type the path.** `keystroke` goes through the current input
>   source, and on a machine set to Thai every Latin letter arrives as `ฟ`
>   (the path came out `/ฟฟฟฟฟ/ฟฟฟ-ฟฟฟฟ/…`). Open the go-to-folder sheet with
>   `cmd+shift+g` and **set the text field's value directly**:
>   `set value of text field 1 of sheet 1 of sheet 1 of window 1 to thePath`,
>   then Return to accept the path and Return again to open the file.
> - **There is nothing to look at.** `screencapture` needs Screen Recording
>   permission, which this machine does not grant, so the panel is inspected
>   through System Events (`exists sheet 1 of window 1`) rather than by eye.
>
> The Play Developer API is still the clean answer for CI — a Google Cloud
> service account linked under **Setup → API access** with release
> permissions — and is a one-time job nobody has done yet.

### Release details

Two fields, and only the first is required.

**Release name** — required, **50 characters**, counter under the box. Play's
own help text: *"This is so you can identify this release, and isn't shown to
users on Google Play. We've suggested a name based on the first app bundle or
APK in this release, but you can edit it."*

It is internal bookkeeping, not user-facing copy. Play pre-fills it from the
bundle as `<versionCode> (<versionName>)` once one is attached. Keep that
convention — the closed test's release is named `1 (1.0.0)`, so build 2 should
be **`2 (1.0.0)`**. Do not put marketing words here; the Console release lists,
the submission history and the rollout screens all identify a release by this
string, and a date or a slogan makes them harder to read, not easier.

**Release notes** — optional to Play, and the only part of this page users ever
read. The box is pre-filled with one block per store listing language:

```text
<th>
Enter or paste your release notes for th here
</th>
```

Rules that are easy to get wrong:

- The language tags are part of the value. Write the text **between** them and
  leave the tags alone; delete a tag and that language loses its notes.
- One block per locale, and **only locales the listing already has**. Today this
  app offers `<th>` and nothing else, because `en-US` has not been added as a
  store listing language — see [4. Store listing](04-store-listing.md).
- **500 characters per language.** The ready-made text is in
  [4. Store listing](04-store-listing.md) under *Release notes*, already within the
  limit; paste it, do not retype it.
- The counter underneath reads *"Release notes provided for N language"*. It
  stays at 0 until there is real text inside a tag, which is the quickest way to
  spot that the placeholder was left in place.
- **Copy from a previous release** fills the box from an earlier release of the
  same app. Handy for a small patch; for a release with real changes, write new
  notes rather than shipping the previous version's.

### Buttons at the foot

| Button | What it does |
| --- | --- |
| **Discard changes** | throws away edits made since the page opened |
| **Discard draft release** (top right) | deletes the whole draft, bundle and all |
| **Save as draft** | keeps everything, publishes nothing — safe to use freely |
| **Next** | goes to stage 2; enabled once a bundle and a release name are present |

## Stage 2 — Preview and confirm

A read-only summary: the bundle, the countries, the release notes, and any
errors or warnings Play found. **Warnings do not block a release** — the
edge-to-edge notices against build 1 were warnings, and the app published around
them. Errors do block.

**Managed publishing is ON for this app**, and that changes the last step —
this page said the opposite until 7 November 2026, when the Console was read
instead of remembered. With it on there is no **Save and publish** here. The
final button is plain **Save**, and the footer says what it does: *"If you
save, changes will be saved in Publishing overview, ready for you to send for
review."* Nothing leaves the Console yet.

So the release goes out in two more steps, both on **Publishing overview**:

1. The saved release appears under **Changes not yet submitted for review**,
   beside any other pending change — a store-listing edit saved the same day
   lands in the same list. **Submit N changes for review** sends them
   together, after a confirm dialog, and the heading becomes *Changes in
   review*. Play first runs "quick checks for commonly found issues" (quoted
   at up to 14 minutes) and sends them to review once those pass.
2. When review approves them they do **not** go live. Managed publishing holds
   them under **Changes ready to publish** until somebody presses publish.

**Ask the owner before both presses.** Everything up to and including *Save*
is reversible; sending for review is not, and publishing even less so.

### The AI asset declaration

Saving a **store listing** change (not the release) stops at a **Review** step
with an *AI asset declaration* that has no default: *Don't label assets* or
*Label assets as created or edited using AI*. This is a regulatory statement
about where the images came from, so it is the owner's answer, not the
uploader's. For this app it is **label them** — the artwork was made with
Codex image generation.

Choosing it opens **Label AI-generated assets**, which lists the assets one by
one with a checkbox each: app icon, feature graphic, and the eight phone
screenshots of the locale being edited (the tablet and Chromebook sets are not
offered). The underlined line at the top reading *"Select all assets that were
generated or edited with AI"* is a **heading, not a select-all** — hovering it
shows a tooltip and nothing is ticked. Tick each one, then **Label assets and
submit**, which only records the labels; the listing still needs **Save**.

## After submitting

- **Publishing overview** shows what is in review and what has been approved.
- **Submission activity** (`publishing/submission-activity`) lists every
  submission with its submitted, approved and published timestamps — the
  countries change for this app went in at 8:44 AM and was live by 9:04 AM.
- Review usually takes 1–7 days for a first production release; later updates
  are often hours.
- Record what happened in a dated `progress-YYYY-MM-DD.md` in this folder.

## If Play rejects it

A rejection names the policy and the thing that broke it, and it arrives by
email and on **Policy status**. Three rules make the next attempt cheaper:

- **Read the actual finding before changing anything.** Most rejections for an
  app like this one are a mismatch rather than a defect: the listing claiming
  more privacy than the Data safety form declares, or the published privacy
  policy not mentioning a permission the app requests. Both are
  [5. App content forms](05-app-content-forms.md), and neither needs a new
  build.
- **A fix that is not in the binary does not need a new version code.** Edit
  the listing, the forms or `web/privacy.html` — remembering to run the `pages`
  workflow — and resubmit the same bundle.
- **A fix that is in the binary needs a new version code.** Play will not take
  the same number twice, even for a release it rejected.

An app can also be removed after it is live, which is the same process in
reverse: the Console names the policy, and the appeal link is on that page.

Next: [7. Later releases](07-later-releases.md).
