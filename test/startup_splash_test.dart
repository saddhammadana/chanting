import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => appRouter.go('/'));

  Future<void> pump(WidgetTester tester, {required bool splash}) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': 999,
      'goal_prompt_seen': true,
    });
    final prefs = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
        child: ChantingApp(splash: splash),
      ),
    );
  }

  final splash = find.byKey(const ValueKey('startup_splash'));

  testWidgets('the lotus splash covers the start, then leaves the tree', (
    tester,
  ) async {
    await pump(tester, splash: true);
    await tester.pump();

    // The app's name and the loading line, over a page already building.
    expect(splash, findsOneWidget);
    expect(
      find.descendant(of: splash, matching: find.text('สวดมนต์')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: splash, matching: find.text('กำลังเตรียมบทสวด…')),
      findsOneWidget,
    );

    // Held, then faded, then gone — not left invisible over the app.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(splash, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(splash, findsNothing);
    expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
  });

  testWidgets('without the flag there is no splash', (tester) async {
    // What every other widget test relies on.
    await pump(tester, splash: false);
    await tester.pump();
    expect(splash, findsNothing);
  });
}
