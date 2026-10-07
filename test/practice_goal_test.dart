import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/settings/settings_controller.dart';
import 'package:chanting/features/stats/practice_log_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show pumpApp, pumpUntilFound;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => appRouter.go('/'));

  group('PracticeLog', () {
    test('parses entries and skips malformed ones', () {
      final log = PracticeLog.fromEntries([
        '2026-09-05:600',
        '2026-09-06:0',
        'no-colon',
        '2026-09-07:abc',
        '2026-09-08:-5',
        ':60',
      ]);
      expect(log.secondsByDate, {'2026-09-05': 600, '2026-09-06': 0});
    });

    test('minutes floor to whole minutes', () {
      final log = PracticeLog.fromEntries(['2026-09-05:119']);
      expect(log.minutesOn('2026-09-05'), 1);
      expect(log.minutesOn('2026-09-04'), 0);
    });

    test('adding sums into the day and round-trips through entries', () {
      final log = PracticeLog.empty
          .adding('2026-09-05', 90)
          .adding('2026-09-05', 30)
          .adding('2026-09-06', 60);
      expect(log.secondsOn('2026-09-05'), 120);
      expect(PracticeLog.fromEntries(log.toEntries()).secondsByDate, {
        '2026-09-05': 120,
        '2026-09-06': 60,
      });
    });

    test('one session cannot contribute more than the cap', () {
      // A reading screen left open overnight must not claim the whole night.
      final log = PracticeLog.empty.adding('2026-09-05', 24 * 60 * 60);
      expect(log.secondsOn('2026-09-05'), kMaxSessionSeconds);
    });

    test('a non-positive session changes nothing', () {
      expect(PracticeLog.empty.adding('2026-09-05', 0).secondsByDate, isEmpty);
    });
  });

  testWidgets('the ring reports minutes chanted today against the goal', (
    tester,
  ) async {
    final today = isoDate(DateTime.now());
    await pumpApp(
      tester,
      openAll: false,
      extraPrefs: {
        'practice_seconds': ['$today:260'],
        'practice_goal_minutes': 20,
      },
    );

    // 260s is four whole minutes; a part-minute does not count yet.
    expect(find.textContaining('4 / 20', findRichText: true), findsOneWidget);
  });

  testWidgets('the goal chips persist and the home ring follows them', (
    tester,
  ) async {
    final prefs = await pumpApp(tester, openAll: false);
    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    // Settings is a hub; the daily goal lives on the goal sub-page, as preset
    // chips plus a custom stepper rather than the slider it used to be.
    await pumpUntilFound(tester, find.byKey(const ValueKey('settings_goal')));
    await tester.tap(find.byKey(const ValueKey('settings_goal')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('goal_minutes_30')));

    // Nothing stored yet, so the default preset is the one showing.
    expect(prefs.getPracticeGoalMinutes(), isNull);
    expect(
      find.byKey(const ValueKey('goal_minutes_$kPracticeGoalDefault')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('goal_minutes_30')));
    await tester.pumpAndSettle();
    expect(prefs.getPracticeGoalMinutes(), 30);

    // The goal sub-page is pushed above the shell, so the bottom nav is not on
    // screen to tap back to home.
    appRouter.go('/');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home_practice_hero')),
    );
    expect(find.textContaining('/ 30', findRichText: true), findsOneWidget);
  });

  testWidgets('leaving the reading screen banks the session without throwing', (
    tester,
  ) async {
    final prefs = await pumpApp(tester, openAll: false);
    // Any prayer will do; take the first one in the file rather than pin an id.
    final prayers =
        jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
            as List;
    final id = (prayers.first as Map)['id'] as String;
    appRouter.go('/prayer/$id');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // The session clock is wall time, which pump does not advance.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );

    // Disposing the screen used to notify the home ring mid-finalizeTree.
    appRouter.go('/');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home_practice_hero')),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(prefs.getPracticeSeconds(), isNotEmpty);
  });

  test('a recorded session reaches prefs as today\'s total', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await PrefsService.init();
    final container = ProviderContainer(
      overrides: [prefsServiceProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final day = DateTime(2026, 9, 7);
    container
        .read(practiceLogControllerProvider.notifier)
        .addSeconds(200, now: day);
    container
        .read(practiceLogControllerProvider.notifier)
        .addSeconds(100, now: day);

    expect(prefs.getPracticeSeconds(), ['2026-09-07:300']);
    expect(
      container.read(practiceLogControllerProvider).minutesOn('2026-09-07'),
      5,
    );
  });

  test('the goal falls back to the default and is clamped on read', () async {
    SharedPreferences.setMockInitialValues({'practice_goal_minutes': 9999});
    final prefs = await PrefsService.init();
    final container = ProviderContainer(
      overrides: [prefsServiceProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(
      container.read(settingsControllerProvider).practiceGoalMinutes,
      kPracticeGoalMax,
    );
  });
}
