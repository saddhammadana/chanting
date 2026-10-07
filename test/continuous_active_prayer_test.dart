import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show prayerTitle, tapPrayerCard;

/// In continuous mode the AppBar commands must act on the prayer **on screen**,
/// not on the one the reader entered with.
///
/// The whole category is one long page there, so `widget.prayerId` stops being
/// the prayer being read the moment anyone scrolls. Copy, favourite, pin and
/// "report a mistake" all used it anyway. The report is the costly one: it
/// leaves the app and reaches a person, carrying one prayer's id and title
/// beside a passage quoted from another.
///
/// Fixtures come from the data file, never hard-coded: this is about *which*
/// prayer the commands follow, not about which prayers a category happens to
/// contain today.
({String id, List<String> prayerIds}) _sectionWithSeveralPrayers() {
  final sections =
      jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
          as List<dynamic>;
  for (final s in sections.cast<Map<String, dynamic>>()) {
    final ids = (s['prayerIds'] as List).cast<String>();
    if (ids.length >= 3) return (id: s['id'] as String, prayerIds: ids);
  }
  fail('ไม่มีหมวดไหนมีบทตั้งแต่ 3 บทขึ้นไปให้เลื่อนทดสอบ');
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 60,
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
    appRouter.go('/');
  });

  testWidgets('continuous mode commands follow the prayer scrolled to', (
    tester,
  ) async {
    // Short viewport so the content actually overflows and scrolling moves
    // between prayers; the tall default would fit several at once.
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final section = _sectionWithSeveralPrayers();
    final firstId = section.prayerIds.first;

    SharedPreferences.setMockInitialValues({
      'continuous_reading': true,
      'welcome_seen_version': 999,
    });
    final prefsService = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
        child: const ChantingApp(),
      ),
    );
    appRouter.go('/category/${section.id}');
    await pumpUntilFound(tester, find.text(prayerTitle(firstId)));
    await tester.pump(const Duration(seconds: 1));
    await tapPrayerCard(tester, prayerTitle(firstId));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

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

    final scroller = find.byKey(const ValueKey('continuous_scroll'));
    expect(scroller, findsOneWidget);

    // Scrolling here needs two things that are easy to get wrong.
    //
    // Steps, not one big drag: the first move is eaten by touch slop.
    //
    // And **real time between scrolls**. `_updateCurrentIndex` throttles itself
    // on `DateTime.now()`, which fake time does not advance, so every scroll
    // notification after the first one is dropped and the index stays at 0 no
    // matter how far the test scrolls. `runAsync` is what lets the wall clock
    // move past that 250 ms window.
    Future<void> scrollBy(double dy) async {
      final gesture = await tester.startGesture(tester.getCenter(scroller));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, dy / 10));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }

    for (var i = 0; i < 6; i++) {
      await scrollBy(-900);
    }

    // The bar reports which prayer is being read; anything past the first is
    // enough to catch the bug.
    final counter = find.textContaining(RegExp(r'บทที่ \d+'));
    expect(counter, findsWidgets, reason: 'ไม่พบตัวเลขบอกบทที่กำลังอ่าน');
    final label = tester.widget<Text>(counter.first).data!;
    final position = int.parse(
      RegExp(r'บทที่ (\d+)').firstMatch(label)!.group(1)!,
    );
    expect(
      position,
      greaterThan(1),
      reason: 'เลื่อนแล้วแต่ยังอยู่บทแรก — เพิ่มระยะเลื่อนในเทสต์',
    );
    final onScreenId = section.prayerIds[position - 1];

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('คัดลอกบทสวด'));
    await tester.pumpAndSettle();

    expect(copied, isNotNull, reason: 'ไม่ได้คัดลอกอะไรเลย');
    expect(
      copied,
      contains(prayerTitle(onScreenId)),
      reason:
          'คัดลอกได้บทที่ไม่ได้อยู่บนจอ — คำสั่งยังผูกกับบทที่เปิดเข้ามา '
          '(อ่านอยู่บทที่ $position แต่ได้เนื้อหาบทอื่น)',
    );
    if (onScreenId != firstId) {
      expect(
        copied,
        isNot(contains('"id": "$firstId"')),
        reason: 'ยังมี id ของบทแรกติดมา',
      );
    }
  });
}
