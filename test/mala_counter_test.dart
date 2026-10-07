import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/mala/mala_controller.dart';
import 'package:chanting/features/mala/mala_counter_overlay.dart';
import 'package:chanting/l10n/app_locale.dart';
import 'package:chanting/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final service = await PrefsService.init();
  return ProviderContainer(
    overrides: [prefsServiceProvider.overrideWithValue(service)],
  );
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  PrefsService service, {
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        locale: AppLocale.th.locale,
        supportedLocales: AppLocale.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(child: MalaCounterOverlay(onClose: onClose ?? () {})),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MalaController', () {
    test('increment adds one count and persists it', () async {
      final c = await _container({});
      addTearDown(c.dispose);
      final notifier = c.read(malaControllerProvider.notifier);
      expect(c.read(malaControllerProvider).count, 0);
      notifier.increment();
      notifier.increment();
      expect(c.read(malaControllerProvider).count, 2);
      // Persist to real prefs.
      expect(c.read(prefsServiceProvider).getMalaCount(), 2);
    });

    test('increment returns true exactly when the target is reached', () async {
      final c = await _container({'mala_count': 107, 'mala_target': 108});
      addTearDown(c.dispose);
      final notifier = c.read(malaControllerProvider.notifier);
      expect(notifier.increment(), isTrue); // 108 exactly reaches the goal.
      expect(
        notifier.increment(),
        isFalse,
      ); // 109 exceeds the goal; do not alert again.
      expect(c.read(malaControllerProvider).isComplete, isTrue);
    });

    test('reset clears the count to zero', () async {
      final c = await _container({'mala_count': 50, 'mala_target': 108});
      addTearDown(c.dispose);
      c.read(malaControllerProvider.notifier).reset();
      expect(c.read(malaControllerProvider).count, 0);
      expect(c.read(prefsServiceProvider).getMalaCount(), 0);
    });

    test(
      'setting a target below the current count restarts counting',
      () async {
        final c = await _container({'mala_count': 100, 'mala_target': 108});
        addTearDown(c.dispose);
        c.read(malaControllerProvider.notifier).setTarget(9);
        final s = c.read(malaControllerProvider);
        expect(s.target, 9);
        expect(s.count, 0);
      },
    );

    test('target values above the maximum are clamped', () async {
      final c = await _container({});
      addTearDown(c.dispose);
      c.read(malaControllerProvider.notifier).setTarget(999999);
      expect(c.read(malaControllerProvider).target, kMalaMaxTarget);
    });
  });

  group('MalaCounterOverlay', () {
    testWidgets('tapping the counter card increments the count', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'mala_target': 108});
      final service = await PrefsService.init();
      await _pumpOverlay(tester, service);

      expect(find.text('0 / 108'), findsOneWidget);
      await tester.tap(find.byType(MalaCounterOverlay));
      await tester.pump();
      expect(find.text('1 / 108'), findsOneWidget);
    });

    testWidgets('close button invokes onClose', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = await PrefsService.init();
      var closed = false;
      await _pumpOverlay(tester, service, onClose: () => closed = true);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, isTrue);
    });
  });
}
