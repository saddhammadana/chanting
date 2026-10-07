import 'dart:convert';
import 'dart:io';

import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app name lives in **two disconnected worlds** and they must match:
///
/// - **Home screen**: `android/app/src/main/res/values*/strings.xml`
///   Android chooses this from the **device** language.
/// - **In app**: `appName` in `lib/l10n/app_*.arb`
///   This follows the language set by the user in settings (Thai by default).
///
/// Nothing links these two places. Updating one and forgetting the other makes
/// the icon label and in-app name differ, with no visible error. This test is the
/// only guard.
///
/// **APK builds are unavailable on dev machines** (no Android SDK; see CLAUDE.md),
/// so reading XML directly is the only way to check this before CI.
void main() {
  /// Reads `app_name` from strings.xml. A regex is enough for this controlled file
  /// because it contains only one string; no full XML parser is needed.
  String androidLabel(String valuesDir) {
    final file = File('android/app/src/main/res/$valuesDir/strings.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'ไม่มี ${file.path} — Android จะไม่มีชื่อแอปสำหรับภาษานี้',
    );
    final m = RegExp(
      r'<string name="app_name">([^<]+)</string>',
    ).firstMatch(file.readAsStringSync());
    expect(m, isNotNull, reason: '${file.path}: ไม่พบ string ชื่อ app_name');
    return m!.group(1)!;
  }

  Future<String> arbAppName(String lang) async {
    final raw = File('lib/l10n/app_$lang.arb').readAsStringSync();
    return (jsonDecode(raw) as Map<String, dynamic>)['appName'] as String;
  }

  test(
    'AndroidManifest uses @string/app_name instead of a hardcoded label',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:label="@string/app_name"'),
        reason:
            'ฮาร์ดโค้ด android:label ไว้ ชื่อแอปจะไม่เปลี่ยนตามภาษาเครื่อง '
            'และ values-en/ ที่มีอยู่ก็ไม่มีใครใช้',
      );
    },
  );

  test('home screen app name matches the in-app name for every locale', () async {
    // values/ with no suffix is Android's default, which is Thai.
    // This matches the app's always-Thai default.
    expect(
      androidLabel('values'),
      await arbAppName('th'),
      reason:
          'ชื่อบนหน้าจอโฮม (values/strings.xml) ไม่ตรงกับ appName ใน app_th.arb',
    );
    expect(
      androidLabel('values-en'),
      await arbAppName('en'),
      reason:
          'ชื่อบนหน้าจอโฮม (values-en/strings.xml) ไม่ตรงกับ appName ใน app_en.arb',
    );
  });

  test('every supported app locale defines an Android label', () {
    // If AppLocale gains a language but values-<lang>/ is missing, devices in
    // that language show the Thai home-screen label while the app uses their locale.
    for (final locale in AppLocale.supported) {
      final code = locale.languageCode;
      // Thai is Android's default in values/, not values-th/.
      final dir = code == 'th' ? 'values' : 'values-$code';
      expect(
        File('android/app/src/main/res/$dir/strings.xml').existsSync(),
        isTrue,
        reason:
            'AppLocale มี $code แต่ไม่มี android/.../res/$dir/strings.xml — '
            'เพิ่มภาษาต้องเพิ่ม label ของ Android ด้วย',
      );
    }
  });

  testWidgets(
    'onGenerateTitle uses the localized appName for task switcher titles',
    (tester) async {
      // MaterialApp `title:` is const and cannot call l10n; use only
      // onGenerateTitle. Switching back to title: would freeze the name in one language.
      for (final locale in AppLocale.supported) {
        late String title;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocale.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            home: Builder(
              builder: (context) {
                title = AppLocalizations.of(context).appName;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(title, await arbAppName(locale.languageCode));
      }
    },
  );
}
