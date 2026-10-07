import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/notification_service.dart';
import '../../data/local/prefs_service.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/app_localizations.dart';
import 'settings_controller.dart';

/// Daily prayer reminder slot.
///
/// Do not put user-visible titles in the const constructor. Same reason as
/// `AppTextColor`: labels live in the extension below.
/// Declaration order is the order the goal page draws them, which is the order
/// of the day. The ids are not renumbered to match: `morning` and `evening`
/// shipped as 1 and 2 and their prefs keys are on people's devices.
enum ReminderSlot {
  morning('morning', NotificationService.morningId),
  midday('midday', NotificationService.middayId),
  evening('evening', NotificationService.eveningId),
  bedtime('bedtime', NotificationService.bedtimeId);

  const ReminderSlot(this.key, this.notificationId);

  final String key;
  final int notificationId;

  /// Default reminder time, used until the person picks one.
  String get defaultTime => switch (this) {
    ReminderSlot.morning => '07:00',
    ReminderSlot.midday => '12:00',
    ReminderSlot.evening => '19:00',
    ReminderSlot.bedtime => '21:00',
  };
}

/// Localized text for a reminder slot.
extension ReminderSlotL10n on ReminderSlot {
  /// Title shown on the actual notification, not the settings label.
  String notificationTitle(AppLocalizations l10n) => switch (this) {
    ReminderSlot.morning => l10n.reminderNotificationMorning,
    ReminderSlot.midday => l10n.reminderNotificationMidday,
    ReminderSlot.evening => l10n.reminderNotificationEvening,
    ReminderSlot.bedtime => l10n.reminderNotificationBedtime,
  };

  /// Full name, as the reminder row and the summary say it.
  String label(AppLocalizations l10n) => switch (this) {
    ReminderSlot.morning => l10n.reminderMorning,
    ReminderSlot.midday => l10n.reminderMidday,
    ReminderSlot.evening => l10n.reminderEvening,
    ReminderSlot.bedtime => l10n.reminderBedtime,
  };

  /// Short name for the time-of-day tiles.
  String shortLabel(AppLocalizations l10n) => switch (this) {
    ReminderSlot.morning => l10n.reminderSlotMorning,
    ReminderSlot.midday => l10n.reminderSlotMidday,
    ReminderSlot.evening => l10n.reminderSlotEvening,
    ReminderSlot.bedtime => l10n.reminderSlotBedtime,
  };

  /// Help text on the time picker.
  String pickerLabel(AppLocalizations l10n) => switch (this) {
    ReminderSlot.morning => l10n.reminderPickerMorning,
    ReminderSlot.midday => l10n.reminderPickerMidday,
    ReminderSlot.evening => l10n.reminderPickerEvening,
    ReminderSlot.bedtime => l10n.reminderPickerBedtime,
  };
}

/// Loads `AppLocalizations` without a `BuildContext`.
///
/// Reminders are scheduled from startup and controller code without context.
/// `AppLocalizations.delegate.load` does not require context, so load directly.
///
/// Take [AppLocale] as input instead of reading prefs. `setLocale` updates state
/// before writing prefs, so listeners can fire while prefs still hold the old
/// value.
Future<AppLocalizations> _l10nFor(AppLocale locale) =>
    AppLocalizations.delegate.load(locale.resolve());

typedef ReminderSetting = ({bool enabled, TimeOfDay time, Set<int> days});

/// Every weekday, which is what a reminder means until days are narrowed.
const kEveryWeekday = {1, 2, 3, 4, 5, 6, 7};

/// Parses the stored digit string; anything unusable reads as every day.
Set<int> parseReminderDays(String raw) {
  final days = {
    for (final ch in raw.split(''))
      if (int.tryParse(ch) case final day? when day >= 1 && day <= 7) day,
  };
  return days.isEmpty ? kEveryWeekday : days;
}

String formatReminderDays(Set<int> days) => (days.toList()..sort()).join();

