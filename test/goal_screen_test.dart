import 'package:chanting/data/local/notification_service.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/settings/reminders_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_test.dart' show pumpGoalSettings, pumpUntilFound;

/// Records what would be scheduled instead of calling the real plugin.
class _FakeNotificationService extends NotificationService {
  final scheduled = <({int id, int weekday})>[];
  final cancelled = <int>[];

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    scheduled.add((id: id, weekday: weekday));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// The goal page: when you chant, on which days, and for how long.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/prayers-en.json');
    appRouter.go('/');
  });

  group('weekday storage', () {
    test('missing or unusable days read as every day', () {
      // Reminders fired every day before days could be chosen, so anything the
      // parser cannot use has to keep behaving that way rather than going
      // silent.
      expect(parseReminderDays(''), kEveryWeekday);
      expect(parseReminderDays('089x'), kEveryWeekday);
      expect(parseReminderDays('1234567'), kEveryWeekday);
    });

    test('a chosen set round-trips through prefs', () {
      expect(parseReminderDays('157'), {1, 5, 7});
      expect(formatReminderDays({7, 1, 5}), '157');
    });
  });

  group('scheduling', () {
    late _FakeNotificationService service;

    Future<ProviderContainer> container(Map<String, Object> prefsValues) async {
      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        ...prefsValues,
      });
      final prefs = await PrefsService.init();
      service = _FakeNotificationService();
      final c = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('an enabled slot schedules one notification per chosen day', () async {
      final c = await container({
        'reminder_enabled_morning': true,
        'reminder_days_morning': '135',
      });
      c
          .read(remindersControllerProvider.notifier)
          .setEnabled(ReminderSlot.morning, true);
      await pumpEventQueue();

      expect(service.scheduled.map((e) => e.weekday).toSet(), {1, 3, 5});
      expect(service.scheduled.map((e) => e.id).toSet(), {
        for (final day in [1, 3, 5])
          NotificationService.weekdayId(NotificationService.morningId, day),
      });
    });

    test('narrowing the days cancels the ones no longer chosen', () async {
      // The whole slot is cancelled before rescheduling, so a day that was
      // dropped cannot keep a notification nothing will ever name again.
      final c = await container({'reminder_enabled_evening': true});
      final controller = c.read(remindersControllerProvider.notifier);
      controller.setEnabled(ReminderSlot.evening, true);
      await pumpEventQueue();
      service.scheduled.clear();
      service.cancelled.clear();

      controller.setDays(ReminderSlot.evening, {6, 7});
      await pumpEventQueue();

      expect(service.scheduled.map((e) => e.weekday).toSet(), {6, 7});
      expect(
        service.cancelled,
        contains(
          NotificationService.weekdayId(NotificationService.eveningId, 1),
        ),
      );
      // The bare slot id too: releases before weekday support scheduled it,
      // and nothing else would ever clear it.
      expect(service.cancelled, contains(NotificationService.eveningId));
    });

    test('an empty day set is refused rather than stored', () async {
      final c = await container({'reminder_enabled_morning': true});
      final controller = c.read(remindersControllerProvider.notifier);
      controller.setDays(ReminderSlot.morning, {});
      expect(
        c.read(remindersControllerProvider)[ReminderSlot.morning]!.days,
        kEveryWeekday,
        reason: 'ล้างวันจนหมดแล้วการเตือนจะไม่มาเลย โดยไม่มีอะไรบอก',
      );
    });

    test('each slot has its own default time', () async {
      final c = await container({});
      final state = c.read(remindersControllerProvider);
      expect(state[ReminderSlot.morning]!.time.hour, 7);
      expect(state[ReminderSlot.midday]!.time.hour, 12);
      expect(state[ReminderSlot.evening]!.time.hour, 19);
      expect(state[ReminderSlot.bedtime]!.time.hour, 21);
    });
  });

  testWidgets('picking a time-of-day tile edits it without switching it on', (
    tester,
  ) async {
    // The gold face means "these controls belong to this slot"; the check
    // means "this one will notify me". Collapsing them would make browsing the
    // tiles switch reminders on by accident.
    final prefs = await pumpGoalSettings(tester);
    expect(prefs.getReminderEnabled('evening'), isFalse);

    await tester.tap(find.byKey(const ValueKey('slot_tile_evening')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefs.getReminderEnabled('evening'), isFalse);
    // While off, the row says how to turn it on rather than reporting a
    // reminder that will not arrive.
    expect(find.textContaining('เปิดสวิตช์นี้'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('slot_switch_evening')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getReminderEnabled('evening'), isTrue);
    // Now it reports the reminder itself: this slot, its time, its days.
    expect(find.textContaining('เปิดสวิตช์นี้'), findsNothing);
    expect(find.textContaining('เย็น'), findsWidgets);
  });

  testWidgets('days can be narrowed but never emptied', (tester) async {
    final prefs = await pumpGoalSettings(tester);
    expect(prefs.getReminderDays('morning'), '1234567');

    // Drop every day but Monday, then try to drop Monday too.
    for (
      var weekday = DateTime.tuesday;
      weekday <= DateTime.sunday;
      weekday++
    ) {
      await tester.tap(find.byKey(ValueKey('weekday_$weekday')));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getReminderDays('morning'), '1');

    await tester.tap(find.byKey(const ValueKey('weekday_1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      prefs.getReminderDays('morning'),
      '1',
      reason: 'ปล่อยให้ล้างวันจนหมดได้ = เตือนที่เปิดอยู่แต่ไม่เคยมา',
    );
  });

  testWidgets('Thai reads times on a 24-hour clock', (tester) async {
    // Flutter's own `th` localization has a 12-hour pattern and renders 06:00
    // as "AM 6:00" — the marker first, in Latin letters. The app overrides the
    // device's 12-hour setting for Thai; see `ChantingApp.builder`.
    await pumpGoalSettings(tester);
    expect(find.textContaining('7:00'), findsWidgets);
    expect(
      find.textContaining('AM'),
      findsNothing,
      reason: 'เวลาภาษาไทยไม่ควรมี AM/PM',
    );
  });

  testWidgets('the daily goal leads, and days belong to the slot panel', (
    tester,
  ) async {
    // The home ring opens this page, and the ring is the daily goal, so the
    // goal comes first. Days are per slot and the goal is not, so the days
    // stay inside the panel the tiles select, and the goal is said to apply
    // to every time of day.
    await pumpGoalSettings(tester);
    expect(find.text('กำลังตั้ง: เช้า'), findsOneWidget);

    final time = tester.getTopLeft(find.byKey(const ValueKey('goal_time')));
    final monday = tester.getTopLeft(find.byKey(const ValueKey('weekday_1')));
    final goal = tester.getTopLeft(
      find.byKey(const ValueKey('goal_minutes_5')),
    );
    final tiles = tester.getTopLeft(
      find.byKey(const ValueKey('slot_tile_morning')),
    );
    expect(goal.dy, lessThan(tiles.dy));
    expect(time.dy, greaterThan(tiles.dy));
    expect(monday.dy, greaterThan(time.dy));
    expect(find.text('ใช้กับทุกช่วงเวลารวมกัน'), findsOneWidget);

    // Switching tile switches whose days are on screen.
    await tester.tap(find.byKey(const ValueKey('slot_tile_bedtime')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('กำลังตั้ง: ก่อนนอน'), findsOneWidget);
  });

  testWidgets('the daily goal keeps its full range behind the custom chip', (
    tester,
  ) async {
    // The four presets are the artwork's; the range they replaced is 1–120 and
    // somebody has already chosen a value inside it.
    final prefs = await pumpGoalSettings(tester);

    await tester.tap(find.byKey(const ValueKey('goal_minutes_15')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getPracticeGoalMinutes(), 15);

    await tester.tap(find.byKey(const ValueKey('goal_minutes_custom')));
    await tester.pumpAndSettle();
    // The wheel is 1-based: item 44 is 45 minutes.
    (tester
            .widget<CupertinoPicker>(
              find.byKey(const ValueKey('minutes_wheel')),
            )
            .scrollController!)
        .jumpToItem(44);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(prefs.getPracticeGoalMinutes(), 45);
    // A custom value takes the custom chip's place rather than hiding.
    expect(find.text('45 นาที'), findsWidgets);
  });

  testWidgets('more than one time of day can be switched on at once', (
    tester,
  ) async {
    await pumpGoalSettings(tester);

    await tester.tap(find.byKey(const ValueKey('slot_switch_morning')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The switch's own line says the reminder back.
    expect(find.textContaining('ทุกวัน'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('slot_tile_bedtime')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('slot_switch_bedtime')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Both, because this app is chanted morning and evening and the tiles are
    // a picker rather than a single choice.
    final reminders = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('slot_tile_bedtime'))),
    ).read(remindersControllerProvider);
    expect(reminders[ReminderSlot.morning]!.enabled, isTrue);
    expect(reminders[ReminderSlot.bedtime]!.enabled, isTrue);
  });

  testWidgets('the goal page is what the hub reminder row opens', (
    tester,
  ) async {
    await pumpGoalSettings(tester);
    await pumpUntilFound(tester, find.text('ตั้งเป้าหมาย'));
    expect(find.text('สร้างช่วงเวลาแห่งความสงบ'), findsOneWidget);
  });
}
