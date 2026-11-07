# 3. Store assets

Produces the images Play shows on the store page: the icon, the feature graphic
and four sets of screenshots. Only needed when the app's look has changed —
otherwise what is in `assets/` already matches the live listing.

Written in English like the rest of `docs/`. The one
Thai in this folder is the store copy inside `04-store-listing.md`, because
that is written for users.

## Prerequisites

Install once; all of it is already set up on the macOS dev machine.

| Tool                                                                     | Needed for                                                              | Check                                        |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------- | -------------------------------------------- |
| Docker Desktop                                                           | Building the release APK/AAB for upload (a local `flutter build apk` fails) | `docker info`                            |
| Node.js + `playwright-core`                                              | Driving the app for the screenshots                                     | `node -v`                                    |
| ImageMagick                                                              | Resizing the icon and checking image sizes                              | `magick -version`                            |
| Google Chrome                                                            | Rendering the feature graphic and the screenshots                       | `ls "/Applications/Google Chrome.app"`       |
| Python 3                                                                 | Checking the listing character limits                                   | `python3 -V`                                 |

## 1. Build the release web app

```sh
flutter build web --release
# → build/web
```

Under a minute. The screenshots come from this build; see
[Phone screenshots](screenshots.md) for why it is the web build and what that
cannot show.

## 2. Install the capture driver (once)

```sh
npm i --prefix /tmp/chanting-shots playwright-core@1.38.1
```

It lives outside the repo because the app has no Node project of its own.

## 3. Capture the screenshots

```sh
NODE_PATH=/tmp/chanting-shots/node_modules node tool/store/capture_screenshots_web.cjs
```

About six minutes. It will:

1. serve `build/web` on port 8791 and open it in Chrome once per device profile
   — the phone at 432×768 dp and 2.5× (exactly 1080×1920), then the three
   large screens in landscape at exactly 16:9, which is what Play's tablet and
   Chromebook slots require (see `screenshots.md`),
2. start every shot from an empty profile seeded with the same stored state,
   with the app's clock pinned to 07:30,
3. open each screen by its URL, press what needs pressing by its accessibility
   name, and write `01`–`08` into each of

   | Play slot              | Folder under `docs/store/assets/` |
   | ---------------------- | --------------------------------- |
   | Phone                  | `screenshots/`                    |
   | 7-inch tablet          | `screenshots-tablet-7/`           |
   | 10-inch tablet         | `screenshots-tablet-10/`          |
   | Chromebook ("desktop") | `screenshots-desktop/`            |

`DEVICE=tablet-7` captures one profile and `ONLY=05` one shot, so a single image
is cheap to redo without waiting for the other 31.

**Then look at all 32 images.** The script cannot tell a correct screen from a
wrong one — and the large-screen sets are the layout nobody develops against day
to day.

## 4. Render the feature graphic and the icon

```sh
tool/store/make_feature_graphic.sh
# → docs/store/assets/feature-graphic.png (1024×500)
# → docs/store/assets/icon-512.png (512×512)
```

A couple of seconds. Edit `tool/store/feature-graphic.html` to change the wording or
layout — it uses the app's own fonts and colours over `file://`, nothing is fetched.

## Troubleshooting

| Symptom                                                   | Cause and fix                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `no build/web`                                            | Step 1 was skipped. `flutter build web --release`.                                                                                  |
| `Cannot find module 'playwright-core'`                    | Step 2 was skipped, or `NODE_PATH` does not point at its `node_modules`.                                                            |
| A shot is the lotus loading screen                        | The app had not finished starting. Raise the wait in `open()`.                                                                      |
| `no menuitem labelled …` or a button wait times out       | A label changed in the `.arb` files. Update the name in the script's `shots` list.                                                  |
| A tooltip is drawn over a button                          | The click that opened a menu left the pointer on it. Move the pointer away and wait, as the `05` shot does.                         |
| Play rejects a screenshot's dimensions                    | A profile's viewport or scale was changed. Each one must multiply out to 1080×1920 (phone) or an exact 16:9 (tablets, Chromebook).  |
| A large-screen shot is cut off at the fold                | A short landscape viewport. Scrolling pages may end mid-list; a page that is one composition gets its own `lift` in the profile.    |
| Thai text renders as boxes in the feature graphic         | Chrome could not read the fonts over `file://`; keep `--allow-file-access-from-files` in `make_feature_graphic.sh`.                                                                                                                                                             |

## When to redo what

| Change                       | Redo                                                                          |
| ---------------------------- | ----------------------------------------------------------------------------- |
| Any visible UI change        | Section 3 here (all four screenshot sets)                                     |
| App icon artwork             | Section 4 here                                                                |
| Wording of the listing       | [4. Store listing](04-store-listing.md)                                       |
| New user-facing feature      | Section 3 here, plus the listing copy and the release notes                   |
| New permission or dependency | [5. App content forms](05-app-content-forms.md), checked against the built APK with `aapt2 dump permissions` |

Next: [4. Store listing](04-store-listing.md).
