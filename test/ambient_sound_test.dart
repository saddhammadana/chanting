import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/ambient_sound.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the timer asks of the nature-sound player; no audio backend.
class _RecordingAmbientPlayer extends AmbientSoundPlayer {
  final calls = <String>[];

  @override
  Future<void> start(AmbientSound sound, double volume) async =>
      calls.add('start ${sound.name}');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> setVolume(double volume) async =>
      calls.add('volume ${volume.toStringAsFixed(2)}');

  @override
  Future<void> stop({bool fade = false}) async =>
      calls.add(fade ? 'stop fade' : 'stop');

  @override
  Future<void> dispose() async {}
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    if (tester.any(finder)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<(PrefsService, _RecordingAmbientPlayer)> _pumpTimer(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'welcome_seen_version': 999,
    ...prefs,
  });
  final prefsService = await PrefsService.init();
  final player = _RecordingAmbientPlayer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsServiceProvider.overrideWithValue(prefsService),
        ambientSoundPlayerProvider.overrideWithValue(player),
      ],
      child: const ChantingApp(),
    ),
  );
  await _pumpUntilFound(tester, find.byKey(const ValueKey('home_meditation')));
  await tester.tap(find.byKey(const ValueKey('home_meditation')));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('meditation_start')));
  return (prefsService, player);
}

/// The nature sound that loops under a meditation sitting.
///
/// Same opt-in rule as the completion bell: an update must not start making
/// sound on its own, and every bundled recording must say where it came from.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  test('the default is no sound, and unknown names degrade to none', () async {
    SharedPreferences.setMockInitialValues({'meditation_minutes': 20});
    final prefs = await PrefsService.init();

    expect(prefs.getMeditationAmbient(), isNull);
    expect(
      AmbientSound.fromName(prefs.getMeditationAmbient()),
      AmbientSound.none,
    );
    // prefs can hold a value written by a newer build.
    for (final raw in ['', 'thunder', 'RAIN']) {
      expect(AmbientSound.fromName(raw), AmbientSound.none);
    }
  });

  test('every loop exists, is bundled, is an MP3, and stays small', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/sound/ambient/'));

    for (final sound in AmbientSound.values) {
      final asset = sound.asset;
      if (asset == null) continue;
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'ไม่มีไฟล์ $asset');
      expect(asset, startsWith('assets/sound/ambient/'));
      // iOS and macOS cannot play Ogg Vorbis.
      expect(asset, endsWith('.mp3'));
      // One minute of 96 kbps stereo is ~720 KB; these ride in every install.
      expect(
        file.lengthSync(),
        lessThan(1024 * 1024),
        reason: '$asset ใหญ่เกินไป (${file.lengthSync()} bytes)',
      );
    }
  });

  test('every loop records where it came from', () {
    final readme = File('assets/sound/README.md').readAsStringSync();
    for (final sound in AmbientSound.values) {
      final asset = sound.asset;
      if (asset == null) continue;
      expect(
        readme,
        contains(asset.split('/').last),
        reason: 'assets/sound/README.md ไม่ได้บันทึกที่มาของ $asset',
      );
    }
  });

  testWidgets('a chosen sound follows the sitting: start, pause, end', (
    tester,
  ) async {
    final (prefs, player) = await _pumpTimer(tester);

    await tester.tap(find.byKey(const ValueKey('meditation_ambient')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meditation_option_AmbientSound.rain')),
    );
    await tester.pumpAndSettle();
    expect(prefs.getMeditationAmbient(), 'rain');
    // Picked on setup, the sound is heard for a moment so it is not chosen
    // blind, then eases out and waits for the clock.
    expect(player.calls.last, 'start rain');
    await tester.pump(const Duration(seconds: 7));
    expect(player.calls.last, 'stop fade');
    player.calls.clear();

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(player.calls, ['start rain']);

    await tester.tap(find.byKey(const ValueKey('meditation_pause')));
    await tester.pump();
    expect(player.calls.last, 'pause');

    await tester.tap(find.byKey(const ValueKey('meditation_resume')));
    await tester.pump();
    expect(player.calls.last, 'start rain');

    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'stop');
  });

  testWidgets('the session card switches sound and sets the volume', (
    tester,
  ) async {
    final (prefs, player) = await _pumpTimer(
      tester,
      prefs: {'meditation_ambient': 'forestStream'},
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(player.calls, ['start forestStream']);

    await tester.tap(find.byKey(const ValueKey('meditation_ambient_pick')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meditation_option_AmbientSound.seaWaves')),
    );
    await tester.pumpAndSettle();
    // Changed mid-sitting, the new loop takes over without a restart.
    expect(player.calls.last, 'start seaWaves');
    expect(prefs.getMeditationAmbient(), 'seaWaves');

    final slider = find.byKey(const ValueKey('meditation_ambient_volume'));
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.left + box.width * 0.9, box.center.dy));
    await tester.pump();
    expect(player.calls.last, startsWith('volume 0.'));
    final stored = prefs.getMeditationAmbientVolume();
    expect(stored, isNotNull);
    expect(stored, greaterThan(kAmbientDefaultVolume));

    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
  });

  testWidgets('running out the clock fades the sound instead of cutting it', (
    tester,
  ) async {
    final (_, player) = await _pumpTimer(
      tester,
      prefs: {'meditation_ambient': 'forestBirds', 'meditation_minutes': 1},
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    // Let the completion haptics finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
    expect(player.calls.last, 'stop fade');
  });

  testWidgets('with no sound chosen the volume slider is inert', (
    tester,
  ) async {
    final (_, player) = await _pumpTimer(tester);

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(player.calls, ['start none']);
    expect(
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('meditation_ambient_volume')),
          )
          .onChanged,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
  });
}
