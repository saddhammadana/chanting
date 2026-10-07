import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widget_test.dart' show pumpApp;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => appRouter.go('/'));

  // The shell's own Scaffold used to lay out every SnackBar flush on the nav
  // bar, covering the start button. (It covered the playlists FAB too, until
  // "create" moved into the list and no shell page kept a FAB.)
  testWidgets('SnackBar on a shell page clears the start button', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    tester.view.physicalSize = const Size(460, 900);
    appRouter.go('/playlists');
    await tester.pumpAndSettle();

    // Any widget inside the page resolves the page's own messenger.
    final page = find.byKey(const ValueKey('playlist_create_button'));
    ScaffoldMessenger.of(
      tester.element(page),
    ).showSnackBar(const SnackBar(content: Text('snack')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The surface, not the SnackBar widget: the widget's rect includes the
    // transparent inset that is there precisely to clear the start button.
    final snack = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    final start = tester.getRect(find.byKey(const ValueKey('nav_start')));
    expect(snack.overlaps(start), isFalse, reason: 'snack $snack start $start');

    ScaffoldMessenger.of(tester.element(page)).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  });

  // The set editor and a set's page sit outside the shell, so their SnackBars
  // belong to the root messenger and are still up when they pop back to it.
  testWidgets(
    'a SnackBar left by a pushed page does not lift the start button',
    (tester) async {
      await pumpApp(tester, openAll: false);
      tester.view.physicalSize = const Size(460, 900);
      appRouter.go('/playlists');
      await tester.pumpAndSettle();

      final startFinder = find.byKey(const ValueKey('nav_start'));
      final before = tester.getRect(startFinder);
      // The start button is outside every page, so it resolves the root one.
      final root = ScaffoldMessenger.of(tester.element(startFinder));
      root.showSnackBar(const SnackBar(content: Text('snack')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.getRect(startFinder), before);
      final snack = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        snack.overlaps(before),
        isFalse,
        reason: 'snack $snack start $before',
      );

      root.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    },
  );
}
