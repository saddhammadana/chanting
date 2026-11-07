# 1. Developer account and signing keys

One-time setup. Both halves outlive any single release: the account is the
identity Google bills and reviews, and the signing key is the only thing that
proves a future update comes from the same developer.

**Status for this app: done.** The account exists, the keystore exists, and Play
App Signing is on. Read this when something about the account or the keys needs
checking, not on an ordinary release.

## The developer account

1. Register at https://play.google.com/console with a Google account.
2. Pay the one-time **$25** registration fee.
3. Complete identity verification; review usually takes 1–3 days.
4. Personal accounts created from late 2023 onward must run a closed test with
   **at least 12 testers for 14 continuous days** before they may publish to
   production. **Done for this app**: production access was granted in
   November 2026. The closed test that earned it is written up in the owner's
   local `progress-2026-10-08.md`.

### Trader status

Google requires every developer to declare whether they are a trader. For this
account it is still **outstanding**, with a deadline of **February 2027**; the
Console shows it as *Action required* on the home banner. Miss it and the
developer profile and every app are removed from Google Play globally. It asks
for trader or non-trader status and a review of the public developer profile, so
only the account owner can answer it.

## The upload keystore

Created once, for the lifetime of the app:

```sh
keytool -genkey -v -keystore ~/chanting-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias chanting
```

Back the `.jks` file and its passwords up in at least two places — an external
drive and private cloud storage, say. For this app the file lives at the repo
root as `release.jks`, which `.gitignore` keeps out of Git.

Copy `android/key.properties.example` to `android/key.properties` and fill in the
real passwords. That file is gitignored too and must never be committed. Its
`storeFile` points at the **container** path, because the release build runs in
Docker:

```properties
storeFile=/keystore/release.jks
```

## Play App Signing, and which key signs what

This app uses Play App Signing, so there are two keys and they are easy to
confuse:

| Key | Who holds it | What it does |
| --- | --- | --- |
| **App signing key** | Google | Signs the APKs Play actually delivers to devices. Google generated and stores it. |
| **Upload key** | You, as `release.jks` | Signs the `.aab` you upload. Play verifies it, strips it, and re-signs with the app signing key. |

Both fingerprints are on **Protected with Play → App signing** in the Console.
If an upload is rejected with a signing error, that page is where the expected
upload-key SHA-1 is; compare it with the local keystore:

```sh
keytool -list -v -keystore release.jks -alias chanting | grep SHA
```

A lost upload key can be reset from that same page (**Upload key → Request
reset**). A lost *app signing* key cannot be replaced for an app that is already
published — that is why the backups matter.

Next: [2. Build the .aab](02-build-the-aab.md).
