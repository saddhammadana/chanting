# Play Store release pack

Everything the Google Play listing needs that is not the app binary: the
procedure, the copy, the form answers, and the images.

The numbered files are the release itself, in the order you do them. The rest
is reference they point at.

## The steps

| File | What it covers | Needed on an ordinary release? |
| --- | --- | --- |
| [01-account-and-signing.md](01-account-and-signing.md) | Developer account, trader status, the upload keystore, Play App Signing | no — one-time, read it when a key or the account is in question |
| [02-build-the-aab.md](02-build-the-aab.md) | Version bump, `task aab`, the two traps that cost a build, verifying the artifact | **yes** |
| [03-store-assets.md](03-store-assets.md) | Regenerating the icon, feature graphic and four screenshot sets | only after a visible UI change |
| [04-store-listing.md](04-store-listing.md) | The store page: where each Play field comes from, and the Thai and English copy itself | only when the wording changes |
| [05-app-content-forms.md](05-app-content-forms.md) | Data safety, privacy policy, content rating, audience, category, and the permission inventory — the answers themselves, not just the procedure | only when a permission or a network call changes |
| [06-create-release.md](06-create-release.md) | The release form itself: app bundle, **Release details**, preview, review, publish | **yes** |
| [07-later-releases.md](07-later-releases.md) | The short list for an update, and what usually gets forgotten | **yes** — start here |

## Reference

| File | What it is |
| --- | --- |
| [screenshots.md](screenshots.md) | What each of the 32 images is, the size each slot needs, and why the set is captured from the web build |

A dated `progress-YYYY-MM-DD.md` beside these files is a snapshot, not a
procedure: what the Console showed on one day and what was done about it. Add a
new one rather than editing an old one. **Those files are not published**: they
carry the developer-account and app ids, Console deep links and install
figures, which belong to the owner rather than to the repository.

## Where things stand

Production access is granted, the store listing is live, and every App content
declaration is complete. What is left is the trader-status declaration, which
only the account owner can answer, and the production release itself. The
owner's local `progress-2026-11-06.md` has the detail.

## Language rule for this folder

Developer-facing prose here is **English**, like every other document under
`docs/`, most of which is kept local to the maintainer's checkout rather than
published here. The Thai copy inside [04-store-listing.md](04-store-listing.md) is the
exception on purpose: it is user-facing copy that ships to Thai users in the
store, so it is written in Thai and must not be "translated for consistency".
The English copy in the same file is that copy for the `en-US` store locale,
not a translation of the developer prose around it.

## Asset specification

| Asset                  | Play requirement                                                                         | What we ship                                |
| ---------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------- |
| App icon               | 512×512 PNG, 32-bit                                                                      | 512×512 PNG from `assets/icon/app_icon.png` |
| Feature graphic        | 1024×500 PNG/JPEG                                                                        | 1024×500 PNG                                |
| Phone screenshots      | 2–8 images, PNG/JPEG, each side 320–3840 px, long side no more than twice the short side | 8 × 1080×1920 PNG, portrait                 |
| 7-inch tablet          | 4–8 images, each side 1080–7680 px, exactly 16:9 or 9:16                                 | 8 × 1920×1080 PNG, landscape                |
| 10-inch tablet         | the same                                                                                 | 8 × 2560×1440 PNG, landscape                |
| Chromebook ("desktop") | the same                                                                                 | 8 × 2400×1350 PNG, landscape                |

Two rows of that table are easy to get wrong. A tall phone's own resolution
(1080×2220, say) has a long side more than twice the short one and is **out of
spec for the phone slot**; the capture script renders at 432×768 dp and 2.5×,
which is 1080×1920 exactly, so what is captured is a real layout at a real phone
size rather than a crop. The three large-screen slots then want the ratio
**exactly** 16:9 or 9:16 and nothing under 1080 px, which the phone's own rule
would happily allow — each large profile's viewport times its scale is 16:9 on
the nose. Why those sets are landscape, and why they are captured as the Android
app rather than as the web app, is in [screenshots.md](screenshots.md).

The images live under `assets/`: `icon-512.png`, `feature-graphic.png`, and
`screenshots/`, `screenshots-tablet-7/`, `screenshots-tablet-10/`,
`screenshots-desktop/`, eight shots each. They are committed rather than
generated on demand, because the release does not build them and a reviewer
should be able to see what was submitted without building the app.
