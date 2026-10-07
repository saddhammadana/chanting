import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The longest prayer in the book. This case needs content that **really scrolls**
/// on an 800x500 screen, not any specific prayer.
///
/// This used to hard-code `phae-metta`, then failed as soon as that prayer was
/// reorganized and `text` shrank to 6 lines (`maxScrollExtent` became 0).
/// Per CLAUDE.md, fixtures that need a *property* should find it in the real file
/// instead of pinning a prayer name, or content edits can fail tests without code bugs.
///
/// **Read through `decodePrayers`, not the raw JSON `text` key**. Prayers moved
/// to the `sections` format no longer have that key in the file (`Prayer.text`
/// is computed from `lines`), so reading the key directly breaks when the longest
/// prayer is converted. The helper rule still works; it just has to ask the model.
String _longestPrayerId() {
  final prayers = PrayerRepository.decodePrayers(
    File('assets/data/prayers-th.json').readAsStringSync(),
  );
  var best = prayers.first;
  for (final p in prayers) {
    if (p.text.length > best.text.length) best = p;
  }
  return best.id;
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

  testWidgets('resume reading card returns to the saved scroll position', (
    WidgetTester tester,
  ) async {
    // Short enough viewport that the long prayer scrolls, giving restore a real offset.
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'last_read_id': _longestPrayerId(),
      'last_read_offset': 250.0,
      'last_read_continuous': false,
      'last_read_playlist': '',
      'welcome_seen_version': 999,
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
    for (var i = 0; i < 8 && !tester.any(find.text('อ่านต่อ')); i++) {
      await tester.drag(
        find.byKey(const ValueKey('home_scroll')),
        const Offset(0, -180),
      );
      await tester.pump();
    }
    expect(find.text('อ่านต่อ'), findsWidgets);
    await tester.ensureVisible(find.text('อ่านต่อ'));
    await tester.pumpAndSettle();

    // Opening from the "resume reading" card should restore the saved position.
    await tester.tap(find.text('อ่านต่อ'));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    // Restore retries frame by frame until layout is ready, so pump several frames.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    // Scroll to 250, or the end if content is shorter; either way, not the top.
    expect(position.pixels, greaterThan(0));
    expect(
      position.pixels,
      anyOf(equals(250.0), equals(position.maxScrollExtent)),
    );
  });
}
