import 'package:chanting/data/local/notification_service.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/settings/reminders_controller.dart';
import 'package:chanting/features/settings/settings_controller.dart';
import 'package:chanting/l10n/app_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records scheduled notifications instead of calling the real plugin.
class _FakeNotificationService extends NotificationService {
  final scheduled =
      <({int id, int weekday, String title, String body, String channel})>[];
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
    scheduled.add((
      id: id,
      weekday: weekday,
      title: title,
      body: body,
      channel: channelName,
    ));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// Which slot a scheduled id belongs to; ids are `base * 10 + weekday`.
int _slotOf(int id) => id ~/ 10;

/// Notifications are the hardest i18n case in this app (docs/internationalization.md Phase 1 trap 2):
/// there is no BuildContext, **and** the OS stores text at schedule time.
/// Changing language without rescheduling leaves users on the old language forever,
/// with no error.
void main() {
  late _FakeNotificationService service;
  late PrefsService prefs;

  Future<ProviderContainer> containerWith(String locale) async {
    SharedPreferences.setMockInitialValues({
      'locale': locale,
      'reminder_enabled_morning': true,
      'reminder_time_morning': '07:00',
    });
    prefs = await PrefsService.init();
    service = _FakeNotificationService();
    final container = ProviderContainer(
      overrides: [
        prefsServiceProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test(
    'startup reminder scheduling uses the saved user language instead of always Thai',
    () async {
      // rescheduleRemindersOnStartup has no context, so it must read locale from prefs.
      SharedPreferences.setMockInitialValues({
        'locale': 'en',
        'reminder_enabled_evening': true,
        'reminder_time_evening': '19:30',
      });
      final p = await PrefsService.init();
      final s = _FakeNotificationService();
      await rescheduleRemindersOnStartup(p, s);

      // One per weekday: a reminder defaults to every day, and each day is
      // scheduled on its own so the set can be narrowed later.
      expect(s.scheduled, hasLength(7));
      expect(s.scheduled.map((e) => e.weekday).toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(s.scheduled.map((e) => _slotOf(e.id)).toSet(), {
        NotificationService.eveningId,
      });
      expect(s.scheduled.first.title, 'Time for evening chanting');
      expect(s.scheduled.first.channel, 'Prayer time reminders');
    },
  );

  test(
    'enabled reminder notification text matches the selected language',
    () async {
      final container = await containerWith('th');
      container.read(remindersControllerProvider);
      container
          .read(remindersControllerProvider.notifier)
          .setEnabled(ReminderSlot.morning, true);
      await pumpEventQueue();

      expect(service.scheduled.last.title, 'ได้เวลาทำวัตรเช้า');
      expect(service.scheduled.last.body, contains('จิตใจสงบ'));
    },
  );

  test(
    'changing language reschedules pending reminders in the new language',
    () async {
      // The core of trap 2: this fails unless locale changes are listened to.
      final container = await containerWith('th');
      container.read(remindersControllerProvider);
      await pumpEventQueue();
      service.scheduled.clear();

      container
          .read(settingsControllerProvider.notifier)
          .setLocale(AppLocale.en);
      await pumpEventQueue();

      expect(
        service.scheduled,
        isNotEmpty,
        reason: 'เปลี่ยนภาษาแล้วไม่ได้ตั้งแจ้งเตือนใหม่ — ผู้ใช้จะค้างภาษาเก่า',
      );
      expect(_slotOf(service.scheduled.last.id), NotificationService.morningId);
      expect(service.scheduled.last.title, 'Time for morning chanting');
      expect(service.scheduled.last.body, isNot(contains('จิตใจสงบ')));
    },
  );

  test(
    'disabled reminders are not rescheduled when language changes',
    () async {
      SharedPreferences.setMockInitialValues({'locale': 'th'});
      final p = await PrefsService.init();
      final s = _FakeNotificationService();
      final container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(p),
          notificationServiceProvider.overrideWithValue(s),
        ],
      );
      addTearDown(container.dispose);

      container.read(remindersControllerProvider);
      container
          .read(settingsControllerProvider.notifier)
          .setLocale(AppLocale.en);
      await pumpEventQueue();

      expect(s.scheduled, isEmpty);
    },
  );
}
