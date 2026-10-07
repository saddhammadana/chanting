import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/settings/widgets/reading_color_picker.dart';
import 'package:chanting/router/app_router.dart';
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
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

/// Open the app and the settings hub with a tall screen so all rows fit.
Future<PrefsService> pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 5000);
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
  await pumpUntilFound(tester, find.byKey(const ValueKey('nav_settings')));
  await tester.tap(find.byKey(const ValueKey('nav_settings')));
  await pumpUntilFound(tester, find.byKey(const ValueKey('settings_theme')));
  await tester.pump(const Duration(seconds: 1));
  return prefsService;
}

/// Opens one settings sub-page from the hub and waits for it to arrive.
///
/// Settings is a hub of seven rows; every control the tests below drive lives
/// one page deeper. Going by row key rather than by label keeps these helpers
/// working when the wording changes.
Future<void> openSettingsPage(
  WidgetTester tester,
  String rowKey,
  Finder arrived,
) async {
  await tester.tap(find.byKey(ValueKey(rowKey)));
  await pumpUntilFound(tester, arrived);
  await tester.pump(const Duration(seconds: 1));
}

/// Opens settings and drills straight into the reading/text sub-page.
Future<PrefsService> pumpReadingSettings(WidgetTester tester) async {
  final prefs = await pumpSettings(tester);
  await openSettingsPage(
    tester,
    'settings_reading',
    find.byKey(const ValueKey('font_scale_slider')),
  );
  return prefs;
}

/// Opens settings and drills straight into the goal / reminders sub-page.
Future<PrefsService> pumpGoalSettings(WidgetTester tester) async {
  final prefs = await pumpSettings(tester);
  await openSettingsPage(
    tester,
    'settings_goal',
    find.byKey(const ValueKey('goal_time')),
  );
  return prefs;
}

/// Opens settings and drills straight into the sound sub-page.
Future<PrefsService> pumpSoundSettings(WidgetTester tester) async {
  final prefs = await pumpSettings(tester);
  await openSettingsPage(tester, 'settings_sound', find.text('เงียบ'));
  return prefs;
}

/// Opens settings and drills straight into the language sub-page.
Future<PrefsService> pumpLanguageSettings(WidgetTester tester) async {
  final prefs = await pumpSettings(tester);
  await openSettingsPage(
    tester,
    'settings_language',
    find.byKey(const ValueKey('language_en')),
  );
  return prefs;
}

