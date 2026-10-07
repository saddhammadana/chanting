import 'package:chanting/data/local/system_bars.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'meditation_timer_test.dart' show pumpApp, pumpUntilFound;

const _channel = MethodChannel('th.chanting.app/system_bars');

/// Records what the Android window is asked for, as `MainActivity` would
/// receive it. `true` is hidden.
List<bool> recordSystemBars(WidgetTester tester) {
  final asked = <bool>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    asked.add((call.arguments as Map)['hidden'] as bool);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
  return asked;
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

  testWidgets('Android asks its own window, not SystemChrome', (tester) async {
    final asked = recordSystemBars(tester);
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
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

    // Real async: an unmocked channel is answered by the engine, outside the
    // fake clock a widget test runs on.
    await tester.runAsync(() async {
      await setSystemBarsHidden(true);
      await setSystemBarsHidden(false);
    });

    expect(asked, [true, false]);
    expect(modes, isEmpty);
  });

  testWidgets('without the Android handler it falls back to SystemChrome', (
    tester,
  ) async {
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
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

    // Real async: an unmocked channel is answered by the engine, outside the
    // fake clock a widget test runs on.
    await tester.runAsync(() async {
      await setSystemBarsHidden(true);
      await setSystemBarsHidden(false);
    });

    expect(modes, ['SystemUiMode.immersiveSticky', 'SystemUiMode.edgeToEdge']);
  });

  testWidgets('a sitting that hid the bars gives them back on the way out', (
    tester,
  ) async {
    final asked = recordSystemBars(tester);
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );

    await tester.tap(find.byKey(const ValueKey('meditation_start')));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(asked, [true]);

    // Back once ends the sitting, back again leaves the screen.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_practice_hero')), findsOneWidget);
    expect(asked.last, isFalse);

    // The tap hint's own timer outlives the screen by a moment.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('leaving the meditation screen always shows the bars', (
    tester,
  ) async {
    final asked = recordSystemBars(tester);
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_meditation')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('meditation_start')),
    );
    expect(asked, isEmpty);

    // Nothing was hidden, and the bars are still asked for: a screen that
    // can hide them must not depend on its own bookkeeping to return them.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(asked, [false]);
  });
}
