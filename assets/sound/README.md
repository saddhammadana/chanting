# App Audio

Chanting originally held an "offline and silent" position. The meditation
completion bell is the first exception, approved by the owner in August 2026
together with the `just_audio` dependency. See `docs/architecture/audio.md`.

Sound is optional, not mandatory. Users can choose sound, vibration, or silent in
Settings. The default remains vibration, matching the previous behavior so an app
update never starts making sound without the user's choice.

## singing_bowl.mp3

|                |                                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------- |
| Original title | Tibetan Bowl Struck #1                                                                                  |
| Recorder       | Joseph SARDIN                                                                                           |
| Source         | https://bigsoundbank.com/tibetan-bowl-struck-s1110.html                                                 |
| License        | **CC0 (public domain)** — usable for any purpose, including commercial use; attribution is not required |
| Original file  | 30 seconds · mono · 48 kHz · MP3 320 kbps (1.2 MB)                                                      |
| Bundled file   | 9 seconds · mono · 44.1 kHz · MP3 96 kbps (107 KB)                                                      |

**Processing:** trimmed to 9 seconds. The strike is in the first second and the
tail is already around -44 dB at second 8, effectively silent on phone speakers.
The last 1.5 seconds fade out to avoid an abrupt cut, then the file is re-encoded
at a smaller bitrate.

```
ffmpeg -i bowl_raw.mp3 -t 9 -af "afade=t=out:st=7.5:d=1.5" \
       -ac 1 -ar 44100 -codec:a libmp3lame -b:a 96k singing_bowl.mp3
```

**Why MP3, not OGG:** OGG Vorbis is smaller, but iOS and macOS cannot play it
through AVFoundation. MP3 is the one format that works across all six build
targets.

**CC0 does not require attribution, but the app credits it anyway.** The About
screen lists the source, just as it credits the Sarabun/Pridi fonts and prayer
sources in `meta.sources`. Recording provenance is a project practice, not only a
license obligation.

## ambient/ — nature loops for the meditation timer

Added October 2026 at the owner's request, from the session artwork
`design/mobile/icon/wait/02/Serene Thai Meditation Countdown Session.png`
("เสียงธรรมชาติ"). The loops are off by default; one plays only after the user
picks it on the meditation screen.

| Bundled file        | Original title            | Recorder         | Source                                                   | Segment used |
| ------------------- | ------------------------- | ---------------- | -------------------------------------------------------- | ------------ |
| `forest_stream.mp3` | Forest and Stream #1      | Pierre SIBANARCO | https://bigsoundbank.com/forest-and-stream-1-s2713.html  | 3:55–4:59    |
| `rain.mp3`          | Summer Rain on Terrace    | Joseph SARDIN    | https://bigsoundbank.com/summer-rain-on-terrace-s1019.html | 0:20–1:24  |
| `forest_birds.mp3`  | Forest #4                 | Joseph SARDIN    | https://bigsoundbank.com/forest-4-s2749.html             | 0:25–1:29    |
| `sea_waves.mp3`     | Small waves and beach #1  | Joseph SARDIN    | https://bigsoundbank.com/small-waves-and-beach-1-s1446.html | 1:00–2:04 |

**License:** every one is **CC0 (public domain)** on its source page, checked
on 3 October 2026. The MP3 download is `https://bigsoundbank.com/UPLOAD/mp3/<number>.mp3`,
where the number is the `s####` at the end of the page address.

**Bundled format:** 60 seconds · stereo · 44.1 kHz · MP3 96 kbps (~720 KB each,
~2.9 MB together).

**Processing:** the steadiest 64 seconds of each recording (lowest spread in
5-second RMS) is cut out, brought to about -24 LUFS with a fixed gain so the
four sit at the same level, and limited. The first 4 seconds are then
cross-faded onto the end, which makes the last sample run into the first one —
the file loops without a seam. `START` and `GAIN` per file:

| File                | Source number | `START` | `GAIN` |
| ------------------- | ------------- | ------- | ------ |
| `forest_stream.mp3` | 2713          | 235     | 3.3    |
| `rain.mp3`          | 1019          | 20      | 4.7    |
| `forest_birds.mp3`  | 2749          | 25      | -5.9   |
| `sea_waves.mp3`     | 1446          | 60      | -8.2   |

```
ffmpeg -ss $START -t 64 -i $NUMBER.mp3 -filter_complex \
  "[0:a]volume=${GAIN}dB,alimiter=limit=0.89:level=false,asplit[a][b]; \
   [a]atrim=4:64,asetpts=PTS-STARTPTS[body]; \
   [b]atrim=0:4,asetpts=PTS-STARTPTS[head]; \
   [body][head]acrossfade=d=4:c1=qsin:c2=qsin" \
  -ar 44100 -ac 2 -codec:a libmp3lame -b:a 96k ambient/$NAME.mp3
```

**Not yet checked by ear.** The segments were chosen from loudness
measurements, not by listening, so a passing car or a voice inside one would
not have been noticed. Listen to each loop once before a release; a different
`START` is the fix.

## Adding New Sounds

Every new sound must include three things: a reachable source, a redistributable
license such as CC0/CC BY/public domain, and a reproducible conversion command.
Add those details above. This follows the same provenance rule as
`meta.sources` in the prayer data: it must be possible to verify where the asset
came from.
