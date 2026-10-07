import 'package:chanting/features/settings/widgets/reading_color_picker.dart';
import 'package:chanting/router/app_router.dart';
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'settings_test.dart'
    show pumpReadingSettings, pumpSettings, pumpUntilFound;

/// The reading settings page and the settings it added in September 2026.
///
/// Every one of these is a preference that only means something on the reading
/// screen, so each test follows it through to the reader rather than stopping
/// at prefs — a value that persists but never reaches the page is the failure
/// mode worth guarding.
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

  /// The reader's own Scaffold, not the shell's: the reading route is pushed
  /// above it, so `find.byType(Scaffold).first` would be the wrong one.
  Color? readerPageColor(WidgetTester tester) => tester
      .widgetList<Scaffold>(find.byType(Scaffold))
      .map((s) => s.backgroundColor)
      .whereType<Color>()
      .lastOrNull;

  testWidgets('page colour persists and paints the reading screen', (
    tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    // Ivory is the default, and it is the app's own page colour.
    expect(prefs.getReadingBackground(), isNull);

    await tester.tap(find.byKey(const ValueKey('page_color_sepia')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getReadingBackground(), 'sepia');

    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    expect(
      readerPageColor(tester),
      ReadingBackground.sepia.color,
      reason: 'เลือกสีพื้นหลังแล้วหน้าอ่านยังไม่เปลี่ยนสี',
    );
  });

  testWidgets('the night page resolves text against its own brightness', (
    tester,
  ) async {
    // The app theme is light in tests, so this is the case the whole
    // `readingBrightness` parameter exists for: dark paper under a light app.
    await pumpReadingSettings(tester);
    await tester.tap(find.byKey(const ValueKey('page_color_night')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    expect(readerPageColor(tester), ReadingBackground.night.color);
    final body = tester.widget<Text>(
      find.textContaining('อะระหัง สัมมาสัมพุทโธ').first,
    );
    expect(
      body.style?.color,
      defaultReadingText(Brightness.dark),
      reason: 'พื้นหลังกลางคืนแต่ตัวอักษรยังใช้สีของธีมสว่าง',
    );
  });

  testWidgets('showing the translation by default opens the reader with it', (
    tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);
    expect(prefs.getShowMeaningDefault(), isFalse);

    await tester.tap(find.byKey(const ValueKey('show_meaning_default')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getShowMeaningDefault(), isTrue);

    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // The reader's own chip reflects it, which is the state the content reads.
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'คำแปล').first,
    );
    expect(
      chip.selected,
      isTrue,
      reason: 'ตั้งให้เปิดคำแปลมาแต่แรก แต่หน้าอ่านยังปิดอยู่',
    );
  });

  testWidgets('the sample answers the switches underneath it', (tester) async {
    // A sample that does not move when its own switches move is a picture, not
    // a preview — and it is the only thing on the page that shows what these
    // settings do before you open a prayer.
    await pumpReadingSettings(tester);
    final roman = find.text(sampleFor(ReadingLane.roman));
    final meaning = find.text(sampleFor(ReadingLane.meaning));

    // Both lanes are off by default, exactly as the reader opens.
    expect(find.text(sampleFor(ReadingLane.chant)), findsOneWidget);
    expect(roman, findsNothing);
    expect(meaning, findsNothing);

    await tester.tap(find.byKey(const ValueKey('show_roman_default')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(roman, findsOneWidget);
    expect(meaning, findsNothing);

    await tester.tap(find.byKey(const ValueKey('show_meaning_default')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(meaning, findsOneWidget);

    // Inline off groups the companions into their own boxes, which is how the
    // reader lays them out at the end of a prayer.
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration),
      isNotEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('inline_translation')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Still both lanes, just laid out differently; losing one would mean the
    // inline switch had quietly turned a lane off.
    expect(roman, findsOneWidget);
    expect(meaning, findsOneWidget);
  });

  testWidgets('the lane colours sit with the switches naming the same lanes', (
    tester,
  ) async {
    // They were under "More" at the foot of the page for one revision and it
    // read wrong: the three rows here are the three switches above them.
    await pumpReadingSettings(tester);
    final content = tester.getTopLeft(
      find.byKey(const ValueKey('show_meaning_default')),
    );
    final colour = tester.getTopLeft(
      find.byKey(const ValueKey('lane_color_chant')),
    );
    final spacing = tester.getTopLeft(
      find.byKey(const ValueKey('line_spacing_normal')),
    );
    expect(colour.dy, greaterThan(content.dy));
    expect(
      colour.dy,
      lessThan(spacing.dy),
      reason: 'สีตัวอักษรควรอยู่ติดกับสวิตช์เลนเดียวกัน ไม่ใช่ท้ายหน้า',
    );
  });

  testWidgets('the auto-scroll delay persists through its picker', (
    tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);
    expect(prefs.getAutoScrollDelay(), 0);

    await tester.tap(find.byKey(const ValueKey('auto_scroll_delay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auto_scroll_delay_5')));
    await tester.pumpAndSettle();

    expect(prefs.getAutoScrollDelay(), 5);
    expect(find.text('5 วินาที'), findsOneWidget);
  });

  testWidgets('keep-screen-on and hide-bars default on and off respectively', (
    tester,
  ) async {
    // Both describe what the reader already did: it has always held the screen
    // awake and always started with its bars showing. The defaults must keep
    // that, or an update silently changes how the app behaves.
    final prefs = await pumpReadingSettings(tester);
    expect(prefs.getKeepScreenOn(), isTrue);
    expect(prefs.getStartImmersive(), isFalse);

    await tester.tap(find.byKey(const ValueKey('start_immersive')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getStartImmersive(), isTrue);

    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.textContaining('อะระหัง สัมมาสัมพุทโธ'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byIcon(Icons.more_vert),
      findsNothing,
      reason: 'ตั้งให้ซ่อนแถบเครื่องมือ แต่หน้าอ่านยังมีแถบบนอยู่',
    );
  });

  testWidgets('reset puts every reading setting back but leaves the theme', (
    tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    await tester.drag(
      find.byKey(const ValueKey('font_scale_slider')),
      const Offset(600, 0),
    );
    await tester.tap(find.byKey(const ValueKey('page_color_white')));
    await tester.tap(find.byKey(const ValueKey('show_meaning_default')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getFontScale(), 1.6);
    expect(prefs.getReadingBackground(), 'white');
    expect(prefs.getShowMeaningDefault(), isTrue);

    // Language and theme live on other pages; a reset here must not reach them.
    final themeBefore = prefs.getThemeMode();

    await tester.tap(find.byKey(const ValueKey('reading_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reading_reset_confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefs.getFontScale(), 1.0);
    expect(prefs.getReadingBackground(), 'ivory');
    expect(prefs.getShowMeaningDefault(), isFalse);
    expect(prefs.getLineSpacing(), 'normal');
    expect(prefs.getAutoScrollLevel(), 3);
    expect(prefs.getLaneColor('chant'), 'auto');
    expect(prefs.getThemeMode(), themeBefore);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('cancelling the reset changes nothing', (tester) async {
    final prefs = await pumpReadingSettings(tester);
    await tester.drag(
      find.byKey(const ValueKey('font_scale_slider')),
      const Offset(600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('reading_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(prefs.getFontScale(), 1.6);
  });

  testWidgets('text size stays in the reader, with a way through to the rest', (
    tester,
  ) async {
    // It is the one reading setting somebody needs mid-prayer, so it must not
    // move to the settings page — but the sheet is also where someone lands
    // when what they actually wanted was line spacing or the page colour.
    await pumpSettings(tester);
    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ขนาดตัวอักษร').last);
    await tester.pumpAndSettle();

    // Changing it here writes the same value the settings page holds.
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('เพิ่มขนาดตัวอักษร'));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reader_more_reading_settings')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('font_scale_slider')), findsOneWidget);
    expect(
      find.text('110%'),
      findsOneWidget,
      reason: 'ปรับจากหน้าอ่านแล้วหน้าตั้งค่าควรเห็นค่าเดียวกัน',
    );
  });

  test('an unknown stored page colour reads as the app default', () {
    // The value is a plain string in prefs and the enum can be trimmed later.
    expect(ReadingBackground.fromName(null), ReadingBackground.ivory);
    expect(ReadingBackground.fromName('teal'), ReadingBackground.ivory);
    expect(ReadingBackground.fromName('sepia'), ReadingBackground.sepia);
  });

  test('a dark app theme always reads on the night page', () {
    for (final chosen in ReadingBackground.values) {
      expect(
        effectiveReadingBackground(chosen, Brightness.dark),
        ReadingBackground.night,
      );
      expect(effectiveReadingBackground(chosen, Brightness.light), chosen);
    }
  });
}
