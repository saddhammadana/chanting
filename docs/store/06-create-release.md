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

> This upload cannot be automated from here. The browser-automation bridge caps
> a file at 10 MB and this bundle is about 83 MB, and the repo has no Play
> Developer API service account configured. Until one is set up, a person has to
> drop the file in. Setting up the API is a one-time job: a Google Cloud service
> account, linked under **Setup → API access**, with release permissions.

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

The final button is **Save and publish** (or **Start rollout to Production**
when a staged percentage is chosen). Pressing it sends the release to Google
for review. Once it is approved, it goes live automatically unless managed
publishing is turned on. For this app managed publishing is **off**.

**Stop here and ask the owner before pressing it.** Everything up to and
including *Save as draft* is reversible; this is not.

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
