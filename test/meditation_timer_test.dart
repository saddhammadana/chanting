import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/stats/practice_log_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pump until the finder appears to tolerate async asset loading timing.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 50,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (tester.any(finder)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<PrefsService> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
  final prefsService = await PrefsService.init();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      child: const ChantingApp(),
    ),
  );
  await pumpUntilFound(
    tester,
    find.byKey(const ValueKey('home_practice_hero')),
  );
  return prefsService;
}

/// The meditation screen's own bar. `find.byType(AppBar)` also matches the
/// home route sitting underneath the pushed one.
final meditationBar = find.descendant(
  of: find.byType(AppBar),
  matching: find.text('นั่งสมาธิ'),
);

/// How visible the session's receding controls currently are.
double sessionControlsOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('meditation_end_practice')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone.
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  testWidgets('phone layout keeps setup and session controls reachable', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('meditation_start')));
    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('meditation_pause')));
    await tester.tap(find.byKey(const ValueKey('meditation_pause')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('meditation_end_practice')),
    );
    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meditation_start')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening from the home card and selecting minutes persists the value',
    (tester) async {
      final prefsService = await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('home_meditation')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('meditation_start')),
      );
      // Default is 10 minutes when no value has been set.
      expect(find.text('10:00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meditation_preset_30')));
      await tester.pump();
      expect(find.text('30:00'), findsOneWidget);
      expect(prefsService.getMeditationMinutes(), 30);
    },
  );

  testWidgets('custom duration chip accepts minutes and persists the value', (
    tester,
  ) async {
    final prefsService = await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    // Open the custom wheels, turn the minutes to 45, and confirm; the OK
    // button is Material-localized. It opens on the current preset, so the
    // hours wheel is set too.
    await tester.tap(find.byKey(const ValueKey('meditation_custom')));
    await tester.pump();
    for (final (key, item) in [('hours_wheel', 0), ('minutes_wheel', 45)]) {
      tester
          .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
          .scrollController!
          .jumpToItem(item);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pump();

    // Countdown is set to 45 minutes and the value is saved.
    expect(find.text('45:00'), findsOneWidget);
    expect(prefsService.getMeditationMinutes(), 45);
    // The custom chip becomes selected and shows the minute count instead of its label.
    expect(find.text('45 นาที'), findsOneWidget);
    expect(find.text('กำหนดเอง'), findsNothing);
  });

  testWidgets('custom duration takes hours, and never zero', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );
    FixedExtentScrollController wheel(String key) => tester
        .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
        .scrollController!;

    await tester.tap(find.byKey(const ValueKey('meditation_custom')));
    await tester.pump();
    wheel('hours_wheel').jumpToItem(5);
    wheel('minutes_wheel').jumpToItem(30);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    expect(find.text('5:30:00'), findsOneWidget);
    // The chip says it in hours too, not as 330 minutes.
    expect(find.text('5 ชม. 30 นาที'), findsOneWidget);

    // 0:00 is not a sitting: the minutes wheel turns itself on to 0:01.
    await tester.tap(find.byKey(const ValueKey('meditation_custom')));
    await tester.pump();
    wheel('hours_wheel').jumpToItem(0);
    wheel('minutes_wheel').jumpToItem(0);
    await tester.pumpAndSettle();
    expect(wheel('minutes_wheel').selectedItem % 60, 1);
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('start pause and restart update the countdown correctly', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_preset_5')));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('04:57'), findsOneWidget);

    // The focused session screen replaces setup controls while counting down.
    expect(find.byKey(const ValueKey('meditation_session')), findsOneWidget);
    expect(find.byKey(const ValueKey('meditation_preset_10')), findsNothing);
    expect(find.text('04:57'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_pause')));
    await tester.pump();
    expect(find.text('เริ่มต่อ'), findsOneWidget);
    // Time must not keep advancing while paused.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('04:57'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_reset')));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('meditation_start')), findsOneWidget);
  });

  testWidgets('sitting options persist and the countdown runs with them set', (
    tester,
  ) async {
    final prefsService = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    // Start signal defaults to silence so the timer gains no sound for anyone
    // already using it.
    expect(prefsService.getMeditationStartSignal(), isNull);
    await tester.tap(find.byKey(const ValueKey('meditation_start_signal')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meditation_option_CompletionSignal.sound')),
    );
    await tester.pumpAndSettle();
    expect(prefsService.getMeditationStartSignal(), 'sound');

    // The end signal row writes the same setting Settings does.
    await tester.tap(find.byKey(const ValueKey('meditation_end_signal')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meditation_option_CompletionSignal.silent')),
    );
    await tester.pumpAndSettle();
    expect(prefsService.getCompletionSignal(), 'silent');

    await tester.tap(find.byKey(const ValueKey('meditation_preset_5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    await tester.pump(const Duration(minutes: 3, seconds: 1));
    expect(find.text('01:59'), findsOneWidget);
    // Three minutes in, the controls have long receded; a tap brings them back.
    await tester.tap(find.byKey(const ValueKey('meditation_session_surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meditation_reset')));
    await tester.pumpAndSettle();
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('time sat counts toward the daily goal, ended early or not', (
    tester,
  ) async {
    final prefsService = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    int minutesToday() => PracticeLog.fromEntries(
      prefsService.getPracticeSeconds(),
    ).minutesOn(isoDate(DateTime.now()));
    expect(minutesToday(), 0);

    await tester.tap(find.byKey(const ValueKey('meditation_preset_5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2, seconds: 5));
    // The controls have receded by now; a tap brings them back.
    await tester.tap(find.byKey(const ValueKey('meditation_session_surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();

    // Two minutes were sat before ending early, and they are kept.
    expect(minutesToday(), 2);
  });

  testWidgets('end practice returns from the focused session to setup', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(find.bySemanticsLabel('กำลังนั่งสมาธิ'), findsOneWidget);
    expect(find.text('เวลาคงเหลือ'), findsOneWidget);
    expect(meditationBar, findsNothing);
    expect(
      find.byKey(const ValueKey('meditation_end_practice')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('นั่งสมาธิ'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('meditation_start')), findsOneWidget);
  });

  testWidgets('a sitting sheds the bar and the system back lands on setup', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );
    expect(meditationBar, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(meditationBar, findsNothing);

    // Popping mid-sitting used to leave the screen and cancel the ticker with
    // nothing said. It lands on setup instead, with the duration intact.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(find.byKey(const ValueKey('meditation_start')), findsOneWidget);
    expect(meditationBar, findsOneWidget);
  });

  testWidgets('settling the ring adds no scroll to a sitting', (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    final list = find.byKey(const ValueKey('meditation_session'));
    final before = tester.widget<ListView>(list).padding;

    // The ring settles toward the middle by being moved, not by being given
    // more padding — padding would make the list taller than the screen and
    // hand the sitting a scroll it did not have a moment earlier.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(sessionControlsOpacity(tester), 0);
    expect(tester.widget<ListView>(list).padding, before);

    await tester.tap(find.byKey(const ValueKey('meditation_session_surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
  });

  testWidgets('an option picker opened mid-sitting follows the dim ground', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    // `showDialog` builds from the navigator, above the theme the sitting
    // installs, so this comes up cream on a dark screen if nothing hands it on.
    await tester.tap(find.byKey(const ValueKey('meditation_session_signal')));
    await tester.pumpAndSettle();

    final dialog = find.byType(SimpleDialog);
    expect(dialog, findsOneWidget);
    expect(Theme.of(tester.element(dialog)).brightness, Brightness.dark);

    await tester.tap(
      find.byKey(const ValueKey('meditation_option_CompletionSignal.silent')),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('controls recede while sitting and a tap brings them back', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    // The buttons stay up long enough to be reached without chasing them.
    expect(sessionControlsOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(sessionControlsOpacity(tester), 0);
    expect(find.byKey(const ValueKey('meditation_tap_hint')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_session_surface')));
    await tester.pumpAndSettle();
    expect(sessionControlsOpacity(tester), 1);

    await tester.tap(find.byKey(const ValueKey('meditation_end_practice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meditation_start')), findsOneWidget);
  });

  testWidgets(
    'completed timer shows the done message instead of a stuck timer',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('home_meditation')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('meditation_start')),
      );

      // 5 minutes is the shortest chip; fake time makes it fast enough.
      await tester.tap(find.byKey(const ValueKey('meditation_preset_5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('meditation_start')));
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('ครบเวลาแล้ว'), findsOneWidget);

      // Clear vibration timers (3 pulses, 400ms apart) before the test ends.
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('starting again after a finished sitting runs a whole new one', (
    tester,
  ) async {
    // The clock was left at 00:00, so the first tick ended the new sitting.
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );
    await tester.tap(find.byKey(const ValueKey('meditation_preset_5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('ครบเวลาแล้ว'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('04:57'), findsOneWidget);
    expect(find.text('ครบเวลาแล้ว'), findsNothing);

    // Leave it stopped so no ticker outlives the test.
    await tester.tap(find.byKey(const ValueKey('meditation_pause')));
    await tester.pump();
  });
}
