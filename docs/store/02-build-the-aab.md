# 2. Build the .aab

Produces `dist/app-release.aab`, the single file Play wants. Everything here
runs on the dev machine; nothing touches the Console yet.

## Before building: the version

Bump `version` in `pubspec.yaml`. The number after `+` is the **version code**
and must be higher than anything already uploaded — Play rejects a repeat, and
a build already sent to *any* track counts, including a closed test.

```yaml
version: 1.0.0+2
```

The part before `+` is the version name users see. It only has to change when
the release means something to users; the build number has to change every time.
Record what moved in `CHANGELOG.md` under `## [Unreleased]`.

## Run the checks first

```sh
sh tool/check.sh
```

Format, analyze, and the whole test suite — the same script CI runs. Run it
**before** the build, not after: see the `local.properties` trap below.

## Build

A local `flutter build` does not work on the macOS dev machine: Gradle 9.1
refuses the only JDK installed there, which is newer than it accepts and fails
as *"Unsupported class file major version"*. (It was Java 26 when this was
written; `java -version` reported 27 in November 2026, so the number in the
message moves with the JDK.) Build in Docker, which is the documented path
anyway and matches CI. The Taskfile wraps it, including the guards that stop two builds sharing one
Gradle cache:

```sh
task aab        # dist/app-release.aab, for Play
task apk:arm64  # dist/app-release-arm64.apk, for putting on a phone
```

Docker Desktop has to be running first; `task` reports a stopped daemon as a
compose failure rather than saying so. A cold cache takes six minutes or so.

## Two traps that cost a build each

**`android/local.properties` carries host paths into the container.** It is
generated and gitignored, and it holds absolute paths. Every `flutter` command
run on the host — including `flutter test` and `flutter analyze` — rewrites it
with the host's SDK locations, which do not exist inside the container. The
build then dies early with:

```text
Included build '/opt/homebrew/share/flutter/packages/flutter_tools/gradle' does not exist.
```

Delete it and build again; the container regenerates its own:

```sh
rm -f android/local.properties && task aab
```

**The keystore mount is committed commented out.** `docker-compose.yml` ends its
volume list with

```yaml
    # Real signing: uncomment and place release.jks at the project root.
    # - ./release.jks:/keystore/release.jks:ro
```

so that a clone without the key still builds, debug-signed. A build for Play
needs that line uncommented, with `release.jks` at the repo root. Leave it
commented and Gradle runs the full three minutes and only then fails at
`:app:validateSigningRelease` with *Keystore file '/keystore/release.jks' not
found*. The line is deliberately not committed uncommented, because it would
break any build on a machine without the key — uncomment it to build, and put
the repo back afterwards.

## Verify the artifact before uploading

**A failed build leaves the previous `dist/app-release.aab` untouched.** The
file is only copied out of the container on success, so after a build that died
at `validateSigningRelease` the old bundle is still sitting there, with the old
version code inside it and nothing on screen saying so. Check its timestamp
before uploading:

```sh
ls -l dist/app-release.aab
```

A debug-signed, stale or wrongly-numbered bundle wastes an upload round trip.
Check all three in one go:

```sh
python3 - <<'PY'
import zipfile
z = zipfile.ZipFile('dist/app-release.aab')
sigs = [n for n in z.namelist()
        if n.startswith('META-INF/') and n.endswith(('.RSA', '.DSA', '.EC'))]
m = z.read('base/manifest/AndroidManifest.xml')
i = m.find(b'versionCode')
print('signature :', sigs or 'NONE — debug build')
print('manifest  :', m[i:i+40])
PY
```

What to look for:

- **signature** — a `META-INF/CHANTING.RSA`. `NONE`, or a `CERT.RSA` from the
  debug key, means the keystore mount was not picked up.
- **manifest** — the bytes after `versionCode` encode the number; `\x08\x02`
  is 2. `versionName` follows a little later in plain text.
- **size** — around 83 MB for this app. A few megabytes means the asset bundle
  did not make it in.

Next: [3. Store assets](03-store-assets.md), or jump straight to
[6. Create the release](06-create-release.md) if the listing is already live.
