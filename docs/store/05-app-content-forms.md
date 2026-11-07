# 5. App content forms

The declarations Play requires before it will publish anything: who the app is
for, what data it touches, and what each permission is for. Both the procedure
and the answers themselves are here, so there is one copy to keep current.

**Status for this app: complete.** The Console's **App content** page reads
*"You're all caught up"* — no declaration needs attention, and there are no
policy tasks against the app. Come back here when a new permission, dependency
or network call is added, because that is what invalidates these answers.

Console path: **Monitor and improve → Policy and programs → App content**. The
page has two tabs, *Need attention* and *Actioned*; an empty *Need attention*
tab is the pass condition. The store category and contact details are not there
— they live under **Grow users → Store presence → Store settings**.

## Data safety

| Question                                                              | Answer                                                                 |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Does your app collect or share any of the required user data types?   | **No**                                                                 |
| Is all of the user data collected by your app encrypted in transit?   | Not applicable — no data leaves the device                             |
| Do you provide a way for users to request that their data is deleted? | Not applicable — nothing is collected; uninstalling removes everything |

The claim is structural, not a policy promise: the app has no analytics
SDK, no ads SDK, no crash reporter, and no accounts, and its one network request
(below) carries no user data. Everything a user creates —
saved prayers, prayer sets, reading position, minutes practised per day, settings — is written to
`SharedPreferences` on the device and is never read by anything but the app.

Things a reviewer may ask about, and the honest answer to each:

- **Prayer updates** — the app downloads a newer prayer book from
  `dhammapanya.org` when one has been published: a `GET` with no identifier, at
  most once a day, switchable off in Settings. Nothing about the user or the
  device is sent, so it is not data collection. **Review the Data safety form
  against this before the first release that carries it**: "encrypted in
  transit" is still not applicable (no user data leaves the device), and the
  listing may no longer say the app never connects to the internet.

- **The error report menu** opens the user's own mail app with a pre-filled message
  (falling back to the clipboard). The app sends nothing itself; the user composes
  and sends a mail, and can edit or discard it. That is user-initiated
  communication, not data collection.
- **Prayer set sharing** encodes a set as a `CHANTING1.` code shown as a QR or copied
  to the clipboard. It travels device to device with no server involved.
- **Saving a QR image and reading one back** — "บันทึก QR Code" writes the share
  card to the user's photo library when pressed, and the scan page reads a QR from
  an image the user picks. Both stay on the device; the picked image is read and
  discarded, never stored by the app or sent anywhere.

## Privacy policy

`https://saddhammadana.github.io/chanting/privacy.html` — served by the GitHub Pages
workflow from `web/privacy.html`, which deploys itself when that file changes on
main. The privacy policy must be reachable **before** submitting, so run the
`pages` workflow by hand if the URL 404s.

**The published URL does not update by itself.** GitHub Pages deploys from the `pages`
workflow (`.github/workflows/pages.yml`), which only runs by hand — start it from
Actions → pages → Run workflow and re-open the URL before submitting, or the store
points at the old text.

### The policy covers the camera as of 23 August 2026

`web/privacy.html` used to be dated 15 July 2026 and listed only notifications and
start-after-reboot under "สิทธิ์ (Permissions) ที่แอปใช้" — the QR scanner landed after
that, so the shipped app requested `CAMERA` while the published policy was silent
about it. Play expects the policy to cover the permissions an app requests, and a
reviewer comparing the two can reject on it.

The page now carries a "การแชร์ชุดสวดและการสแกน QR" section (camera used only while
the scan screen is open, nothing stored or transmitted, sharing is device to device
with no server), lists the camera and the exact-alarm permission, says the same thing
in the English summary at the foot, and is dated 23 August 2026.

### The policy covers the photo library as of 25 September 2026

Saving the QR card to Photos and reading a QR from a picked image arrived in
September 2026. `web/privacy.html` says what each does (saved only on request,
picked image read on the device and not kept), lists the photo-library access
and the Android ≤ 10 storage permission, repeats both in the English summary,
and is dated 25 September 2026. Run the `pages` workflow, as above.

