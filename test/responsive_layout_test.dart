import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:chanting/shared/widgets/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('home_practice_hero')),
  );
}

Future<void> _pumpUntilFound(
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
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/sections-th.json');
    appRouter.go('/');
  });

  testWidgets('prayer search fits narrow mobile width', (tester) async {
    await _pumpAppAt(tester, const Size(320, 700));

    expect(find.byType(SearchBar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav_prayers')));
    await _pumpUntilFound(tester, find.byType(SearchBar));

    final searchSize = tester.getSize(find.byType(SearchBar));
    expect(searchSize.width, lessThanOrEqualTo(288));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home header stays inside the content column when wide', (
    tester,
  ) async {
    await _pumpAppAt(tester, const Size(1400, 700));

    // The body is capped at ContentWidth.gridWidth and centred; the header used
    // to live in the AppBar's own title/actions slots, so it stretched to the
    // window edges and under the corner ornament. Measured on the header row
    // itself rather than on any one control in it, which comes and goes.
    final header = tester.getRect(find.byKey(const ValueKey('home_header')));
    final hero = tester.getRect(
      find.byKey(const ValueKey('home_practice_hero')),
    );

    expect(header.width, lessThanOrEqualTo(ContentWidth.gridWidth));
    expect(header.left, greaterThanOrEqualTo(hero.left - 8));
    expect(header.right, lessThanOrEqualTo(hero.right + 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header keeps its top room without a status bar', (
    tester,
  ) async {
    // A phone's status bar supplies the space the artwork leaves above the
    // emblem; desktop and web have none, and the header used to sit against the
    // window edge under the corner ornament.
    await _pumpAppAt(tester, const Size(430, 900));

    final bar = tester.getRect(find.byType(AppBar).first);
    expect(bar.height, 114);
    expect(
      tester.getRect(find.byKey(const ValueKey('home_practice_hero'))).top,
      126,
    );
    expect(tester.takeException(), isNull);
  });
}