TimeOfDay _parseTime(String raw) {
  final parts = raw.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Schedules or cancels reminders from prefs during app startup.
///
/// This repairs missed schedules after app updates or timezone changes. Unsupported
/// platforms no-op.
Future<void> rescheduleRemindersOnStartup(
  PrefsService prefs,
  NotificationService service,
) async {
  if (!NotificationService.supported) return;
  if (!prefs.getRemindersMaster()) return;
  final l10n = await _l10nFor(AppLocale.fromName(prefs.getLocale()));
  for (final slot in ReminderSlot.values) {
    // Always clear first: a release before weekday support left a bare-id
    // daily notification behind, and rescheduling never touches that id.
    await service.cancelSlot(slot.notificationId);
    if (!prefs.getReminderEnabled(slot.key)) continue;
    final time = _parseTime(
      prefs.getReminderTime(slot.key, fallback: slot.defaultTime),
    );
    for (final weekday in parseReminderDays(prefs.getReminderDays(slot.key))) {
      await service.scheduleWeekly(
        id: NotificationService.weekdayId(slot.notificationId, weekday),
        weekday: weekday,
        hour: time.hour,
        minute: time.minute,
        title: slot.notificationTitle(l10n),
        body: l10n.reminderNotificationBody,
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
      );
    }
  }
}

/// Reminder state and scheduling logic.
///
/// Changes persist to prefs and immediately schedule/cancel notifications.
class RemindersController extends Notifier<Map<ReminderSlot, ReminderSetting>> {
  @override
  Map<ReminderSlot, ReminderSetting> build() {
    final prefs = ref.read(prefsServiceProvider);

    // The OS stores notification text at schedule time. After a locale change,
    // already scheduled notifications stay in the old language until rescheduled.
    ref.listen(settingsControllerProvider.select((s) => s.locale), (_, _) {
      for (final slot in ReminderSlot.values) {
        if (state[slot]!.enabled) _apply(slot);
      }
    });

    return {
      for (final slot in ReminderSlot.values)
        slot: (
          enabled: prefs.getReminderEnabled(slot.key),
          time: _parseTime(
            prefs.getReminderTime(slot.key, fallback: slot.defaultTime),
          ),
          days: parseReminderDays(prefs.getReminderDays(slot.key)),
        ),
    };
  }

  void setEnabled(ReminderSlot slot, bool enabled) {
    final current = state[slot]!;
    state = {
      ...state,
      slot: (enabled: enabled, time: current.time, days: current.days),
    };
    ref.read(prefsServiceProvider).setReminderEnabled(slot.key, enabled);
    _apply(slot);
  }

  void setTime(ReminderSlot slot, TimeOfDay time) {
    final current = state[slot]!;
    state = {
      ...state,
      slot: (enabled: current.enabled, time: time, days: current.days),
    };
    ref.read(prefsServiceProvider).setReminderTime(slot.key, _formatTime(time));
    _apply(slot);
  }

  /// Sets which weekdays a slot fires on.
  ///
  /// An empty set is refused rather than stored: an enabled reminder with no
  /// days would silently never arrive, which looks exactly like a bug in the
  /// notification. The UI makes the last selected day a no-op for the same
  /// reason.
  void setDays(ReminderSlot slot, Set<int> days) {
    if (days.isEmpty) return;
    final current = state[slot]!;
    state = {
      ...state,
      slot: (enabled: current.enabled, time: current.time, days: days),
    };
    ref
        .read(prefsServiceProvider)
        .setReminderDays(slot.key, formatReminderDays(days));
    _apply(slot);
  }

  /// Re-applies every slot, used when the master switch flips.
  Future<void> applyAll() async {
    for (final slot in ReminderSlot.values) {
      await _apply(slot);
    }
  }

  Future<void> _apply(ReminderSlot slot) async {
    final setting = state[slot]!;
    final service = ref.read(notificationServiceProvider);
    // Always clear the slot first; the set of weekdays may have shrunk, and a
    // day that is no longer chosen has to lose its scheduled notification.
    await service.cancelSlot(slot.notificationId);
    // The master switch gates every slot without clearing the per-slot values,
    // so turning it back on restores the times the user already chose.
    if (!setting.enabled || !ref.read(remindersMasterProvider)) return;
    final l10n = await _l10nFor(ref.read(settingsControllerProvider).locale);
    for (final weekday in setting.days) {
      await service.scheduleWeekly(
        id: NotificationService.weekdayId(slot.notificationId, weekday),
        weekday: weekday,
        hour: setting.time.hour,
        minute: setting.time.minute,
        title: slot.notificationTitle(l10n),
        body: l10n.reminderNotificationBody,
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
      );
    }
  }
}

final remindersControllerProvider =
    NotifierProvider<RemindersController, Map<ReminderSlot, ReminderSetting>>(
      RemindersController.new,
    );

/// Master switch shown on the settings hub, above the per-slot times.
///
/// Kept apart from [RemindersController] so its state stays a map of slots:
/// the master is not a slot, and folding it in would make every reader of that
/// map handle a key that has no time.
class RemindersMasterController extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsServiceProvider).getRemindersMaster();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(prefsServiceProvider).setRemindersMaster(value);
    await ref.read(remindersControllerProvider.notifier).applyAll();
  }
}

final remindersMasterProvider =
    NotifierProvider<RemindersMasterController, bool>(
      RemindersMasterController.new,
    );

/// Whether this device can schedule exact reminders.
///
/// Android 12+ requires user permission. Settings invalidates this provider after
/// returning from system settings to re-check whether the explanation box is still
/// needed.
final exactAlarmAllowedProvider = FutureProvider<bool>((ref) async {
  return ref.read(notificationServiceProvider).canScheduleExact();
});