## Permissions in the shipped artifact

Verify against the artifact, never against `android/app/src/main/AndroidManifest.xml`:
manifest merging adds permissions from library dependencies that the app's own
manifest never names.

```sh
$ANDROID_HOME/build-tools/34.0.0/aapt2 dump permissions dist/app-release-arm64.apk
```

| Permission                                                | Where it comes from                                 | Why it is there                                                                                  |
| --------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `POST_NOTIFICATIONS`                                      | app manifest + `flutter_local_notifications`        | Daily morning/evening chanting reminders                                                         |
| `RECEIVE_BOOT_COMPLETED`                                  | app manifest                                        | Re-schedules the reminders after a restart                                                       |
| `SCHEDULE_EXACT_ALARM`                                    | app manifest                                        | Reminders fire at the minute the user set                                                        |
| `VIBRATE`                                                 | `flutter_local_notifications`                       | Reminder notifications, and the meditation/mala haptics                                          |
| `CAMERA`                                                  | `mobile_scanner`                                    | Scanning a prayer-set QR code, only while that screen is open. No image is stored or transmitted |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion` 29)             | app manifest, for `gal`                             | Saving the share QR card to the gallery on Android 10 and older; later versions need no permission |
| `INTERNET`                                                | app manifest                                        | Downloading a newer prayer book from dhammapanya.org. See below                                  |
| `ACCESS_NETWORK_STATE`                                    | merged in from a library, not from the app manifest | Not used by the app                                                                              |
| `th.chanting.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX                                            | Internal signature-level permission for a dynamically registered receiver; not user visible      |

### About `INTERNET`

The app makes one network request: it asks `dhammapanya.org` whether a newer prayer
book has been published and downloads it when one has (see
`docs/architecture/content-updates.md`). Everything else — fonts, the meditation
bell, the bundled prayer book — is an asset, and there is no analytics or ads.
`INTERNET` is declared in the app manifest for that request. Before October 2026 it
arrived only through manifest merging from the ML Kit / Play services stack behind
`mobile_scanner`, and the app did not use it; `ACCESS_NETWORK_STATE` still arrives
that way and is still unused.

The Play listing's permission list therefore shows "full network access". The listing
copy may say the app works without a connection, which is true; it must not say the
app never connects.

## Content rating questionnaire

- Category: **Reference, News, or Educational**
- No violence, no sexuality, no profanity, no controlled substances, no gambling
- No user-generated content, no user-to-user communication, no location sharing
- No personal information collected
- Expected result: **Everyone / 3+**

The prayer-set QR sharing is device-to-device transfer of a fixed list of prayer ids,
not user-to-user communication, and it carries no free text a user could write.

## Store settings

| Field              | Answer                                                                                         |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| App category       | Lifestyle (Books & Reference is the reasonable alternative)                                    |
| Tags               | Buddhism, meditation, reference                                                                |
| Target audience    | 13+ — avoids the child-directed-app requirements, and matches an app aimed at adults who chant |
| Contains ads       | No                                                                                             |
| In-app purchases   | No                                                                                             |
| Contact email      | saddhammadana@gmail.com                                                                        |
| Website            | https://saddhammadana.github.io/chanting/                                                     |
| Government app     | No                                                                                             |
| Financial features | None                                                                                           |

## Ads and monetisation

No ads SDK is present, and the "Contains ads" answer must stay **No**. If a build ever
adds one, this file, the listing copy in [4. Store listing](04-store-listing.md)
("ไม่มีโฆษณา" / "No ads"), and the Data safety form all
have to change together.

## When these answers go stale

| Change | Re-check |
| --- | --- |
| A new Android permission in the manifest | the permission table above, and Data safety |
| A new network call, or a new endpoint | Data safety, and `web/privacy.html` |
| A new dependency that collects anything | Data safety |
| Wording about ads or payments in the listing | "Contains ads" |
| Anything that changes `web/privacy.html` | run the `pages` workflow before submitting |

A listing that claims more privacy than the Data safety form declares is a
policy violation, not a marketing choice.

Next: [6. Create the release](06-create-release.md).
