import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show tapPrayerCard;

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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone.
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  testWidgets('auto scroll advances to the next prayer after reaching the end', (
    WidgetTester tester,
  ) async {
    // Very tall screen: the prayer is shorter than the viewport, so it counts
    // as "finished" on the first tick and isolates the auto-advance behavior.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'auto_scroll_auto_start': true,
      'welcome_seen_version': 999,
    });
    final prefsService = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
        child: const ChantingApp(),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('nav_prayers')));
    await tester.tap(find.byKey(const ValueKey('nav_prayers')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pump(const Duration(seconds: 1));

    // Open the first morning-chanting prayer; auto scroll starts from settings.
    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // After the end-of-prayer pause (1.8s), it should advance within the category.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    // The second morning prayer also appears in evening chanting, so use findsWidgets.
    expect(find.text('ปุพพภาคนมการ'), findsWidgets);

    // At the last prayer in the category, wait for it to stop without stuck timers.
    await tester.pump(const Duration(seconds: 3));
  });
}
