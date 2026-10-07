import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current `title` for prayer [id], **read from the real data file**, not hard-coded.
///
/// Exists because nine tests used to fail together whenever a prayer title changed.
/// Those tests did not check the *name*; they only used it to tap the target card.
/// The stable value is **`id`**, not user-facing text, which can change anytime.
/// This mirrors `_sectionWithMixedVerification` in `prayer_edit_test.dart`, which
/// builds fixtures from real files to survive content movement.
String prayerTitle(String id) => _prayerRecord(id)['title'] as String;

Map<String, dynamic> _prayerRecord(String id) {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  for (final p in prayers.cast<Map<String, dynamic>>()) {
    if (p['id'] == id) return p;
  }
  fail('ไม่มีบท id=$id ในไฟล์ข้อมูลแล้ว — เทสต์ที่อ้างถึงมันต้องเปลี่ยนบท');
}

/// First non-empty line for prayer [id], **read from the file's `sections`/`lines` structure**.
///
/// Since 2026-08-16, every record uses the new shape (docs/content/prayer-schema.md rule 1),
/// so **there is no prayer-level `text` key anymore**. Tests reading `record['text']`
/// got silent nulls. This helper supports both shapes like `Prayer` computing
/// `text` for old call sites.
String prayerFirstLine(String id) {
  final r = _prayerRecord(id);
  final flat = r['text'] as String?;
  if (flat != null) {
    return flat.split('\n').firstWhere((l) => l.trim().isNotEmpty);
  }
  for (final s
      in (r['sections'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    for (final l
        in (s['lines'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final t = (l['text'] as String?)?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
  }
  fail('บท id=$id ไม่มีบรรทัดที่มีข้อความเลย');
}

List<Map<String, dynamic>> _sectionRecords() =>
    (jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();

/// First category containing prayer [id]. This matches `resolveSection` when a
/// prayer is opened without a category, such as from the all-prayers page.
List<String> sectionOf(String id) {
  for (final s in _sectionRecords()) {
    final ids = (s['prayerIds'] as List<dynamic>).cast<String>();
    if (ids.contains(id)) return ids;
  }
  fail('บท id=$id ไม่อยู่หมวดไหนเลย');
}

/// One-based position and prayer count for [id]'s category. The reading bar's
/// `n/m` must be computed from the file, not hard-coded.
({int position, int total}) prayerPosition(String id) {
  final ids = sectionOf(id);
  return (position: ids.indexOf(id) + 1, total: ids.length);
}

/// Category count in `sections-th.json`, so new categories do not break hard-coded tests.
int sectionCount() => _sectionRecords().length;

/// The **last** category and its last prayer. "Last" means file order, not any
/// special category; the old hard-coded category broke when another was appended.
({String id, String title, String lastPrayerId}) lastSection() {
  final s = _sectionRecords().last;
  final ids = (s['prayerIds'] as List<dynamic>).cast<String>();
  if (ids.isEmpty) fail('หมวดสุดท้าย (${s['id']}) ไม่มีบทเลย');
  return (
    id: s['id'] as String,
    title: s['title'] as String,
    lastPrayerId: ids.last,
  );
}

/// Next prayer in the same category; "next" means `sections-th.json` order.
Map<String, dynamic> nextPrayerAfter(String id) {
  final ids = sectionOf(id);
  final i = ids.indexOf(id);
  if (i + 1 >= ids.length) fail('บท id=$id เป็นบทสุดท้ายของหมวดแล้ว');
  return _prayerRecord(ids[i + 1]);
}

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
  // Debug: show all on-screen text when failing.
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText())
      .toList();
  debugPrint('TEXTS ON SCREEN: $texts');
  expect(finder, findsWidgets); // Report failure with the finder name.
}

/// Tap prayer card [title] on the all-prayers page.
///
/// **Use `.first`, not the bare finder**. The page is grouped by category
/// (`filteredPrayersProvider`), so prayers in multiple categories have multiple
/// cards. The first card is from the earlier category in `sections-th.json`, which
/// is what these tests intend to tap.
Future<void> tapPrayerCard(WidgetTester tester, String title) =>
    tester.tap(find.text(title).first);

/// Open the category-page AppBar overflow menu and choose command [itemKey].
///
/// Category commands moved from bare AppBar icons into the menu. Three adjacent
/// icons (`add` / `playlist_add` / pin) were ambiguous, and the first two looked
/// too similar. Pin stays visible because it is a switch whose **state must show**.
Future<void> tapCategoryMenu(WidgetTester tester, String itemKey) async {
  await tester.tap(find.byKey(const ValueKey('category_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(itemKey)));
  await tester.pumpAndSettle();
}

Future<PrefsService> pumpApp(
  WidgetTester tester, {

  /// Extra prefs before opening the app, such as `{'locale': 'en'}` for other languages.
  Map<String, Object> extraPrefs = const {},

  /// First prayer title used to confirm the list has loaded. It varies by
  /// **content** language, not UI language. Override when a test starts in a
  /// non-Thai content edition.
  String loadedAnchor = 'บทกราบพระรัตนตรัย',

  /// Home is a grid. By default, tap the all-prayers tile because most tests start
  /// from the prayer list. Pass false for tests that work on the home page itself.
  bool openAll = true,
}) async {
  // Very tall screen so content fits without scrolling, avoiding ListView lazy-build issues.
  // Height must grow with prayer count: 2400 fit 19 prayers, but after 36 prayers
  // in July 2026, trailing cards left the viewport and finders missed them.
  tester.view.physicalSize = const Size(800, 5600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Skip welcome sheet; it has dedicated tests.
  SharedPreferences.setMockInitialValues({
    'welcome_seen_version': 999,
    ...extraPrefs,
  });
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
  if (!openAll) return prefsService;
  await tester.tap(find.byKey(const ValueKey('nav_prayers')));
  await pumpUntilFound(tester, find.text(loadedAnchor));
  // Wait for the list transition before later tests tap cards.
  await tester.pump(const Duration(seconds: 1));
  return prefsService;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone; without
    // eviction, the next test may await a Future that never completes.
    rootBundle.evict('assets/data/prayers-th.json');
    // appRouter is global; reset home to avoid stale routes from previous tests.
    appRouter.go('/');
  });

  testWidgets(
    'home page shows category cards from assets and can open the all-prayers list',
    (WidgetTester tester) async {
      await pumpApp(tester, openAll: false);

      // Home keeps quick actions, while search and personal sets belong to
      // their bottom-navigation destinations.
      // The greeting follows the clock (day_part_test pins which is which).
      expect(find.byKey(const ValueKey('home_greeting')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_morning')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_evening')), findsOneWidget);
      expect(find.text('ชุดสวดของฉัน'), findsNothing);
      expect(find.byType(SearchBar), findsNothing);
      expect(find.text('นั่งสมาธิ'), findsOneWidget);
      expect(find.text('แผ่เมตตา'), findsOneWidget);
      // Prayer titles do not show on the home page yet.
      expect(find.text(prayerTitle('ratanattaya-vandana')), findsNothing);

      // Open the Prayers destination to see prayers from multiple categories.
      await tester.tap(find.byKey(const ValueKey('nav_prayers')));
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      expect(find.text(prayerTitle('mettapharana')), findsOneWidget);
    },
  );

  testWidgets('tapping a category card shows only prayers in that category', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, openAll: false);

    await tester.tap(find.byKey(const ValueKey('home_morning')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pump(const Duration(seconds: 1));
    // This prayer is in evening chanting and must not appear in morning chanting.
    expect(find.text(prayerTitle('mettapharana')), findsNothing);
    // This prayer is only in the morning category. The old fixture moved to evening
    // chanting, matching real chanting practice.
    expect(find.text('พุทธาภิถุติ'), findsOneWidget);
  });

  testWidgets('opening a prayer shows translation and can save favorite state', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpApp(tester);

    // Open the prayer detail. Wait for a detail-only icon because content text can
    // duplicate list-card previews, then wait for transition before scrolling.
    await tester.tap(find.text(prayerTitle('mettapharana')));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('สัพเพ สัตตา'), findsWidgets);

    // Toggle translation using the chip above content.
    expect(find.textContaining('ขอสัตว์ทั้งหลายทั้งปวง'), findsNothing);
    await tester.tap(find.text('คำแปล'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining('ขอสัตว์ทั้งหลายทั้งปวง'));

    // Favoriting should show in favorites and persist to prefs.
    await tester.tap(find.byIcon(Icons.favorite_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefsService.getFavoriteIds(), ['mettapharana']);

    // Saved prayers are owned by the Prayers destination, keeping Home focused.
    appRouter.go('/');
    await pumpUntilFound(tester, find.byKey(const ValueKey('nav_prayers')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('nav_prayers')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('prayers_favorites')),
    );
    // Mid-transition the app-bar button is outside the viewport and the tap
    // misses without an error; the title below would still be found, on the
    // all-prayers list, so wait for the row that only the saved page has.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prayers_favorites')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('favorite_row_mettapharana')),
    );
    expect(find.text(prayerTitle('mettapharana')), findsWidgets);
  });

  testWidgets('tapping content toggles full-screen reading mode', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text(prayerTitle('mettapharana')));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Tap content to hide the AppBar and enter full-screen mode.
    await tester.tap(find.textContaining('สัพเพ สัตตา').first);
    await tester.pump();
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // Wait for the hint to fade to avoid pending timers at test end.
    await tester.pump(const Duration(seconds: 3));

    // Tap again to show the AppBar.
    await tester.tap(find.textContaining('สัพเพ สัตตา').first);
    await tester.pump();
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('paged mode drag up at prayer end advances to the next prayer', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final scrollView = find.byKey(const ValueKey('prayer_scroll'));
    final controller = tester.widget<ListView>(scrollView).controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    // **pumpApp's 5600px viewport makes this prayer fit exactly, so there is no
    // scroll extent**. Clamping physics rejects that drag entirely; this proves
    // AlwaysScrollableScrollPhysics works, not only naturally scrollable long prayers.
    expect(controller.position.maxScrollExtent, 0);

    // Drag in multiple steps; the first starts the drag after touch slop.
    final gesture = await tester.startGesture(tester.getCenter(scrollView));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
    }
    expect(
      find.textContaining('ปล่อยเพื่อไปบท'),
      findsOneWidget,
      reason: 'ลากเลยเกณฑ์ 96px แล้วต้องขึ้นวงบอกระยะพร้อมชื่อบทถัดไป',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    // This is the next prayer in morning chanting.
    await pumpUntilFound(tester, find.text('ปุพพภาคนมการ'));
  });

  testWidgets('swiping left on the reader opens the next prayer', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text(prayerTitle('mettapharana')));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Swipe left on content to go to the next prayer **in the same category** by
    // `sections-th.json` order. Read from the file, not hard-coded, because inserted
    // prayers have broken this test while swipe behavior was correct.
    final next = nextPrayerAfter('mettapharana');
    await tester.fling(
      find.textContaining(prayerFirstLine('mettapharana')).first,
      const Offset(-400, 0),
      1000,
    );
    await pumpUntilFound(tester, find.text(next['title'] as String));
    await pumpUntilFound(
      tester,
      find.textContaining(prayerFirstLine(next['id'] as String)),
    );
  });

  testWidgets(
    'swiping past the first prayer shows edge glow instead of staying silent or stuck',
    (tester) async {
      await pumpApp(tester);

      // First prayer in morning chanting, so swiping right has no previous prayer.
      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      await tester.fling(
        find.textContaining('อะระหัง สัมมาสัมพุทโธ').first,
        const Offset(400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must tell the user they are at the edge and stay on the same prayer.
      expect(find.text('นี่เป็นบทแรกของหมวด'), findsOneWidget);
      expect(find.textContaining('อะระหัง สัมมาสัมพุทโธ'), findsWidgets);

      // Must disappear on its own, not stick; real timing is about 2.6s.
      //
      // **Pump step by step**. One 3s pump is not enough: the SnackBar timer starts
      // after entrance animation frames, and pumpAndSettle does not advance timers.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('นี่เป็นบทแรกของหมวด'), findsNothing);
    },
  );

  testWidgets(
    'font size sheet from overflow menu changes reader size immediately',
    (tester) async {
      final prefsService = await pumpApp(tester);

      await tester.tap(find.text(prayerTitle('mettapharana')));
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('ขนาดตัวอักษร').last);
      await pumpUntilFound(tester, find.byIcon(Icons.text_increase));
      await tester.pump(const Duration(seconds: 1));

      // Sheet opens showing the current size.
      expect(find.text('100%'), findsWidgets);

      // A+ steps up and persists immediately, with no confirmation.
      await tester.tap(find.byIcon(Icons.text_increase));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(prefsService.getFontScale(), greaterThan(1.0));

      final enlarged = prefsService.getFontScale();
      await tester.tap(find.byIcon(Icons.text_decrease));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(prefsService.getFontScale(), lessThan(enlarged));
    },
  );

  testWidgets(
    'copy prayer includes Pali and translation according to enabled chips',
    (tester) async {
      await pumpApp(tester);

      // This channel has no test handler; without a mock, Clipboard.setData hangs.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      Future<void> copyPrayer() async {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('คัดลอกบทสวด').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      // Chips are off, so copy only title and content with no extras.
      await copyPrayer();
      expect(copied, isNotNull);
      expect(copied, contains('บทกราบพระรัตนตรัย'));
      expect(copied, contains('อะระหัง สัมมาสัมพุทโธ'));
      expect(copied, isNot(contains('[บาลี]')));
      expect(copied, isNot(contains('[คำแปล]')));

      // With both chips on, copy both sections with headings.
      await tester.tap(find.widgetWithText(FilterChip, 'บาลี'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'คำแปล'));
      await tester.pump(const Duration(seconds: 1));

      await copyPrayer();
      expect(copied, contains('[บาลี]'));
      expect(copied, contains('Arahaṃ sammāsambuddho'));
      expect(copied, contains('[คำแปล]'));
      // Translation must follow Pali, matching the on-screen order.
      expect(
        copied!.indexOf('[คำแปล]'),
        greaterThan(copied!.indexOf('[บาลี]')),
      );
    },
  );

  testWidgets('inline translation mode can be toggled and persists', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpApp(tester);

    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Enable translation; default position is separate at the end.
    await tester.tap(find.text('คำแปล'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('ข้าพเจ้าอภิวาทพระผู้มีพระภาคเจ้า'),
      findsOneWidget,
    );
    expect(find.text('แยกท้ายบท'), findsOneWidget);

    // Tap the position chip to switch inline and persist to prefs.
    await tester.tap(find.text('แยกท้ายบท'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('แทรกใต้บรรทัด'), findsOneWidget);
    expect(
      find.textContaining('ข้าพเจ้าอภิวาทพระผู้มีพระภาคเจ้า'),
      findsOneWidget,
    );
    expect(prefsService.getInlineTranslation(), isTrue);
  });

  // The "non-inlineable prayer disables the position chip" case moved to
  // `translation_toggle_test.dart`. Real data has no non-inlineable prayers now,
  // so the case needs the fake-asset helper that lives there.

  testWidgets('selecting dark theme applies the dark theme', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpApp(tester, openAll: false);

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    // Settings is a hub; the theme choices sit on their own sub-page.
    await pumpUntilFound(tester, find.byKey(const ValueKey('settings_theme')));
    await tester.tap(find.byKey(const ValueKey('settings_theme')));
    await pumpUntilFound(tester, find.text('มืด'));
    await tester.tap(find.text('มืด'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(prefsService.getThemeMode(), 'dark');
  });

  testWidgets('playlist creation can add prayers and persists', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpApp(tester, openAll: false);

    // Enter playlists from its primary navigation destination.
    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('playlist_create_button')),
    );
    await tester.tap(find.byKey(const ValueKey('playlist_create_button')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('playlist_name_field')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
      find.byKey(const ValueKey('playlist_name_field')),
      'สวดก่อนนอน',
    );

    // Add a prayer on the choose tab; nothing is stored before saving.
    const id = 'ratanattaya-vandana';
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('choose_$id')),
        matching: find.byTooltip('เพิ่มเข้าชุด'),
      ),
    );
    await tester.pump();
    expect(prefsService.getPlaylistsRaw(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('playlist_save_button')));
    await pumpUntilFound(tester, find.text('สร้างชุดสวดสำเร็จ'));

    // Playlist is saved to prefs with the selected prayer.
    expect(prefsService.getPlaylistsRaw(), hasLength(1));
    expect(prefsService.getPlaylistsRaw().single, contains(id));
  });

  testWidgets('English UI uses the English prayer content edition', (
    tester,
  ) async {
    await pumpApp(
      tester,
      extraPrefs: {'locale': 'en'},
      loadedAnchor: 'Veneration of the Triple Gem',
    );

    expect(find.text('Veneration of the Triple Gem'), findsWidgets);
    expect(find.text('Morning Chanting'), findsWidgets);

    await tapPrayerCard(tester, 'Veneration of the Triple Gem');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Position text and content labels are both English in the English edition.
    final pos = prayerPosition('ratanattaya-vandana');
    expect(find.text('${pos.position} of ${pos.total}'), findsOneWidget);
    expect(find.textContaining('บทที่ '), findsNothing);

    // Overflow menu is localized.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Copy prayer'), findsOneWidget);
    expect(find.text('ขนาดตัวอักษร'), findsNothing);
  });

  testWidgets('playlist pages are localized in English including plurals', (
    tester,
  ) async {
    await pumpApp(tester, extraPrefs: {'locale': 'en'}, openAll: false);

    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await pumpUntilFound(tester, find.text('Create a new set'));

    // Empty page.
    expect(find.text('My prayer sets'), findsWidgets);
    expect(find.text('No prayer sets yet'), findsOneWidget);
    expect(find.text('ยังไม่มีชุดสวด'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('playlist_create_button')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('playlist_name_field')),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Save set'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
    expect(find.text('บันทึกชุดสวด'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('playlist_name_field')),
      'Before bed',
    );
    await tester.tap(find.byKey(const ValueKey('playlist_save_button')));
    await pumpUntilFound(tester, find.text('Set created'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('View set'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The new set's page is in English too.
    expect(find.text('Prayer set'), findsOneWidget);
    expect(find.text('This set has no prayers yet'), findsOneWidget);

    // Back on the list; an empty playlist should show "No prayers", not "0 prayers".
    await tester.tap(find.byKey(const ValueKey('app_back_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Before bed'), findsOneWidget);
    expect(find.text('No prayers'), findsOneWidget);
  });

  testWidgets('prayer search filters the list', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'พาหุง');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(prayerTitle('buddha-jaya-mangala-gatha')), findsOneWidget);
    expect(find.text(prayerTitle('ratanattaya-vandana')), findsNothing);
  });

  testWidgets(
    'clear search button appears only with a query and restores all prayers',
    (WidgetTester tester) async {
      await pumpApp(tester);

      final clear = find.byKey(const ValueKey('search_clear'));
      // Blank query means nothing to clear, so no clear button.
      expect(clear, findsNothing);

      await tester.enterText(find.byType(SearchBar), 'พาหุง');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(clear, findsOneWidget);

      await tester.tap(clear);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Field and results return to the complete prayer directory.
      expect(
        tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
        '',
      );
      expect(clear, findsNothing);
      expect(find.text('ทำวัตรเช้า'), findsOneWidget);
      expect(find.text(prayerTitle('buddha-jaya-mangala-gatha')), findsWidgets);
    },
  );

  testWidgets(
    'search history stores submitted queries shows them and can reuse a query',
    (WidgetTester tester) async {
      final prefsService = await pumpApp(tester);

      // No history yet; focusing search should not show the panel.
      await tester.tap(find.byType(SearchBar));
      await tester.pump();
      expect(find.text('ค้นหาล่าสุด'), findsNothing);
      expect(find.text('ทำวัตรเช้า'), findsOneWidget);

      // Typing and pressing enter saves the query to prefs.
      await tester.enterText(find.byType(SearchBar), 'พาหุง');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(prefsService.getSearchHistory(), ['พาหุง']);

      // Clear text while focused: the history dropdown overlays the prayer list.
      await tester.enterText(find.byType(SearchBar), '');
      await tester.pump();
      expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'พาหุง'), findsOneWidget);
      expect(find.text('ทำวัตรเช้า'), findsOneWidget);

      // Panel width must match the search field; both share the same max width.
      final panelMaterial = find
          .ancestor(
            of: find.text('ค้นหาล่าสุด'),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getSize(panelMaterial).width,
        tester.getSize(find.byType(SearchBar)).width,
      );

      // Tapping a row fills the old query and filters immediately.
      await tester.tap(find.widgetWithText(ListTile, 'พาหุง'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text(prayerTitle('buddha-jaya-mangala-gatha')),
        findsOneWidget,
      );
      expect(find.text('ทำวัตรเช้า'), findsNothing);
    },
  );

  testWidgets(
    'search history keeps four latest unique queries and supports deletion',
    (WidgetTester tester) async {
      final prefsService = await pumpApp(tester);

      // Submit 5 queries plus the first again: keep 4 most recent, newest to oldest.
      for (final q in ['หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'สอง']) {
        await tester.enterText(find.byType(SearchBar), q);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      expect(prefsService.getSearchHistory(), ['สอง', 'ห้า', 'สี่', 'สาม']);

      // Tap the row's X to remove it from both UI and prefs.
      await tester.enterText(find.byType(SearchBar), '');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'ห้า'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'ห้า'), findsNothing);
      expect(prefsService.getSearchHistory(), ['สอง', 'สี่', 'สาม']);

      // Tap outside the panel to close it, release focus, and make the grid tappable.
      await tester.tapAt(const Offset(400, 2000));
      await tester.pump();
      expect(find.text('ค้นหาล่าสุด'), findsNothing);
    },
  );

  testWidgets('search history long press across frames remains usable on web and desktop', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpApp(tester);

    // **The two tests above cannot catch this bug, which is why this one exists**.
    // `tester.tap` sends pointer down and up in one frame, so the tap completes
    // before rebuild. A real finger stays down for multiple frames; if the panel
    // is removed during that time, the tap recognizer is disposed and `onTap` never fires.
    //
    // The search field used to treat the history row as an outside tap and drop
    // focus on pointer **down** (`EditableTextTapOutsideIntent`; desktop always,
    // web for all pointer devices). Losing focus removed the panel, so history
    // row taps and X buttons did nothing. Wrap the panel in `TextFieldTapRegion`.
    //
    // Use mouse to simulate this path: desktop drops focus for every device, and
    // web touch follows the same route. Android tests exempt only app touch.
    for (final q in ['หนึ่ง', 'สอง']) {
      await tester.enterText(find.byType(SearchBar), q);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
    await tester.enterText(find.byType(SearchBar), '');
    await tester.pump();
    expect(find.text('ค้นหาล่าสุด'), findsOneWidget);

    Future<void> pressAcrossFrames(Finder target) async {
      final gesture = await tester.startGesture(
        tester.getCenter(target),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 80));
      // Panel must still exist while the pointer is down, or the tap is lost.
      expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
      await gesture.up();
      await tester.pump();
    }

    // Row trailing X actually removes it.
    await pressAcrossFrames(
      find.descendant(
        of: find.widgetWithText(ListTile, 'หนึ่ง'),
        matching: find.byIcon(Icons.close),
      ),
    );
    expect(prefsService.getSearchHistory(), ['สอง']);

    // Tapping a row really searches again with that query.
    await pressAcrossFrames(find.widgetWithText(ListTile, 'สอง'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      'สอง',
    );
  });
}
