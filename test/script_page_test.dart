import 'dart:convert';
import 'dart:io';

import 'package:chanting/features/settings/script_screen.dart';
import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The script reference page (`/script`).
///
/// It exists because the two scripts shown side by side do **not** correspond
/// letter for letter, and mistaking one for the other has already produced real
/// transcription errors (docs/roadmap/todo.md). These tests keep the explanation honest: the
/// table must cover the diacritics the data actually uses, and its examples must
/// be words that really appear in the file.
Set<String> _diacriticsInData() {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  final found = <String>{};
  for (final p in prayers.cast<Map<String, dynamic>>()) {
    for (final s
        in (p['sections'] as List? ?? []).cast<Map<String, dynamic>>()) {
      for (final l in (s['lines'] as List).cast<Map<String, dynamic>>()) {
        for (final ch in (l['roman'] as String? ?? '').split('')) {
          if (ch.codeUnitAt(0) > 127) found.add(ch.toLowerCase());
        }
      }
    }
  }
  return found;
}

/// Every `roman`/`text` word pair in the file, for checking the examples.
List<(String, String)> _wordPairs() {
  final prayers =
      jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
          as List<dynamic>;
  final pairs = <(String, String)>[];
  for (final p in prayers.cast<Map<String, dynamic>>()) {
    for (final s
        in (p['sections'] as List? ?? []).cast<Map<String, dynamic>>()) {
      for (final l in (s['lines'] as List).cast<Map<String, dynamic>>()) {
        final roman = l['roman'] as String?;
        final text = l['text'] as String?;
        if (roman == null || text == null) continue;
        final rw = roman.replaceAll(RegExp(r'[,.]'), '').split(RegExp(r'\s+'));
        final tw = text.replaceAll(RegExp(r'[,.]'), '').split(RegExp(r'\s+'));
        if (rw.length != tw.length) continue;
        for (var i = 0; i < rw.length; i++) {
          pairs.add((rw[i], tw[i]));
        }
      }
    }
  }
  return pairs;
}

Future<void> _pumpAbout(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ScriptScreen(),
    ),
  );
  await tester.pump();
}

/// Concatenated text of every Text widget currently on screen.
String _screenText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('the guide is reachable from both places that need it', () {
    // A route nothing links to is a page nobody finds. About is where someone
    // browsing the app looks; the reading menu is where the question actually
    // comes up, mid-prayer, at a mark they do not recognise.
    expect(
      File('lib/router/app_router.dart').readAsStringSync(),
      contains("path: '/script'"),
      reason: 'ยังไม่ได้ลงทะเบียน route /script',
    );
    for (final entry in const [
      'lib/features/settings/about_screen.dart',
      'lib/features/prayer_detail/widgets/reading_menu.dart',
    ]) {
      expect(
        File(entry).readAsStringSync(),
        contains('/script'),
        reason: '$entry ไม่ได้ลิงก์ไปหน้าอักษรและการถอดเสียง',
      );
    }
  });

  testWidgets('the script section renders in Thai', (tester) async {
    await _pumpAbout(tester, const Locale('th'));
    final screen = _screenText(tester);

    expect(screen, contains('อักษรและการถอดเสียง'));
    // The point of the section: the Thai reading is a pronunciation guide.
    expect(screen, contains('ทะวิ'));
    expect(screen, contains('อัญชะลี'));
  });

  testWidgets('the script section renders in English too', (tester) async {
    await _pumpAbout(tester, const Locale('en'));
    expect(_screenText(tester), contains('Script & transliteration'));
  });

  testWidgets('the niggahita note names both conventions, not one loosely', (
    tester,
  ) async {
    // docs/content/prayer-schema.md section 3 is explicit that IAST and PTS disagree here, so
    // the note must not present one form as simply "the standard".
    await _pumpAbout(tester, const Locale('th'));
    final screen = _screenText(tester);

    expect(screen, contains('ṃ'));
    expect(screen, contains('ṁ'));
    expect(screen, contains('IAST'));
    expect(screen, contains('PTS'));
  });

  testWidgets('the table covers every diacritic the data actually uses', (
    tester,
  ) async {
    // Adding a character to the data without explaining it here leaves readers
    // with a mark the app never accounts for.
    await _pumpAbout(tester, const Locale('th'));
    final screen = _screenText(tester);

    final used = _diacriticsInData();
    expect(used, isNotEmpty);
    for (final ch in used) {
      expect(
        screen,
        contains(ch),
        reason: 'ข้อมูลใช้ "$ch" แต่ตารางในหน้าเกี่ยวกับแอปไม่ได้อธิบายไว้',
      );
    }
  });

  testWidgets('every example in the table is a real word pair from the file', (
    tester,
  ) async {
    // The examples claim "this Roman word is written this way in Thai script".
    // If content is edited so a pair no longer matches, the claim is false.
    await _pumpAbout(tester, const Locale('th'));
    final examples = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains(' · '))
        .toList();
    expect(examples, isNotEmpty, reason: 'ไม่พบบรรทัดตัวอย่างในตาราง');

    final pairs = _wordPairs();
    for (final example in examples) {
      final parts = example.split(' · ');
      expect(parts, hasLength(2), reason: example);
      final roman = parts[0].trim();
      final thai = parts[1].trim();
      expect(
        pairs.any((p) => p.$1 == roman && p.$2 == thai),
        isTrue,
        reason:
            'ตัวอย่าง "$roman · $thai" ไม่ตรงกับคู่คำใดในไฟล์ข้อมูลแล้ว '
            '— แก้ตัวอย่างในหน้าเกี่ยวกับแอปให้ตรงกับเนื้อหาปัจจุบัน',
      );
    }
  });
}
