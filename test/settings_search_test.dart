import 'package:chanting/features/settings/settings_search_screen.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'settings_test.dart' show pumpSettings, pumpUntilFound;

/// The settings search index.
///
/// It is a hand-kept list, so what can be checked is that everything in it
/// leads somewhere real and is findable by its own name — a broken route or a
/// duplicate entry is silent otherwise, and the whole point of the search is
/// that a setting is not lost behind the hub's seven rows.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  testWidgets('every indexed setting is findable and opens its page', (
    tester,
  ) async {
    await pumpSettings(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const ValueKey('settings_theme'))),
    );
    final entries = settingsSearchEntries(l10n);
    expect(entries, isNotEmpty);

    // No entry may repeat a title: two rows reading the same thing give the
    // user no way to tell which page they are about to open.
    expect(
      entries.map((e) => e.title).toSet(),
      hasLength(entries.length),
      reason: 'ดัชนีค้นหามีชื่อซ้ำ',
    );

    for (final entry in entries) {
      await tester.tap(find.byKey(const ValueKey('settings_search_button')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('settings_search_field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('settings_search_field')),
        entry.title,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(entry.title),
        findsWidgets,
        reason: 'ค้นชื่อของตัวเองแล้วไม่เจอ: ${entry.title}',
      );
      await tester.tap(find.text(entry.title).last);
      await tester.pumpAndSettle();

      // Landed on a real page, not the router's not-found screen.
      expect(
        find.text(l10n.notFound),
        findsNothing,
        reason: 'เส้นทางในดัชนีพาไปหน้าที่ไม่มีอยู่: ${entry.route}',
      );

      appRouter.go('/settings');
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('settings_theme')),
      );
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
