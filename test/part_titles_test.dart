import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/features/prayer_detail/widgets/prayer_content.dart';
import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Block headings on the reading screen.
///
/// Every one of the file's blocks carries a title, so short prayers get a
/// heading on nearly every line; the reader can turn them off, and a `rubric`
/// block never gets one because its heading restates the stage direction it
/// sits on.
///
/// Fixtures are read from the real data file rather than pinned: this is about
/// heading *behaviour*, not about which prayer has which title.
Prayer _prayerFromFile(String id) {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  for (final p in prayers.cast<Map<String, dynamic>>()) {
    if (p['id'] == id) return Prayer.fromJson(p);
  }
  fail('ไม่มีบท id=$id ในไฟล์ข้อมูลแล้ว');
}

/// Titles of [id]'s blocks, split by whether the block is a rubric.
({List<String> main, List<String> rubric}) _titles(String id) {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  final record = prayers.cast<Map<String, dynamic>>().firstWhere(
    (p) => p['id'] == id,
  );
  final main = <String>[];
  final rubric = <String>[];
  for (final s in (record['sections'] as List).cast<Map<String, dynamic>>()) {
    final title = s['title'] as String?;
    if (title == null || title.isEmpty) continue;
    (s['type'] == 'rubric' ? rubric : main).add(title);
  }
  return (main: main, rubric: rubric);
}

/// A prayer that has both a titled non-rubric block and a titled rubric block,
/// so one fixture exercises both rules.
String _fixtureId() {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  for (final p in prayers.cast<Map<String, dynamic>>()) {
    final t = _titles(p['id'] as String);
    if (t.main.isNotEmpty && t.rubric.isNotEmpty) return p['id'] as String;
  }
  fail('ไม่มีบทไหนมีทั้งหัวข้อท่อนปกติและหัวข้อท่อน rubric');
}

Future<void> _pump(
  WidgetTester tester,
  Prayer prayer, {
  required bool showPartTitles,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('th'),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: PrayerContent(
          prayer: prayer,
          fontScale: 1,
          readingColors: ReadingColors.auto,
          readingBrightness: Brightness.light,
          showPartTitles: showPartTitles,
          lineHeight: 1.9,
          justifyText: false,
          showPali: false,
          onTogglePali: (_) {},
          showMeaning: false,
          onToggleMeaning: (_) {},
          inlineTranslation: false,
          onInlineTranslationChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('block headings show when the setting is on', (tester) async {
    final id = _fixtureId();
    await _pump(tester, _prayerFromFile(id), showPartTitles: true);

    for (final title in _titles(id).main) {
      expect(
        find.text(title),
        findsWidgets,
        reason: 'เปิดสวิตช์แล้วแต่ไม่เห็นหัวข้อ "$title"',
      );
    }
  });

  testWidgets('turning the setting off hides every block heading', (
    tester,
  ) async {
    final id = _fixtureId();
    await _pump(tester, _prayerFromFile(id), showPartTitles: false);

    for (final title in _titles(id).main) {
      expect(
        find.text(title),
        findsNothing,
        reason: 'ปิดสวิตช์แล้วยังเห็นหัวข้อ "$title"',
      );
    }
  });

  testWidgets('a rubric block never gets a heading, even with the setting on', (
    tester,
  ) async {
    final id = _fixtureId();
    final rubricTitles = _titles(id).rubric;
    await _pump(tester, _prayerFromFile(id), showPartTitles: true);

    for (final title in rubricTitles) {
      expect(
        find.text(title),
        findsNothing,
        reason:
            'หัวข้อท่อน rubric "$title" ไม่ควรแสดง — มันซ้ำกับบรรทัดคำกำกับของตัวเอง',
      );
    }
  });

  testWidgets('the chant line itself still renders under a hidden heading', (
    tester,
  ) async {
    // Hiding the heading must not take the rubric's own line with it.
    // is a real instruction the reader needs.
    final id = _fixtureId();
    final prayer = _prayerFromFile(id);
    await _pump(tester, prayer, showPartTitles: false);

    final firstLine = prayer.text.split('\n').first.trim();
    expect(find.textContaining(firstLine), findsWidgets);
  });

  test(
    'rubric headings in the data restate their own line often enough to hide',
    () {
      // The rule is worth its own code path only because the duplication is real.
      // If a future edit makes rubric titles carry new information, this fails and
      // the rule should be revisited rather than silently kept.
      final prayers =
          jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
              as List<dynamic>;
      var rubrics = 0;
      var restating = 0;
      for (final p in prayers.cast<Map<String, dynamic>>()) {
        for (final s in (p['sections'] as List).cast<Map<String, dynamic>>()) {
          if (s['type'] != 'rubric') continue;
          rubrics++;
          final title = (s['title'] as String? ?? '')
              .replaceAll('คำกำกับ:', '')
              .trim();
          final line =
              ((s['lines'] as List).first as Map)['text'] as String? ?? '';
          if (title.isNotEmpty &&
              title == line.replaceAll(RegExp(r'[()（）]'), '').trim()) {
            restating++;
          }
        }
      }
      expect(rubrics, greaterThan(0));
      expect(
        restating / rubrics,
        greaterThan(0.4),
        reason:
            'หัวข้อท่อน rubric ไม่ซ้ำกับบรรทัดตัวเองแล้ว ($restating/$rubrics) '
            '— ทบทวนกฎที่ซ่อนหัวข้อ rubric ใน PrayerContent._partHeading',
      );
    },
  );
}
