import 'dart:convert';
import 'dart:io';

import 'package:chanting/features/prayer_list/day_part.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widget_test.dart' show pumpApp;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => appRouter.go('/'));

  testWidgets(
    'bottom navigation exposes five destinations and starts the service of the hour',
    (tester) async {
      await pumpApp(tester, openAll: false);

      expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_prayers')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_start')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_library')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
      expect(find.text('ตั้งค่า'), findsOneWidget);
      expect(find.byType(SearchBar), findsNothing);
      // The only Library label on Home is its bottom-navigation destination.
      expect(find.text('คลังของฉัน'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_prayers')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_start')));
      await tester.pumpAndSettle();

      expect(appRouter.routeInformationProvider.value.uri.path, '/start');
      // The Start tab opens the service for this part of the day, so which
      // title is on screen depends on when the test runs.
      final serviceId = DayPart.of(DateTime.now()).serviceSectionId;
      final sections =
          jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
              as List;
      final title =
          sections.firstWhere((s) => s['id'] == serviceId)['title'] as String;
      expect(find.text(title), findsWidgets);
    },
  );

  testWidgets('bottom navigation switches between primary destinations', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);

    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/playlists');

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/settings');

    await tester.tap(find.byKey(const ValueKey('nav_home')));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('the start button leaves with the bar when the keyboard opens', (
    tester,
  ) async {
    // A Scaffold lifts its FAB above the keyboard while the bar stays under
    // it, so the button used to float alone over the list being searched.
    await pumpApp(tester, openAll: false);
    expect(find.byKey(const ValueKey('nav_start')), findsOneWidget);

    // One frame each way: it goes and returns with no transition.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byKey(const ValueKey('nav_start')), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(find.byKey(const ValueKey('nav_start')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
