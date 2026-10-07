import 'package:chanting/features/settings/widgets/time_wheel_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Opens the picker at [initial] under a 12- or 24-hour clock and returns
  /// where its result will land.
  Future<List<TimeOfDay?>> open(
    WidgetTester tester, {
    required TimeOfDay initial,
    required bool use24,
  }) async {
    final picked = <TimeOfDay?>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked.add(
              await showTimeWheelPicker(
                context: context,
                initialTime: initial,
                title: 'title',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  FixedExtentScrollController wheel(WidgetTester tester, String key) => tester
      .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
      .scrollController!;

  testWidgets('a 12-hour clock adds an AM/PM wheel and keeps the hour right', (
    tester,
  ) async {
    final picked = await open(
      tester,
      initial: const TimeOfDay(hour: 17, minute: 5),
      use24: false,
    );

    // 17:05 opens as 5 : 05 PM.
    expect(wheel(tester, 'time_wheel_hour').selectedItem % 12, 5);
    expect(wheel(tester, 'time_wheel_minute').selectedItem % 60, 5);
    expect(wheel(tester, 'time_wheel_period').selectedItem, 1);

    // Item 0 of the hour wheel is "12": 12 AM is midnight, 12 PM is noon.
    wheel(tester, 'time_wheel_hour').jumpToItem(0);
    await tester.pumpAndSettle();
    wheel(tester, 'time_wheel_period').jumpToItem(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked.single, const TimeOfDay(hour: 0, minute: 5));
  });

  testWidgets('switching to PM moves the same hour to the afternoon', (
    tester,
  ) async {
    final picked = await open(
      tester,
      initial: const TimeOfDay(hour: 6, minute: 30),
      use24: false,
    );
    wheel(tester, 'time_wheel_period').jumpToItem(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked.single, const TimeOfDay(hour: 18, minute: 30));
  });

  testWidgets('a 24-hour clock has no AM/PM wheel, and cancel returns null', (
    tester,
  ) async {
    final picked = await open(
      tester,
      initial: const TimeOfDay(hour: 17, minute: 5),
      use24: true,
    );
    expect(find.byKey(const ValueKey('time_wheel_period')), findsNothing);
    expect(wheel(tester, 'time_wheel_hour').selectedItem % 24, 17);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picked.single, isNull);
  });
}
