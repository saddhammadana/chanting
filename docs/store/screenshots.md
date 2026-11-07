# Screenshots

Reference, not a step: what each image is, what size it has to be, and why the
set is captured the way it is. Running the capture is
[3. Store assets](03-store-assets.md).

Four sets of eight images, one per Play screenshot slot, captured from the
**release web build** of the app with the Thai UI and the light theme.

| Slot in Play           | Folder                          | Size      | Viewport            | Captured       |
| ---------------------- | ------------------------------- | --------- | ------------------- | -------------- |
| Phone                  | `assets/screenshots/`           | 1080×1920 | 432×768 dp at 2.5×  | 4 October 2026 |
| 7-inch tablet          | `assets/screenshots-tablet-7/`  | 1920×1080 | 960×540 dp at 2×    | 8 October 2026 |
| 10-inch tablet         | `assets/screenshots-tablet-10/` | 2560×1440 | 1280×720 dp at 2×   | 8 October 2026 |
| Chromebook ("desktop") | `assets/screenshots-desktop/`   | 2400×1350 | 1600×900 dp at 1.5× | 8 October 2026 |

One script captures all four: it walks the same shot list once per device
profile. Play asks for at least four images in each of the large-screen slots
and allows eight; eight is what every slot gets, so a tablet user sees the app
described as fully as a phone user does.

## Why the web build and not an emulator

The earlier set was captured from a release APK on the Pixel_3a emulator by a
script of `adb shell input tap` coordinates. Two things retired it:

- **Tap coordinates rot.** Every layout change moved a button out from under a
  tap, and a mistap still wrote a valid PNG — once, of YouTube. The October
  2026 redesign left the whole script pointing at a UI that no longer existed.
- **It needs a release APK**, which this Mac can only build in Docker.

`tool/store/capture_screenshots_web.cjs` drives the same Flutter UI in Chrome
instead. It reaches each screen **by its URL** and presses buttons **by their
accessibility names**, so a layout change does not misdirect it, and it seeds
the app's stored state directly rather than tapping its way to it.

What the web build cannot show: the Android status bar (the shots have none),
and anything that exists only on a phone. That is why the goal-and-reminders
page is not one of the eight — on the web it carries a "mobile only" notice
for reminders, which has no place in a store image. If a shot of a
phone-only screen is ever needed, it has to come from a device.

## Why those sizes

The phone slot takes each side 320–3840 px with the long side at most twice the
short one. 432×768 dp at 2.5× is exactly 1080×1920: a real layout at a real
phone size, not a crop.

**The three large-screen slots are stricter**: each side 1080–7680 px and the
aspect ratio exactly 16:9 landscape or 9:16 portrait. Every profile above
multiplies out to 16:9 on the nose, which is also why the dp viewports are the
sizes they are rather than a real device's own dp.

**The large screens are landscape, the phone is portrait.** Two reasons, and the
second is the one that decides it. Google asks large-screen listings to show the
app on a large screen, and this app has no tablet-only layout to show: content is
capped at 700–800 dp and centred (`ContentWidth`), so a portrait tablet viewport
renders a column the same width as the phone's and the shot says nothing the
phone shot did not. Landscape shows what a large screen actually gets — the
column held at a comfortable reading width on the painted ground. The second
reason is arithmetic: 9:16 at a 600 dp-wide 7-inch tablet needs a 1066.67 dp
viewport height, which cannot be set, so a portrait tablet shot would be off-ratio
or resampled.

**Chromebook is captured as Android, not as the web app.** What Play lists in
that slot is this Android app running on ChromeOS, so every profile sets
`isMobile`/`hasTouch` — otherwise Flutter reads the platform as macOS and draws
desktop scrollbars and hover chrome that the listed app does not have.

## Rules the shots follow

- **Release build**, Thai UI, light theme. Play shows one set of screenshots for
  every store locale unless per-locale images are uploaded; the prayers are
  Thai in every edition, so the Thai UI is the honest one to show. See
  the English copy in `04-store-listing.md`.
- **A fixed clock.** The script pins the app's clock to 07:30 today, so every
  run shows the morning greeting and the morning service on the goal card.
- **The same eight screens everywhere**, so the four sets tell one story and a
  screen that changes is re-captured in one run.
- **No personal data, and never a fresh install.** Each shot starts from an
  empty browser profile seeded with the same small state — a 15-minute goal
  with 9 minutes done, one prayer to continue, one prayer set. A fresh install
  would open the home tour and the goal page instead of the app.

## The shots

| File                    | Screen                | Shows                                                                                |
| ----------------------- | --------------------- | ------------------------------------------------------------------------------------ |
| `01-home.png`           | Home                  | Today's goal card and ring, the shortcuts, the "อ่านต่อ" card, the bottom bar          |
| `02-categories.png`     | All categories        | The shipped categories with their icons and prayer counts                            |
| `03-reading.png`        | Reader                | Romanized Pali and the Thai translation inline under each chant line                 |
| `04-continuous.png`     | Continuous reading    | The seam between two prayers on one scrolling page                                   |
| `05-mala.png`           | Reader + mala counter | The floating counter at 21 / 108 over a prayer                                       |
| `06-settings.png`       | Reading settings      | The live preview, text size, the lane switches and per-lane text colours             |
| `07-playlist-share.png` | Prayer set sharing    | The QR card of a three-prayer set                                                    |
| `08-meditation.png`     | Meditation timer      | The ring set to 10 minutes, the duration chips and the sitting options               |

`02` is the most replaceable if one has to make room, since the home screen
already shows how the book is organised.

Two shots are scrolled into place and each profile carries its own distance,
because a wider column wraps fewer lines and a shorter viewport holds less:

- **`wheel`** is how far `04` scrolls to land on the seam between two prayers.
- **`lift`** is how far `07` scrolls so the whole share card is in frame. It is
  0 everywhere but the 7-inch profile, whose 540 dp of height is shorter than
  the card and its heading together — that page is one composition and cannot be
  cut the way a list can.

Both are tuned by looking at the image, not computed. If a change to the reader
or the share page moves either shot off its mark, change the number in the
profile rather than the shot.

## Recapturing

The commands are in [3. Store assets](03-store-assets.md) — build the release
web app, install the capture driver once, run the script. They are kept there
rather than here so there is one copy to keep current.

What belongs with this file is the judgement after the run: **look at all 32
images**. The script cannot tell a correct screen from a wrong one, a splash
that had not faded, or a tooltip left over a button — the last of which
happened on the first run of `05`. If a shot has drifted off its mark, the
number to change is `wheel` or `lift` in that device's profile, above, not the
shot itself.
