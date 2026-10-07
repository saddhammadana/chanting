import 'package:chanting/router/app_router.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show pumpApp, pumpUntilFound, tapPrayerCard;

/// The "report prayer issue" menu on the reading page works on every platform.
/// In tests, url_launcher has no handler, so launchUrl throws and falls back to
/// copying to the clipboard. Clipboard copy is always the safety net, so tests
/// can inspect the mocked clipboard. Version may not load in tests; it is optional.
void main() {
  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone, and appRouter
    // is global. Without clearing both, the second test can stay on the first test's
    // reading page and pumpApp will not find the home page.
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  testWidgets(
    'report prayer issue requires details then copies the full report',
    (tester) async {
      await pumpApp(tester);

      await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(seconds: 1));

      // Open the overflow menu, then report a prayer issue.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('แจ้งบทสวดผิด').last);
      await pumpUntilFound(tester, find.text('ส่งรายงาน'));
      await tester.pump(const Duration(seconds: 1));

      // Submitting an empty form shows an error and does not send.
      await tester.tap(find.text('ส่งรายงาน'));
      await tester.pump();
      expect(find.text('กรุณากรอกรายละเอียดก่อนส่ง'), findsOneWidget);

      // Mock url_launcher to return false; otherwise launchUrl hangs without a
      // handler and _submit never reaches fallback or closes the sheet.
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcherChannel,
          null,
        ),
      );

      // Capture clipboard; this channel has no test handler and hangs unless mocked.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.enterText(find.byType(TextField), 'สะกดผิดตรงคำว่า อะระหัง');
      await tester.tap(find.text('ส่งรายงาน'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Copied report must include prayer info and the typed details.
      expect(copied, isNotNull);
      expect(copied, contains('id: ratanattaya-vandana'));
      expect(copied, contains('field: text'));
      expect(copied, contains('สะกดผิดตรงคำว่า อะระหัง'));

      // The sheet closes after submit.
      expect(find.text('ส่งรายงาน'), findsNothing);
    },
  );

  testWidgets('long-press text selection reports from the toolbar with selected text', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Long-press prayer content. This gesture is not claimed by reading-page tap
    // or swipe handlers, so SelectionArea should own it and show selection UI
    // with our report button.
    //
    // **Drive the long press manually per pump; do not use `tester.longPress`**.
    // It presses, pumps 600ms at once, and releases. Inside a scrollable ListView,
    // jumping the clock once does not let SelectableRegion's long-press recognizer
    // win the arena, so nothing is selected and the test falsely looks broken.
    // Pumping ten 100ms steps in the same structure selects normally.
    final target =
        tester.getTopLeft(find.textContaining('อะระหัง สัมมาสัมพุทโธ').first) +
        const Offset(30, 8);
    final press = await tester.startGesture(target);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await press.up();
    await tester.pumpAndSettle();

    final reportButton = find.text('แจ้งบทสวดผิด');
    expect(
      reportButton,
      findsOneWidget,
      reason: 'แถบที่ขึ้นตอนเลือกข้อความต้องมีปุ่มแจ้งบทสวดผิดต่อท้ายของระบบ',
    );

    await tester.tap(reportButton);
    await pumpUntilFound(tester, find.text('ส่งรายงาน'));
    await tester.pump(const Duration(seconds: 1));

    // The sheet shows selected text before sending and guesses the issue part as content.
    expect(find.byKey(const ValueKey('report_selected_text')), findsOneWidget);
    expect(find.text('ข้อความที่เลือก'), findsOneWidget);

    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.enterText(find.byType(TextField), 'ตรงนี้สะกดผิด');
    await tester.tap(find.text('ส่งรายงาน'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Selected text must be included in the report; that is the feature's purpose.
    expect(copied, isNotNull);
    expect(copied, contains('selected:'));
    expect(copied, contains('ตรงนี้สะกดผิด'));
  });

  testWidgets('mobile home bar exposes report button without opening more options', (
    tester,
  ) async {
    await pumpApp(tester);
    // Wider test screens fit every button and never overflow. This bug appears
    // only at real mobile width: at 360px the bar fits **two buttons**, with the
    // rest behind a small more-options button. A mis-tap hits content, clears
    // selection, and hides the whole toolbar.
    tester.view.physicalSize = const Size(360, 5600);
    tester.view.devicePixelRatio = 1.0;

    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Drive the long press manually for the same reason as above; `longPress` fails.
    final target =
        tester.getTopLeft(find.textContaining('อะระหัง สัมมาสัมพุทโธ').first) +
        const Offset(30, 8);
    final press = await tester.startGesture(target);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await press.up();
    await tester.pumpAndSettle();

    // Buttons on page two are **not in the tree** because the toolbar builds only
    // the visible page. Finding the button here means it is truly on page one.
    expect(
      find.text('แจ้งบทสวดผิด'),
      findsOneWidget,
      reason: 'ปุ่มแจ้งต้องมาก่อนปุ่มของระบบ ไม่งั้นตกไปหน้าสองบนจอมือถือ',
    );

    await tester.tap(find.text('แจ้งบทสวดผิด'));
    await pumpUntilFound(tester, find.text('ส่งรายงาน'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('report_selected_text')), findsOneWidget);
  });

  testWidgets('mouse drag selects text instead of swiping to another prayer', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapPrayerCard(tester, 'บทกราบพระรัตนตรัย');
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(seconds: 1));

    // Prayer-swipe gestures are limited to touch/stylus. On desktop and web,
    // horizontal mouse drag over text means text selection. If the swipe recognizer
    // accepted mouse too, it would win the arena and jump to the next prayer.
    final start =
        tester.getTopLeft(find.textContaining('อะระหัง สัมมาสัมพุทโธ').first) +
        const Offset(10, 8);
    final drag = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    // Still on the same prayer. Check **content**, not title, because the bottom
    // bar already displays the next prayer title as a button label.
    expect(find.textContaining('อะระหัง สัมมาสัมพุทโธ'), findsWidgets);
    expect(find.textContaining('นะโม ตัสสะ'), findsNothing);

    // The drag must reach SelectionArea; copy appears only when there is a selection.
    final region = tester
        .state<SelectionAreaState>(find.byType(SelectionArea))
        .selectableRegion;
    expect(
      region.contextMenuButtonItems.map((b) => b.type),
      contains(ContextMenuButtonType.copy),
      reason: 'ลากคลุมด้วยเมาส์แล้วต้องได้ข้อความที่เลือกจริง',
    );
  });
}
