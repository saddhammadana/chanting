import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Daily prayer reminders using local notifications only; no backend.
///
/// Intended for Android/iOS. On web, desktop, and tests, methods quietly no-op.
/// Calls are guarded because the plugin may be absent on unsupported platforms.
class NotificationService {
  static const morningId = 1;
  static const eveningId = 2;
  static const middayId = 3;
  static const bedtimeId = 4;

  /// Notification id for one weekday of one slot.
  ///
  /// A reminder is scheduled once per selected weekday, so a slot owns a small
  /// block of ids rather than one. `weekday` is `DateTime.monday`..`sunday`,
  /// which keeps every block clear of the bare slot ids 1–4 that the
  /// every-day-only version used.
  static int weekdayId(int baseId, int weekday) => baseId * 10 + weekday;

  /// Whether reminder settings should be shown.
  static bool get supported => !kIsWeb;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      tz_data.initializeTimeZones();
      // flutter_timezone 5 returns a TimezoneInfo rather than the name.
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      // Android 13+ requires runtime notification permission.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      // Android 12+ requires exact-alarm permission, otherwise exact
      // zonedSchedule calls can throw.
      await android?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Schedule a reminder for one weekday at the given time.
  ///
  /// Weekly rather than daily because reminders can be limited to chosen days;
  /// `dayOfWeekAndTime` repeats every week on that day. A slot on all seven
  /// days is seven of these, which is well inside any platform limit.
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    // Android notification channel name/description. They are passed in already
    // localized because this service has no BuildContext.
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfWeekday(weekday, hour, minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            channelName,
            channelDescription: channelDescription,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Exact scheduling keeps prayer reminders on time after permission is
        // granted; allowWhileIdle also works during Doze.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  /// Cancels every notification a slot can own.
  ///
  /// Includes the bare [baseId], which is what releases before weekday support
  /// scheduled: without it an old daily reminder keeps firing forever, since
  /// nothing else ever names that id again.
  Future<void> cancelSlot(int baseId) async {
    await cancel(baseId);
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await cancel(weekdayId(baseId, weekday));
    }
  }

  Future<void> cancel(int id) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// Whether this device can schedule exact reminders.
  ///
  /// - Android 12+: returns false if the user has not granted "Alarms &
  ///   reminders"; the OS may otherwise downgrade to inexact timing.
  /// - Android < 12, iOS, and other platforms: returns true because no user-facing
  ///   exact-alarm permission flow is needed.
  Future<bool> canScheduleExact() async {
    if (!await _init()) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Non-Android platforms have no exact-alarm restriction here.
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ask the OS to open or show the exact-alarm permission flow when relevant.
  Future<void> openExactAlarmSettings() async {
    if (!await _init()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// The next occurrence of [weekday] at the given time.
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOf(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
