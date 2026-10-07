import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/prayer_list/widgets/welcome_sheet.dart';
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

Future<PrefsService> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone.
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/prayers-en.json');
    appRouter.go('/');
  });

  testWidgets('first launch walks the home screen once, stop by stop', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefsService = await pumpApp(tester);

    // The welcome is the tour's opening card, not a sheet listing features:
    // what it used to describe is now pointed at where it is.
    await pumpUntilFound(tester, find.text('ยินดีต้อนรับสู่ สวดมนต์'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home_tour')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    // Count as seen immediately; show once per version.
    expect(prefsService.getWelcomeSeenVersion(), kWelcomeSheetVersion);

    // Each stop titles its card with the label of what it lights. Stops whose
    // target is not on screen are skipped, so walk until the last card rather
    // than counting presses.
    final card = find.byKey(const ValueKey('home_tour_card'));
    final seen = <String>{};
    for (var i = 0; i < 10; i++) {
      if (tester.any(
        find.descendant(of: card, matching: find.text('เริ่มใช้งาน')),
      )) {
        break;
      }
      await tester.tap(find.byKey(const ValueKey('home_tour_next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      for (final title in [
        'เป้าหมายวันนี้',
        'ทางลัด',
        'บทสวดแนะนำวันนี้',
        'เริ่มสวด',
      ]) {
        if (tester.any(find.descendant(of: card, matching: find.text(title)))) {
          seen.add(title);
        }
      }
    }
    expect(seen, containsAll(['เป้าหมายวันนี้', 'ทางลัด', 'เริ่มสวด']));

    // The last card's button ends the tour.
    await tester.tap(find.byKey(const ValueKey('home_tour_next')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('home_tour')), findsNothing);
  });

  testWidgets('the tour can be skipped from its first card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await pumpUntilFound(tester, find.byKey(const ValueKey('home_tour_skip')));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('home_tour_skip')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('home_tour')), findsNothing);
  });

  testWidgets('previously seen welcome sheet does not appear again', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': kWelcomeSheetVersion,
    });
    await pumpApp(tester);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ยินดีต้อนรับสู่ สวดมนต์'), findsNothing);
  });

  testWidgets('upgraded existing users see only whats new content', (
    WidgetTester tester,
  ) async {
    // Has seen a previous version; nonzero means not a new user.
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': kWelcomeSheetVersion - 1,
    });
    final prefsService = await pumpApp(tester);

    await pumpUntilFound(tester, find.text('มีอะไรใหม่'));
    await tester.pump(const Duration(milliseconds: 400));

    // Announce only new features, not previously seen ones again. Scoped to
    // the sheet: the same labels are on the home screen behind it.
    for (final title in [
      'เสียงธรรมชาติ',
      'เป้าหมายวันนี้',
      'บทสวดแนะนำวันนี้',
    ]) {
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(title),
        ),
        findsOneWidget,
        reason: 'หายไป: $title',
      );
    }
    expect(find.text('ยินดีต้อนรับสู่ สวดมนต์'), findsNothing);
    expect(find.text('แชร์ชุดสวด'), findsNothing);
    expect(find.text('เลื่อนหน้าอัตโนมัติ'), findsNothing);
    expect(find.text('ลากเปลี่ยนหมวดต่อเนื่อง'), findsNothing);
    expect(find.text('หน้าแรกโฉมใหม่'), findsNothing);
    expect(find.text('ค้นหาล่าสุด'), findsNothing);

    expect(prefsService.getWelcomeSeenVersion(), kWelcomeSheetVersion);
    await tester.tap(find.text('ลองเลย'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('มีอะไรใหม่'), findsNothing);
  });

  testWidgets('new users can choose language from the tour on first launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefsService = await pumpApp(tester);
    await pumpUntilFound(tester, find.text('ยินดีต้อนรับสู่ สวดมนต์'));
    await tester.pump(const Duration(milliseconds: 400));

    // The language picker is on the tour's opening card; choose English.
    await tester.tap(find.text('ไทย'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('English').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The card follows the language at once and the value persists.
    expect(find.text('Welcome to Chanting'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(prefsService.getLocale(), 'en');

    await tester.tap(find.byKey(const ValueKey('home_tour_skip')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // A fresh install is offered the goal page next; skip past it to get to
    // the home screen this test is about.
    await pumpUntilFound(tester, find.byKey(const ValueKey('goal_skip')));
    await tester.tap(find.byKey(const ValueKey('goal_skip')));
    await tester.pumpAndSettle();

    // Home UI must switch language immediately without reopening the app. Static
    // tile labels become English, while category names remain Thai because there
    // is no en content edition (`kContentLanguages` = `{'th'}` since 2026-08-16).
    // Not the greeting: that follows the clock.
    await pumpUntilFound(tester, find.text('View all'));
    expect(find.text('ยินดีต้อนรับสู่ สวดมนต์'), findsNothing);
  });

  testWidgets('upgraded existing users are not asked for language again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': kWelcomeSheetVersion - 1,
    });
    final prefs = await pumpApp(tester);
    await pumpUntilFound(tester, find.text('มีอะไรใหม่'));
    await tester.pump(const Duration(milliseconds: 400));

    // The "what's new" sheet has no language dropdown; existing users already set it.
    expect(find.text('ไทย'), findsNothing);

    // And they are not sent to set a goal: they have their own habit already,
    // and an update that opens a setup screen reads as the app losing settings.
    await tester.tap(find.text('ลองเลย'));
    await tester.pumpAndSettle();
    expect(find.text('ตั้งเป้าหมาย'), findsNothing);
    expect(prefs.getGoalPromptSeen(), isFalse);
  });

  testWidgets('the goal page is offered once, not on every launch', (
    tester,
  ) async {
    // Offered after the tour on a fresh install, finished or skipped…
    SharedPreferences.setMockInitialValues({});
    final prefs = await pumpApp(tester);
    await pumpUntilFound(tester, find.text('ยินดีต้อนรับสู่ สวดมนต์'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('home_tour_skip')));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('ตั้งเป้าหมาย'));
    expect(prefs.getGoalPromptSeen(), isTrue);

    // …and skipping it is a real answer, not a way to be asked again tomorrow.
    await tester.tap(find.byKey(const ValueKey('goal_skip')));
    await tester.pumpAndSettle();
    expect(find.text('ตั้งเป้าหมาย'), findsNothing);
  });

  testWidgets('the tour uses English when English was already selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    await pumpApp(tester);

    await pumpUntilFound(tester, find.text('Welcome to Chanting'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('ยินดีต้อนรับสู่ สวดมนต์'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_tour_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home_tour_card')),
        matching: find.text("Today's goal"),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home_tour_skip')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome to Chanting'), findsNothing);
  });
}
