import 'package:chanting/shared/widgets/app_toast.dart';
import 'package:chanting/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ScaffoldMessengerState> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const Scaffold()),
    );
    return ScaffoldMessenger.of(tester.element(find.byType(Scaffold)));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the close button dismisses the toast', (tester) async {
    final messenger = await pump(tester);
    messenger.showSnackBar(
      appToast('saved', duration: const Duration(minutes: 1)),
    );
    await settle(tester);
    expect(find.text('saved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);
    expect(find.text('saved'), findsNothing);
  });

  testWidgets('an action runs once and takes the toast with it', (
    tester,
  ) async {
    final messenger = await pump(tester);
    var undone = 0;
    messenger.showSnackBar(
      appToast(
        'deleted',
        kind: ToastKind.info,
        duration: const Duration(minutes: 1),
        actionLabel: 'undo',
        onAction: () => undone++,
      ),
    );
    await settle(tester);

    await tester.tap(find.text('undo'));
    await settle(tester);
    expect(undone, 1);
    expect(find.text('deleted'), findsNothing);
  });

  testWidgets('a toast floats, so the shell start button is never lifted', (
    tester,
  ) async {
    // The shell relies on this; see app_bottom_navigation.dart.
    expect(appToast('x').behavior, SnackBarBehavior.floating);
  });
}
