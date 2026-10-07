import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/models/playlist.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show lastSection, tapPrayerCard;

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

  testWidgets(
    'continuous mode keeps the top chip bar height stable on narrow screens',
    (tester) async {
      // 400px is a typical mobile width where three chips used to wrap.
      // At 371px, chips get ~331px and three chips already take about 327px.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
        'welcome_seen_version': 999,
      });
      final prefsService = await PrefsService.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      appRouter.go('/category/tham-wat-chao');
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pump(const Duration(seconds: 1));
      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('reading_top_bar'));
      final before = tester.getSize(bar).height;
      expect(
        find.byType(ActionChip),
        findsNothing,
        reason: 'ยังไม่เปิดบาลี/คำแปล',
      );

      // Enabling Pali reveals the position-toggle chip as the third chip.
      await tester.tap(find.widgetWithText(FilterChip, 'บาลี'));
      await tester.pumpAndSettle();
      expect(find.byType(ActionChip), findsOneWidget);

      // **This is the invariant**: the bar stays fixed-height. If it grows by one
      // row, the current chanting content shifts down mid-reading, so chips scroll
      // horizontally instead of wrapping (`Wrap` -> horizontal `SingleChildScrollView`).
      expect(
        tester.getSize(bar).height,
        before,
        reason: 'แถบชิปสูงขึ้น = ชิปห่อบรรทัด = เนื้อหาถูกดันลงตอนกำลังอ่าน',
      );
    },
  );

  testWidgets(
    'continuous mode shows every prayer in a category and shared chips control all prayers',
    (WidgetTester tester) async {
      // Very tall screen so multiple prayers fit without scrolling.
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
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

      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      // Other prayers in the same category appear continuously on one page.
      expect(find.text('พุทธาภิถุติ'), findsOneWidget);
      // There is one pinned display-control chip set, not one per prayer.
      expect(find.text('บาลี'), findsOneWidget);
      expect(find.text('คำแปล'), findsOneWidget);

      // Tapping the Pali chip actually shows the prayer's Pali text.
      await tester.tap(find.text('บาลี'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Arahaṃ', findRichText: true), findsWidgets);
    },
  );

  testWidgets('continuous mode next-category card opens the next category', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'continuous_reading': true,
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

    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Category end shows an end label and the next-category card.
    expect(find.text('จบหมวด ทำวัตรเช้า'), findsOneWidget);
    // The card is at the end of a long page; scroll it into view before tapping.
    await tester.ensureVisible(find.text('หมวดถัดไป'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('หมวดถัดไป'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Navigate to the next ordered category and start at its first prayer.
    await pumpUntilFound(tester, find.text('คำบูชาพระรัตนตรัย (โย โส ภะคะวา)'));
    expect(find.text('จบหมวด ทำวัตรเย็น'), findsOneWidget);
  });

  testWidgets(
    'continuous mode can drag up to the next category and drag back down to cancel',
    (WidgetTester tester) async {
      // Short viewport so content overflows; clamping physics ignores drag if the
      // page cannot scroll (`maxScrollExtent = 0`). Test fonts are much shorter
      // than real fonts, leaving the whole category only about 1200px tall.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
        'welcome_seen_version': 999,
      });
      final prefsService = await PrefsService.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      // Short screen; open the list directly instead of tapping through grid tiles.
      appRouter.go('/all');
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pump(const Duration(seconds: 1));

      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      // Target the content scroll view directly. The chip bar is also a horizontal
      // SingleChildScrollView, so `.first` is no longer this one.
      final scrollView = find.byKey(const ValueKey('continuous_scroll'));
      final controller = tester
          .widget<SingleChildScrollView>(scrollView)
          .controller!;

      // Go to the page end, then drag upward past the threshold to see the release label.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      // Drag in multiple steps: the first starts the drag after touch slop, and
      // later steps accumulate real overscroll.
      final cancelGesture = await tester.startGesture(
        tester.getCenter(scrollView),
      );
      for (var i = 0; i < 4; i++) {
        await cancelGesture.moveBy(const Offset(0, -50));
        await tester.pump();
      }
      expect(find.textContaining('ปล่อยเพื่อไปหมวด'), findsOneWidget);
      expect(find.text('ลากกลับลงเพื่อยกเลิก'), findsOneWidget);
      // The webtoon-style progress ring fills when the threshold is reached.
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 1.0);

      // Drag back down before release to cancel and stay in the same category.
      await cancelGesture.moveBy(const Offset(0, 300));
      await tester.pump();
      await cancelGesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('จบหมวด ทำวัตรเช้า'), findsOneWidget);

      // Drag upward past the threshold and release to go to the next category.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final goGesture = await tester.startGesture(tester.getCenter(scrollView));
      for (var i = 0; i < 4; i++) {
        await goGesture.moveBy(const Offset(0, -50));
        await tester.pump();
      }
      await goGesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await pumpUntilFound(tester, find.text('จบหมวด ทำวัตรเย็น'));
    },
  );

  testWidgets(
    'continuous mode final category shows an end label without a next-category card',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
        'welcome_seen_version': 999,
      });
      final prefsService = await PrefsService.init();
      // The last category used to end without feedback. Read the category/prayer
      // from the real file; hard-coding the old last category broke when new ones
      // were appended.
      final last = lastSection();
      appRouter.go('/prayer/${last.lastPrayerId}');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      await pumpUntilFound(tester, find.text('จบหมวด ${last.title}'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('จบหมวด ${last.title}'), findsOneWidget);
      expect(find.text('หมวดถัดไป'), findsNothing);
      // It can still go back; the last category is not the first.
      expect(find.text('หมวดก่อนหน้า'), findsOneWidget);
    },
  );

  testWidgets(
    'continuous mode playlist shows an end-of-playlist label instead of an end-of-category label',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
        'welcome_seen_version': 999,
        // Mixed playlist across categories; the end label cannot infer from the first prayer.
        'playlists': <String>[
          const Playlist(
            id: 'pl1',
            name: 'ก่อนนอน',
            prayerIds: ['pubba-bhaga-namakara', 'ratanattaya-puja-yo-so'],
          ).toJsonString(),
        ],
      });
      final prefsService = await PrefsService.init();
      appRouter.go('/prayer/pubba-bhaga-namakara?pl=pl1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      await pumpUntilFound(tester, find.textContaining('จบชุดสวด'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('จบชุดสวด "ก่อนนอน"'), findsOneWidget);
      // A playlist ends within itself and does not navigate to other categories.
      expect(find.text('หมวดถัดไป'), findsNothing);
      expect(find.text('หมวดก่อนหน้า'), findsNothing);
      expect(find.textContaining('จบหมวด'), findsNothing);
    },
  );

  testWidgets(
    'continuous mode can drag down at the top to return to the previous category',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'continuous_reading': true,
        'welcome_seen_version': 999,
      });
      final prefsService = await PrefsService.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      // Open the second category directly; its prayers are at the end of a long
      // list and this short viewport cannot reasonably scroll to tap them.
      appRouter.go('/prayer/ratanattaya-puja-yo-so');
      await pumpUntilFound(tester, find.text('หมวดก่อนหน้า'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('ทำวัตรเช้า'), findsOneWidget); // Card subtitle.

      // Target the content scroll view directly. The chip bar is also a horizontal
      // SingleChildScrollView, so `.first` is no longer this one.
      final scrollView = find.byKey(const ValueKey('continuous_scroll'));
      final controller = tester
          .widget<SingleChildScrollView>(scrollView)
          .controller!;

      // At the top, drag downward past the threshold for a full ring and release label.
      expect(controller.offset, 0);
      final gesture = await tester.startGesture(tester.getCenter(scrollView));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump();
      }
      expect(find.textContaining('ปล่อยเพื่อย้อนหมวด'), findsOneWidget);
      expect(find.text('ลากกลับขึ้นเพื่อยกเลิก'), findsOneWidget);
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 1.0);

      // Drag back up before release to cancel and stay in the same category.
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('จบหมวด ทำวัตรเย็น'), findsOneWidget);

      // Drag downward past the threshold and release to go to the previous category.
      controller.jumpTo(0);
      await tester.pump();
      final goGesture = await tester.startGesture(tester.getCenter(scrollView));
      for (var i = 0; i < 4; i++) {
        await goGesture.moveBy(const Offset(0, 50));
        await tester.pump();
      }
      await goGesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await pumpUntilFound(tester, find.text('จบหมวด ทำวัตรเช้า'));
    },
  );

  testWidgets('continuous mode shows drag and category-end labels in English locale', (
    tester,
  ) async {
    // These labels appear only during an active drag, so the gesture must be driven.
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'continuous_reading': true,
      'welcome_seen_version': 999,
      'locale': 'en',
    });
    final prefsService = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
        child: const ChantingApp(),
      ),
    );
    // Short screen; open the list directly instead of tapping through grid tiles.
    appRouter.go('/all');
    await pumpUntilFound(tester, find.text('Veneration of the Triple Gem'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Veneration of the Triple Gem'));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // The category-end labels and category names come from the English edition.
    expect(find.text('End of Morning Chanting'), findsOneWidget);
    expect(find.text('จบหมวด ทำวัตรเช้า'), findsNothing);

    // Target the content scroll view directly. The chip bar is also a horizontal
    // SingleChildScrollView, so `.first` is no longer this one.
    final scrollView = find.byKey(const ValueKey('continuous_scroll'));
    final controller = tester
        .widget<SingleChildScrollView>(scrollView)
        .controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(scrollView));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
    }
    expect(find.textContaining('Release for'), findsOneWidget);
    expect(find.text('Drag back down to cancel'), findsOneWidget);
    expect(find.textContaining('ปล่อยเพื่อไปหมวด'), findsNothing);

    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });
}
