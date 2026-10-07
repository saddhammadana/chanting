import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
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

/// Verifies the app declares the Thai locale. Without it, Flutter runs as en_US
/// and built-in Material widgets, such as the reminder time picker, show
/// Cancel/OK/AM/PM in English inside the Thai app. See docs/internationalization.md Phase 0.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone.
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
    final prefs = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
        child: const ChantingApp(),
      ),
    );
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home_practice_hero')),
    );
  }

  testWidgets('app starts in Thai locale instead of en_US', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byKey(const ValueKey('nav_home')));
    expect(Localizations.localeOf(ctx), const Locale('th'));
  });

  testWidgets(
    'reminder time picker uses Thai labels instead of Cancel and OK',
    (tester) async {
      await pumpApp(tester);
      // The time picker now opens from the goal page's own time row; the
      // slot's full name is on the switch beside it, not on the row that
      // opens the picker.
      appRouter.go('/settings/goal');
      await pumpUntilFound(tester, find.byKey(const ValueKey('goal_time')));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('goal_time')));
      await tester.pumpAndSettle();

      // Time-picker buttons come from MaterialLocalizations; they used to be
      // English because the app did not declare its locale.
      final dialogTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(dialogTexts, isNot(contains('Cancel')));
      expect(dialogTexts, isNot(contains('OK')));
      expect(dialogTexts, contains('ยกเลิก'));
      expect(dialogTexts, contains('ตกลง'));
    },
  );

  testWidgets('back button uses a Thai tooltip', (tester) async {
    await pumpApp(tester);
    // A category is pushed above Home, so its AppBar has the app's back
    // button to check. It takes its tooltip from MaterialLocalizations, as
    // the framework's own BackButton does.
    await tester.tap(find.byKey(const ValueKey('home_morning')));
    final back = find.byKey(const ValueKey('app_back_button'));
    await pumpUntilFound(tester, back);
    await tester.pump(const Duration(seconds: 1));

    final tooltip = tester.widget<Tooltip>(
      find.descendant(of: back, matching: find.byType(Tooltip)),
    );
    expect(tooltip.message, isNot('Back'));
  });
}
