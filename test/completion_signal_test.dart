import 'dart:io';

import 'package:chanting/data/local/completion_signal.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the meditation timer announces the end of a session.
///
/// The app held an "offline, no audio" line until August 2026, so the rule that
/// matters most here is that sound is **opt-in**: someone who updates the app
/// must not suddenly get a bell. These are pure/prefs tests; the settings screen
/// and the timer are covered by widget tests.
void main() {
  test('the default is vibrate, the behaviour before sound existed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsService.init();

    expect(prefs.getCompletionSignal(), 'haptic');
    expect(
      CompletionSignal.fromName(prefs.getCompletionSignal()),
      CompletionSignal.haptic,
      reason: 'อัปเดตแอปแล้วต้องไม่มีเสียงดังขึ้นมาเอง',
    );
  });

  test('an existing user with no saved value also gets vibrate', () async {
    // Someone who used the timer before the setting existed has every other
    // meditation key set but not this one.
    SharedPreferences.setMockInitialValues({'meditation_minutes': 20});
    final prefs = await PrefsService.init();
    expect(prefs.getCompletionSignal(), 'haptic');
  });

  test('the choice round-trips through prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsService.init();

    for (final signal in CompletionSignal.values) {
      await prefs.setCompletionSignal(signal.name);
      expect(CompletionSignal.fromName(prefs.getCompletionSignal()), signal);
    }
  });

  test('an unknown stored value degrades to vibrate, never throws', () {
    // prefs can hold a value written by a newer build.
    for (final raw in ['', 'bell', 'gong', 'SOUND']) {
      expect(CompletionSignal.fromName(raw), CompletionSignal.haptic);
    }
  });

  test('silent produces nothing at all', () async {
    // No platform channel is touched, so this runs without a plugin backend.
    await CompletionSignalPlayer().play(CompletionSignal.silent);
  });

  test('the bundled bell exists, is declared, and is small', () {
    // The asset path is a string in Dart and a line in pubspec; nothing links
    // them, so a rename silently ships a timer with no bell.
    final file = File(CompletionSignalPlayer.asset);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'ไม่มีไฟล์ ${CompletionSignalPlayer.asset}',
    );

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains(CompletionSignalPlayer.asset),
      reason: 'ไฟล์เสียงไม่ได้ประกาศใน pubspec.yaml จึงไม่ถูก bundle ลงแอป',
    );

    // A completion bell riding in every install; 9 seconds of mono MP3 is
    // ~110 KB and there is no reason for it to grow into megabytes.
    expect(
      file.lengthSync(),
      lessThan(300 * 1024),
      reason: 'ไฟล์เสียงใหญ่เกินไป (${file.lengthSync()} bytes)',
    );

    // MP3, not OGG: iOS and macOS cannot play Ogg Vorbis, so the format is a
    // cross-platform requirement rather than a preference.
    expect(CompletionSignalPlayer.asset, endsWith('.mp3'));
  });

  test('the bell claims the audio session as a notification, not as music', () {
    // just_audio defaults to music-player settings, which on iOS take the
    // playback category and *stop* whatever another app was playing — a
    // nine-second bell would end someone's background music and never give it
    // back. Asserted against the source because the alternative is mocking a
    // platform channel, and what matters is that the configuration is not
    // quietly dropped.
    final src = File(
      'lib/data/local/completion_signal.dart',
    ).readAsStringSync();
    expect(
      src,
      contains('AudioSession.instance'),
      reason: 'ไม่ได้ตั้งค่า audio session — ระฆังจะไปหยุดเสียงของแอปอื่น',
    );
    expect(
      src,
      contains('AVAudioSessionCategoryOptions.mixWithOthers'),
      reason: 'ต้อง mix กับแอปอื่น ไม่ใช่แย่ง session',
    );
    expect(
      src,
      contains('AndroidAudioFocusGainType.gainTransientMayDuck'),
      reason: 'ฝั่ง Android ต้องหรี่เสียงแอปอื่นชั่วคราว ไม่ใช่ตัดทิ้ง',
    );
  });

  test('the sound file records where it came from', () {
    // CC0 needs no attribution, but an audio file with no provenance is one
    // nobody can re-check later. Same rule as meta.sources in the prayer file.
    final readme = File('assets/sound/README.md');
    expect(readme.existsSync(), isTrue);
    final text = readme.readAsStringSync();
    expect(text, contains('CC0'));
    expect(text, contains('bigsoundbank.com'));
    expect(text, contains('singing_bowl.mp3'));
  });
}
