import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/features/prayer_detail/widgets/prayer_content.dart';
import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
// app_theme.dart re-exports reading_colors.dart, which is how the rest of the
// app reaches these types.
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chantLine = 'บรรทัดเนื้อบททดสอบ';
const _romanLine = 'Banthat roman thotsop';
const _meaningLine = 'บรรทัดคำแปลทดสอบ';

/// Renders one prayer with the given lane colors and returns the tester.
///
/// Drives [PrayerContent] directly rather than the whole reading screen: the
/// rule under test is which color reaches which lane, and the screen would drag
/// in chips, routing and asset loading without adding anything to that.
Future<void> _pumpContent(
  WidgetTester tester,
  ReadingColors colors, {
  Brightness brightness = Brightness.light,
}) async {
  final prayer = Prayer.fromJson({
    'id': 'lane-color-test',
    'title': 'บททดสอบสี',
    'category': 'หมวดทดสอบ',
    'order': 1,
    'text': _chantLine,
    'paliText': _romanLine,
    'meaning': _meaningLine,
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      locale: const Locale('th'),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: PrayerContent(
          prayer: prayer,
          fontScale: 1,
          readingColors: colors,
          // These tests are about the theme's own brightness, so the page
          // follows it rather than a chosen ReadingBackground.
          readingBrightness: brightness,
          showPartTitles: true,
          lineHeight: 1.9,
          justifyText: false,
          showPali: true,
          onTogglePali: (_) {},
          showMeaning: true,
          onToggleMeaning: (_) {},
          inlineTranslation: false,
          onInlineTranslationChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

/// Pure tests for the reader's per-lane colors.
///
/// This is the storage format users' saved settings live in, so it is tested
/// away from widgets like `editionDrift()` and `PracticeLog`: a
/// parse that silently degrades to `auto` loses a setting with no error, and
/// only a round-trip test catches that.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('rendering', () {
    testWidgets('each lane renders in its own color', (tester) async {
      await _pumpContent(
        tester,
        const ReadingColors(
          chant: ReadingColor.preset(AppTextColor.brown),
          roman: ReadingColor.preset(AppTextColor.blue),
          meaning: ReadingColor.preset(AppTextColor.green),
        ),
      );

      // The whole point of the split: three lanes, three colors, on one page.
      expect(
        _colorOf(tester, _chantLine),
        AppTextColor.brown.resolve(Brightness.light),
      );
      expect(
        _colorOf(tester, _romanLine),
        AppTextColor.blue.resolve(Brightness.light),
        reason: 'สีอักษรโรมันไม่ได้แยกจากเนื้อบท',
      );
      expect(
        _colorOf(tester, _meaningLine),
        AppTextColor.green.resolve(Brightness.light),
        reason: 'สีคำแปลไม่ได้แยกจากเนื้อบท',
      );
    });

    testWidgets('a chosen color is used exactly, not faded', (tester) async {
      // Companion lanes used to render at 80% of the chant color. Now that each
      // lane is chosen on its own, a picked color must be the color shown, or
      // the hex someone typed never matches what they see.
      await _pumpContent(
        tester,
        const ReadingColors(
          chant: ReadingColor.auto,
          roman: ReadingColor.custom(
            light: Color(0xFF123456),
            dark: Color(0xFF123456),
          ),
          meaning: ReadingColor.auto,
        ),
      );
      expect(_colorOf(tester, _romanLine), const Color(0xFF123456));
    });

    testWidgets('an auto lane keeps the muted companion look', (tester) async {
      // The previous appearance has to survive for anyone who never opens the
      // new setting: theme text at 80% for Pali and translation.
      await _pumpContent(tester, ReadingColors.auto);

      final onSurface = AppTheme.light().colorScheme.onSurface;
      expect(_colorOf(tester, _romanLine), onSurface.withValues(alpha: 0.8));
      expect(_colorOf(tester, _meaningLine), onSurface.withValues(alpha: 0.8));
    });

    // The two themes get a test each rather than two pumps in one: pumping a
    // second MaterialApp over the first reuses the element tree and the theme
    // change does not reach the content, which reads as a bug in the code.
    const twoThemeChant = ReadingColors(
      chant: ReadingColor.custom(
        light: Color(0xFF111111),
        dark: Color(0xFFEEEEEE),
      ),
      roman: ReadingColor.auto,
      meaning: ReadingColor.auto,
    );

    testWidgets('a custom lane uses its light color on the light theme', (
      tester,
    ) async {
      await _pumpContent(tester, twoThemeChant);
      expect(_colorOf(tester, _chantLine), const Color(0xFF111111));
    });

    testWidgets('a custom lane uses its dark color on the dark theme', (
      tester,
    ) async {
      await _pumpContent(tester, twoThemeChant, brightness: Brightness.dark);
      expect(
        _colorOf(tester, _chantLine),
        const Color(0xFFEEEEEE),
        reason: 'ธีมมืดไม่ได้ใช้สีที่ตั้งไว้สำหรับธีมมืด',
      );
    });
  });

  group('ReadingColor storage', () {
    test('a preset round-trips through its enum name', () {
      for (final preset in AppTextColor.values) {
        final color = ReadingColor.preset(preset);
        expect(color.storage, preset.name);
        expect(ReadingColor.parse(color.storage), color);
      }
    });

    test('a custom pair round-trips both themes', () {
      const color = ReadingColor.custom(
        light: Color(0xFF123456),
        dark: Color(0xFFABCDEF),
      );
      expect(color.storage, 'custom:123456:ABCDEF');

      final parsed = ReadingColor.parse(color.storage);
      expect(parsed, color);
      expect(parsed.resolve(Brightness.light), const Color(0xFF123456));
      expect(parsed.resolve(Brightness.dark), const Color(0xFFABCDEF));
    });

    test('unknown or malformed values degrade to auto, never throw', () {
      // prefs can hold a value written by an older or newer build; a reading
      // app must still open.
      for (final raw in [
        null,
        '',
        'chartreuse',
        'custom:',
        'custom:123456',
        'custom:12345:ABCDEF',
        'custom:zzzzzz:ABCDEF',
        'custom:123456:ABCDEF:extra',
      ]) {
        expect(
          ReadingColor.parse(raw),
          ReadingColor.auto,
          reason: 'ค่า $raw ควรตกกลับเป็น auto',
        );
      }
    });

    test('auto resolves to null so the caller uses the theme color', () {
      expect(ReadingColor.auto.resolve(Brightness.light), isNull);
      expect(ReadingColor.auto.resolve(Brightness.dark), isNull);
      expect(ReadingColor.auto.isAuto, isTrue);
      expect(ReadingColor.auto.isCustom, isFalse);
    });
  });

  group('ReadingColor.withCustomFor', () {
    test('edits one theme and leaves the other untouched', () {
      const start = ReadingColor.custom(
        light: Color(0xFF111111),
        dark: Color(0xFF222222),
      );
      final edited = start.withCustomFor(
        Brightness.light,
        const Color(0xFF333333),
        otherFallback: const Color(0xFF000000),
      );
      expect(edited.resolve(Brightness.light), const Color(0xFF333333));
      expect(
        edited.resolve(Brightness.dark),
        const Color(0xFF222222),
        reason: 'แก้สีธีมสว่างแล้วสีธีมมืดหายไปด้วย',
      );
    });

    test('converting a preset keeps that preset color for the other theme', () {
      const start = ReadingColor.preset(AppTextColor.brown);
      final edited = start.withCustomFor(
        Brightness.dark,
        const Color(0xFF333333),
        otherFallback: const Color(0xFF000000),
      );
      expect(edited.resolve(Brightness.dark), const Color(0xFF333333));
      expect(
        edited.resolve(Brightness.light),
        AppTextColor.brown.resolve(Brightness.light),
        reason: 'เปลี่ยนจาก preset เป็นสีเอง แล้วอีกธีมควรคงสีเดิมของ preset',
      );
    });

    test(
      'converting auto falls back to the theme color for the other side',
      () {
        final edited = ReadingColor.auto.withCustomFor(
          Brightness.light,
          const Color(0xFF333333),
          otherFallback: const Color(0xFF9ABCDE),
        );
        expect(edited.resolve(Brightness.dark), const Color(0xFF9ABCDE));
      },
    );
  });

  group('ReadingColor.parseHex', () {
    test('accepts the forms people actually paste', () {
      expect(ReadingColor.parseHex('6D4C2F'), const Color(0xFF6D4C2F));
      expect(ReadingColor.parseHex('#6D4C2F'), const Color(0xFF6D4C2F));
      expect(ReadingColor.parseHex('  6d4c2f  '), const Color(0xFF6D4C2F));
      // Three-digit shorthand expands each digit.
      expect(ReadingColor.parseHex('abc'), const Color(0xFFAABBCC));
    });

    test('rejects anything that is not a color', () {
      for (final raw in ['', '12', '12345', '1234567', 'ghijkl', '#']) {
        expect(ReadingColor.parseHex(raw), isNull, reason: raw);
      }
    });
  });

  group('ReadingColors', () {
    test('withLane changes one lane and leaves the other two alone', () {
      const brown = ReadingColor.preset(AppTextColor.brown);
      final colors = ReadingColors.auto.withLane(ReadingLane.roman, brown);

      expect(colors.of(ReadingLane.roman), brown);
      expect(colors.of(ReadingLane.chant), ReadingColor.auto);
      expect(colors.of(ReadingLane.meaning), ReadingColor.auto);
    });

    test('of() covers every lane', () {
      for (final lane in ReadingLane.values) {
        expect(ReadingColors.auto.of(lane), ReadingColor.auto);
      }
    });
  });

  group('contrast', () {
    test('ratio is symmetric and spans the WCAG range', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
    });

    test('flags a color that would be unreadable on the reading page', () {
      // Pale gold on cream is the kind of pick the warning exists for.
      expect(
        hasLowContrast(
          const Color(0xFFEBD9A8),
          readingBackground(Brightness.light),
        ),
        isTrue,
      );
      expect(
        hasLowContrast(
          defaultReadingText(Brightness.light),
          readingBackground(Brightness.light),
        ),
        isFalse,
      );
      expect(
        hasLowContrast(
          defaultReadingText(Brightness.dark),
          readingBackground(Brightness.dark),
        ),
        isFalse,
      );
    });

    test('every shipped preset clears the body-text bar in both themes', () {
      // A preset is offered as a safe choice, so it is held to the same bar the
      // picker warns at — not the looser large-text tier, which is what `gold`
      // needed before it was darkened. Custom picks remain the user's own call.
      for (final preset in AppTextColor.values) {
        for (final brightness in Brightness.values) {
          final color =
              preset.resolve(brightness) ?? defaultReadingText(brightness);
          expect(
            contrastRatio(color, readingBackground(brightness)),
            greaterThanOrEqualTo(kMinReadableContrast),
            reason: '${preset.name} อ่านไม่ออกบนธีม ${brightness.name}',
          );
        }
      }
    });

    test('no shipped preset trips the picker\'s own contrast warning', () {
      // `gold` used to, at 3.63:1 on cream, which meant picking the app's own
      // preset produced the app's own complaint. Darkened to 5.09:1. A new
      // preset below the bar should fail here rather than ship and warn.
      final warned = <String>[
        for (final preset in AppTextColor.values)
          for (final brightness in Brightness.values)
            if (hasLowContrast(
              preset.resolve(brightness) ?? defaultReadingText(brightness),
              readingBackground(brightness),
            ))
              '${preset.name}/${brightness.name}',
      ];
      expect(warned, isEmpty);
    });
  });

  group('lane colors in prefs', () {
    test('a legacy text_color seeds all three lanes', () async {
      // Someone who already picked a color keeps the look they had; the three
      // lanes only diverge once one of them is edited.
      SharedPreferences.setMockInitialValues({'text_color': 'brown'});
      final prefs = await PrefsService.init();

      for (final lane in ReadingLane.values) {
        expect(prefs.getLaneColor(lane.name), 'brown');
      }

      await prefs.setLaneColor(ReadingLane.roman.name, 'green');
      expect(prefs.getLaneColor(ReadingLane.roman.name), 'green');
      expect(
        prefs.getLaneColor(ReadingLane.chant.name),
        'brown',
        reason: 'แก้ลานเดียวแล้วลานอื่นควรยังใช้ค่าเดิมจาก text_color',
      );
    });

    test('no saved value at all means auto', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsService.init();
      for (final lane in ReadingLane.values) {
        expect(prefs.getLaneColor(lane.name), 'auto');
      }
    });
  });
}