/// Taps the AppBar back button and waits for the previous page.
///
/// Every settings page now draws the shared `AppBackButton`
/// (`app_back_button`), not a `BackButton`. Prefer the key and fall back to
/// the type anyway, or this helper breaks the moment a page reverts to the
/// framework default.
Future<void> settingsBack(WidgetTester tester) async {
  final keyed = find.byKey(const ValueKey('app_back_button'));
  await tester.tap(keyed.evaluate().isEmpty ? find.byType(BackButton) : keyed);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

String _hex(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();

/// Opens one lane's color dialog, taps a preset swatch, and confirms.
///
/// The swatches moved into a dialog when the setting split into three lanes, so
/// a test can no longer tap them straight off the settings page.
Future<void> pickLanePreset(
  WidgetTester tester,
  ReadingLane lane,
  String preset,
) async {
  await tester.tap(find.byKey(ValueKey('lane_color_${lane.name}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('preset_$preset')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('color_confirm')));
  await tester.pumpAndSettle();
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

  testWidgets('font size slider persists the selected value', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpReadingSettings(tester);
    expect(find.text('100%'), findsOneWidget);

    // Keyed, not positional: settings gained a third slider in September 2026
    // and index 1 silently became the daily-goal one.
    await tester.drag(
      find.byKey(const ValueKey('font_scale_slider')),
      const Offset(600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('160%'), findsOneWidget);
    expect(prefsService.getFontScale(), 1.6);
  });

  testWidgets('text color selection persists the selected value', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpReadingSettings(tester);

    await pickLanePreset(tester, ReadingLane.chant, 'brown');

    // The current-value label updates and prefs store the enum name.
    expect(find.text('น้ำตาล'), findsWidgets);
    expect(prefsService.getLaneColor('chant'), 'brown');
  });

  testWidgets('each reading lane keeps its own color', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    await pickLanePreset(tester, ReadingLane.chant, 'brown');
    await pickLanePreset(tester, ReadingLane.roman, 'green');

    // The point of the feature: setting one lane must not move the others.
    expect(prefs.getLaneColor('chant'), 'brown');
    expect(prefs.getLaneColor('roman'), 'green');
    expect(
      prefs.getLaneColor('meaning'),
      'auto',
      reason: 'ตั้งสีลานหนึ่งแล้วไปเปลี่ยนลานที่ไม่ได้แตะด้วย',
    );

    // The sample only draws a companion lane when that lane is switched on —
    // it answers those switches on purpose — so turn them on before reading
    // colors off it.
    for (final key in ['show_roman_default', 'show_meaning_default']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    // And the preview shows all three, so the colors are actually distinct on
    // screen rather than only in prefs.
    Color? previewColor(ReadingLane lane) =>
        tester.widget<Text>(find.text(sampleFor(lane)).first).style?.color;
    expect(
      previewColor(ReadingLane.chant),
      AppTextColor.brown.resolve(Brightness.light),
    );
    expect(
      previewColor(ReadingLane.roman),
      AppTextColor.green.resolve(Brightness.light),
    );
  });

  testWidgets('a custom color can be typed as a hex code and persists', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    await tester.tap(find.byKey(const ValueKey('lane_color_meaning')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('color_hex_field')),
      '3366CC',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('color_confirm')));
    await tester.pumpAndSettle();

    // Tests run on the light theme, so the typed value lands in the light slot
    // and the dark slot falls back to that theme's own text color.
    expect(
      prefs.getLaneColor('meaning'),
      'custom:3366CC:${_hex(defaultReadingText(Brightness.dark))}',
    );
    expect(prefs.getLaneColor('chant'), 'auto');
  });

  testWidgets('dragging the color field produces a custom color', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    await tester.tap(find.byKey(const ValueKey('lane_color_chant')));
    await tester.pumpAndSettle();
    // Land in the saturated top-left region of the square; the exact color does
    // not matter, only that a drag reaches the setting at all.
    await tester.drag(
      find.byKey(const ValueKey('color_sv_field')),
      const Offset(40, -20),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('color_confirm')));
    await tester.pumpAndSettle();

    expect(prefs.getLaneColor('chant'), startsWith('custom:'));
    expect(ReadingColor.parse(prefs.getLaneColor('chant')).isCustom, isTrue);
  });

  testWidgets('block-heading switch persists and defaults to on', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    // Default is on: every block in the file has a title, so defaulting to off
    // would hide headings that already ship.
    expect(prefs.getShowPartTitles(), isTrue);

    await tester.tap(find.byKey(const ValueKey('show_part_titles')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefs.getShowPartTitles(), isFalse);
  });

  testWidgets('completion signal defaults to vibrate and persists a change', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpSoundSettings(tester);

    // Sound is opt-in: the app held a no-audio line until this shipped, so an
    // update must not start ringing a bell unasked.
    expect(prefs.getCompletionSignal(), 'haptic');

    await tester.tap(find.text('เงียบ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefs.getCompletionSignal(), 'silent');
  });

  testWidgets('vibrate offers a test button, because nothing can detect it', (
    WidgetTester tester,
  ) async {
    // The app cannot read whether the device has vibration switched off —
    // HapticFeedback is fire-and-forget and iOS exposes no way to ask — so
    // pressing a button is the only way a user can find out. Losing this
    // button would leave a setting that silently does nothing.
    await pumpSoundSettings(tester);
    final test = find.byKey(const ValueKey('completion_signal_test'));

    // Default is vibrate, so the button is there from the start.
    expect(test, findsOneWidget);
    expect(find.text('ลองสั่น'), findsOneWidget);

    await tester.tap(find.text('เงียบ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(test, findsNothing, reason: 'เงียบแล้วไม่ควรมีปุ่มลองอะไรให้กด');

    await tester.tap(find.text('สั่น'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(test, findsOneWidget);
  });

  testWidgets('the bell has its own volume, shown only while it is chosen', (
    WidgetTester tester,
  ) async {
    final prefs = await pumpSoundSettings(tester);
    final card = find.byKey(const ValueKey('completion_volume_card'));
    final slider = find.byKey(const ValueKey('completion_volume'));

    // Vibrate is the default, and a volume for a vibration means nothing.
    expect(card, findsNothing);

    await tester.tap(find.text('เสียงระฆัง'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(card, findsOneWidget);
    // Full until the slider is first moved.
    expect(tester.widget<Slider>(slider).value, 1.0);
    expect(prefs.getCompletionVolume(), isNull);

    tester.widget<Slider>(slider).onChanged!(0.4);
    await tester.pump();
    expect(prefs.getCompletionVolume(), 0.4);
    expect(tester.widget<Slider>(slider).value, 0.4);

    await tester.tap(find.text('สั่น'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(card, findsNothing);
    // Put away, not forgotten.
    expect(prefs.getCompletionVolume(), 0.4);
  });

  testWidgets('reading mode can switch to continuous vertical reading', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpReadingSettings(tester);

    await tester.tap(find.text('แนวยาวต่อเนื่อง'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefsService.getContinuousReading(), isTrue);
    expect(find.textContaining('เลื่อนอ่านได้รวดเดียว'), findsOneWidget);
  });

  testWidgets(
    'disabling auto scroll hides the play button on the reader page',
    (WidgetTester tester) async {
      final prefsService = await pumpReadingSettings(tester);

      // Keyed, not positional: the reading page gained the content-lane
      // switches above this one in September 2026, and `Switch.first` silently
      // became one of those.
      await tester.tap(find.byKey(const ValueKey('auto_scroll_enabled')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(prefsService.getAutoScrollEnabled(), isFalse);
      expect(find.textContaining('ปิดอยู่'), findsOneWidget);

      // The reading page must not show the auto-scroll button. Route straight
      // there: this sub-page is pushed above the shell, so the bottom nav is
      // not on screen to tap.
      appRouter.go('/all');
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pump(const Duration(seconds: 1));
      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('auto_scroll_button')), findsNothing);
    },
  );

  // The counterpart that keeps the test above honest: without it, a renamed
  // key would make "findsNothing" pass whether or not the setting works.
  testWidgets('with auto scroll on, the reader page shows the play button', (
    WidgetTester tester,
  ) async {
    final prefsService = await pumpReadingSettings(tester);
    expect(prefsService.getAutoScrollEnabled(), isTrue);

    appRouter.go('/all');
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pump(const Duration(seconds: 1));
    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Presence only: on this 5000px viewport the prayer does not overflow, so
    // pressing play reaches the end on the first tick and stops again.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('auto_scroll_button')),
        matching: find.byTooltip('เลื่อนหน้าอัตโนมัติ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('developer contact dialog can be opened', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    // Contact moved onto the About page when settings became a hub: the
    // artwork gives its About group exactly two rows.
    await openSettingsPage(
      tester,
      'settings_about',
      find.text('ติดต่อผู้พัฒนา'),
    );

    await tester.tap(find.text('ติดต่อผู้พัฒนา'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    await tester.tap(find.text('ปิด'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ปิด'), findsNothing);

    // No donate section: there is still no PromptPay or payment channel set
    // up. Its Thai copy is kept in the .arb files ready for the day there is
    // one — the commented-out block that used to hold its place went with the
    // settings page's rewrite into a hub.
    expect(find.text('สนับสนุนผู้พัฒนา (Donate)'), findsNothing);
  });

  testWidgets('selecting English changes UI language and persists the setting', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester);

    // Always starts in Thai, even when the test device locale is en_US.
    expect(find.text('ตั้งค่า'), findsWidgets);
    expect(find.text('Settings'), findsNothing);

    await openSettingsPage(
      tester,
      'settings_language',
      find.byKey(const ValueKey('language_en')),
    );
    await tester.tap(find.byKey(const ValueKey('language_en')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settingsBack(tester);

    // Text moved into .arb must update too; this fails if MaterialApp ignores
    // the settings locale or delegates are missing.
    for (final english in [
      'Settings',
      'Reading',
      'Reading settings',
      'Reminders',
      'Goal & reminders',
      'General',
      'Language',
      'Theme',
      'About this app',
      'Legal & privacy',
    ]) {
      expect(
        find.text(english),
        findsWidgets,
        reason: 'ยังไม่ได้แปล: $english',
      );
    }
    for (final thai in [
      'ตั้งค่า',
      'การอ่าน',
      'ตั้งค่าการอ่าน',
      'การแจ้งเตือน',
      'เป้าหมายและการแจ้งเตือน',
      'ทั่วไป',
      'ภาษา',
      'ธีม',
      'เกี่ยวกับแอป',
      'กฎหมายและความเป็นส่วนตัว',
    ]) {
      expect(find.text(thai), findsNothing, reason: 'ยังค้างภาษาไทย: $thai');
    }

    // Labels used to be embedded in const enums (AppTextColor / AppLineSpacing).
    // This is docs/internationalization.md trap 1: if extraction failed, they would stay Thai.
    await openSettingsPage(
      tester,
      'settings_reading',
      find.byKey(const ValueKey('font_scale_slider')),
    );
    expect(find.text('Match theme'), findsWidgets);
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('ตามธีม'), findsNothing);
    expect(find.text('ปกติ'), findsNothing);
    // Sample prayer content stays Thai; content does not follow the UI language.
    expect(find.textContaining('อะระหัง'), findsWidgets);
    await settingsBack(tester);

    expect(prefs.getLocale(), 'en');

    // Can switch back; language names are endonyms, not translated UI labels.
    await openSettingsPage(
      tester,
      'settings_language',
      find.byKey(const ValueKey('language_th')),
    );
    expect(find.text('ไทย'), findsWidgets);
    expect(find.text('Thai'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('language_th')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settingsBack(tester);
    expect(find.text('ตั้งค่า'), findsWidgets);
    expect(prefs.getLocale(), 'th');
  });

  testWidgets('changing language updates the prayer list edition immediately', (
    tester,
  ) async {
    // Old bug: PrayerListController used ref.read on the repository, leaving the
    // list stuck on the old language until app restart.
    await pumpSettings(tester);

    await openSettingsPage(
      tester,
      'settings_language',
      find.byKey(const ValueKey('language_en')),
    );
    await tester.tap(find.byKey(const ValueKey('language_en')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    appRouter.go('/');
    // The home UI changes language immediately without reopening the app.
    // Not the greeting: that follows the clock.
    await pumpUntilFound(tester, find.text('View all'));

    // Category and prayer names switch to the English content edition too.
    expect(find.text('Morning Chanting'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('nav_prayers')));
    await pumpUntilFound(tester, find.text('Veneration of the Triple Gem'));
  });

  testWidgets(
    'reminder time picker persists the time and enables reminders automatically',
    (tester) async {
      final prefs = await pumpGoalSettings(tester);

      // Default: off at 07:00.
      expect(prefs.getReminderEnabled('morning'), isFalse);
      expect(prefs.getReminderTime('morning', fallback: '07:00'), '07:00');

      // The time row opens the picker; the switch beside it is a separate row,
      // so tapping here cannot be mistaken for switching the reminder on.
      await tester.tap(find.byKey(const ValueKey('goal_time')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Picker must be Thai; it used to show English Cancel/OK inside the Thai app.
      // This was the Phase 0 bug in docs/internationalization.md. helpText comes from our .arb.
      expect(find.text('เวลาเตือนทำวัตรเช้า'), findsOneWidget);
      expect(find.text('ตกลง'), findsOneWidget);
      expect(find.text('OK'), findsNothing);

      // Drive the wheels through their controllers; a drag is not precise
      // enough to guarantee the intended time.
      for (final (key, item) in [
        ('time_wheel_hour', 5),
        ('time_wheel_minute', 45),
      ]) {
        tester
            .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
            .scrollController!
            .jumpToItem(item);
      }
      await tester.pump();
      await tester.tap(find.text('ตกลง'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Choosing a time while disabled must enable reminders too, not silently
      // save the time only. This is intentional; see GoalScreen._pickTime.
      expect(prefs.getReminderTime('morning', fallback: '07:00'), '05:45');
      expect(prefs.getReminderEnabled('morning'), isTrue);
    },
  );

  testWidgets('text color selection affects the reader page not only prefs', (
    tester,
  ) async {
    final prefs = await pumpReadingSettings(tester);

    await pickLanePreset(tester, ReadingLane.chant, 'brown');
    expect(prefs.getLaneColor('chant'), 'brown');

    // Open the reading page and verify content is painted with that color.
    appRouter.go('/prayer/ratanattaya-vandana');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    final body = tester.widget<Text>(
      find.textContaining('อะระหัง สัมมาสัมพุทโธ').first,
    );
    expect(
      body.style?.color,
      AppTextColor.brown.resolve(Brightness.light),
      reason:
          'เนื้อหาบทสวดไม่ได้ใช้สีที่ตั้งไว้ — ค่าถูกบันทึกแต่ไม่ถึงหน้าอ่าน',
    );
  });

  testWidgets('about page follows the selected language', (tester) async {
    await pumpSettings(tester);

    await openSettingsPage(
      tester,
      'settings_about',
      find.text('สัญญาอนุญาตโอเพนซอร์ส'),
    );
    expect(find.textContaining('แอปอ่านหนังสือสวดมนต์'), findsOneWidget);
    expect(find.text('สัญญาอนุญาตโอเพนซอร์ส'), findsOneWidget);
    // English-translation notes do not appear in Thai; Thai uses book translations.
    expect(find.text('คำแปลภาษาอังกฤษ'), findsNothing);

    await settingsBack(tester);

    await openSettingsPage(
      tester,
      'settings_language',
      find.byKey(const ValueKey('language_en')),
    );
    await tester.tap(find.byKey(const ValueKey('language_en')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settingsBack(tester);

    await openSettingsPage(
      tester,
      'settings_about',
      find.text('Open-source licences'),
    );

    expect(find.textContaining('Thai–Pali prayer book'), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
    // English edition shows a note that the translation is unofficial.
    expect(find.text('English translation'), findsOneWidget);
    expect(find.textContaining('Unofficial'), findsOneWidget);
    expect(find.text('Chanting'), findsWidgets);
    expect(find.textContaining('แอปอ่านหนังสือสวดมนต์'), findsNothing);
    expect(find.text('สวดมนต์'), findsNothing);
  });
}
