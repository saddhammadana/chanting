import 'dart:convert';
import 'dart:io';

import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the i18n structure, the only guard that catches missing translations
/// or missing files after adding a language.
///
/// gen-l10n does not complain when one locale's .arb is missing a key. It
/// silently falls back to the template text (Thai), so English users can see Thai
/// in the app with no visible error. These tests turn missed translations into
/// CI failures.
void main() {
  final arbDir = Directory('lib/l10n');

  Map<String, dynamic> readArb(String languageCode) {
    final file = File('${arbDir.path}/app_$languageCode.arb');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'ไม่มี ${file.path} — AppLocale.$languageCode ประกาศไว้แล้วแต่ไม่มีไฟล์แปล\n'
          'เพิ่มภาษาใหม่ต้องทำสองอย่างพร้อมกัน: ค่าใน AppLocale + ไฟล์ .arb',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Actual translated keys, excluding metadata (`@@locale`, `@keyName`).
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('every AppLocale has an arb file with all message keys', () {
    final template = messageKeys(readArb('th'));
    expect(template, isNotEmpty, reason: 'app_th.arb ว่าง');

    for (final locale in AppLocale.values) {
      final code = locale.languageCode;
      // system is not a real language and has no file.
      if (code == null) continue;

      final keys = messageKeys(readArb(code));
      final missing = template.difference(keys);
      final extra = keys.difference(template);

      expect(
        missing,
        isEmpty,
        reason:
            'app_$code.arb แปลตก ${missing.length} key: $missing\n'
            'ถ้าไม่เติม ผู้ใช้ภาษานี้จะเห็นข้อความไทยโผล่มาแทนแบบเงียบ ๆ',
      );
      expect(
        extra,
        isEmpty,
        reason:
            'app_$code.arb มี key ที่ไม่มีใน template: $extra\n'
            'เพิ่ม key ใหม่ต้องเริ่มที่ app_th.arb (template) ก่อนเสมอ',
      );
    }
  });

  test('every arb file is declared by AppLocale', () {
    // Other guard: a translation file not declared in AppLocale cannot be selected.
    final declared = AppLocale.values
        .map((e) => e.languageCode)
        .whereType<String>()
        .toSet();
    final onDisk = arbDir
        .listSync()
        .whereType<File>()
        .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?.group(1))
        .whereType<String>()
        .toSet();
    expect(
      onDisk.difference(declared),
      isEmpty,
      reason:
          'มีไฟล์ .arb ที่ไม่ได้ประกาศใน AppLocale — ผู้ใช้จะเลือกภาษานี้ไม่ได้',
    );
  });

  test(
    'supportedLocales matches AppLocale and excludes the system locale marker',
    () {
      expect(AppLocale.supported, isNot(contains(null)));
      expect(
        AppLocale.supported.map((l) => l.languageCode).toSet(),
        {'th', 'en'},
        reason: 'อัปเดตเทสต์นี้เมื่อเพิ่มภาษา — ตั้งใจให้สะดุดตอนเพิ่ม',
      );
      expect(AppLocale.system.locale, isNull);
    },
  );

  test('default locale is always Thai regardless of saved prefs', () {
    // Thai app, Thai content: other device languages should not get English UI by default.
    expect(AppLocale.fromName(null), AppLocale.th);
    expect(AppLocale.fromName('ยังไม่รองรับ'), AppLocale.th);
    expect(AppLocale.fromName('en'), AppLocale.en);
    expect(AppLocale.fromName('system'), AppLocale.system);
  });

  testWidgets('ICU plurals resolve correctly for each locale', (tester) async {
    // Main reason for using gen-l10n instead of handwritten AppStrings: Thai has no
    // plural form, English does. Naive string concatenation would produce "1 prayers".
    final results = <String, List<String>>{};
    for (final locale in AppLocale.supported) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocale.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      results[locale.languageCode] = [
        l10n.playlistPrayerCount(0),
        l10n.playlistPrayerCount(1),
        l10n.playlistPrayerCount(5),
      ];
    }
    expect(results['th'], ['0 บท', '1 บท', '5 บท']);
    expect(results['en'], ['No prayers', '1 prayer', '5 prayers']);
  });

  testWidgets('AppLocalizations loads every locale and returns distinct text', (
    tester,
  ) async {
    final seen = <String, String>{};
    for (final locale in AppLocale.supported) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocale.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      seen[locale.languageCode] = l10n.settingsTitle;
    }
    expect(seen['th'], 'ตั้งค่า');
    expect(seen['en'], 'Settings');
    expect(
      seen.values.toSet().length,
      seen.length,
      reason: 'บางภาษาให้ข้อความเดียวกัน — แปลว่า .arb ไม่ได้ถูกใช้จริง',
    );
  });
}
