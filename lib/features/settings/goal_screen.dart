import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/custom_minutes_dialog.dart';
import '../../shared/widgets/duration_chip.dart';
import '../../shared/widgets/ornament_divider.dart';
import 'reminders_controller.dart';
import 'settings_controller.dart';
import 'widgets/goal_pickers.dart';
import 'widgets/reminder_notices.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';
import 'widgets/time_wheel_picker.dart';

/// Daily goal presets, from `Morning Chanting Goal Setup.png`.
///
/// Anything else is reachable through the custom chip, so the full
/// [kPracticeGoalMin]–[kPracticeGoalMax] range stays available; the presets
/// only save four taps for the four answers almost everyone gives.
const kGoalPresetMinutes = [5, 10, 15, 30];

/// When you chant, on which days, and for how long.
///
/// Laid out from `design/mobile/serene/Morning Chanting Goal Setup.png`. The
/// artwork's time-of-day row is a **picker for the slot being edited**, not a
/// single choice: this app is built around ทำวัตรเช้า *and* ทำวัตรเย็น, so
/// several reminders have to be able to be on at once. A tile carries a check
/// when its slot is switched on, and the panel underneath edits whichever tile
/// is selected.
///
/// The artwork's summary card is gone too (owner decision, October 2026): the
/// selected chip and each slot's own line already say what it repeated.
///
/// The artwork's ข้าม and บันทึกเป้าหมาย buttons are gone: every value here is
/// written the moment it is touched, so a save button would be the only
/// control on the page that did nothing.
class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key, this.onboarding = false});

  /// Opened once after install rather than from settings.
  ///
  /// The only difference is a ข้าม action: during onboarding "not now" is a
  /// real answer, whereas from settings there would be nothing to skip — every
  /// value on the page is already saved as it is touched.
  final bool onboarding;

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  /// The slot the panel below the tiles is editing. Opens on the first one
  /// that is switched on, because that is the one being kept.
  ReminderSlot? _editing;

  ReminderSlot _selected(Map<ReminderSlot, ReminderSetting> reminders) {
    final current = _editing;
    if (current != null) return current;
    return ReminderSlot.values.firstWhere(
      (slot) => reminders[slot]!.enabled,
      orElse: () => ReminderSlot.morning,
    );
  }

  Future<void> _pickTime(ReminderSlot slot, ReminderSetting setting) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(remindersControllerProvider.notifier);
    final picked = await showTimeWheelPicker(
      context: context,
      initialTime: setting.time,
      title: slot.pickerLabel(l10n),
    );
    if (picked == null) return;
    controller.setTime(slot, picked);
    // Choosing a time is how someone says they want this reminder; leaving it
    // saved but silent is the surprising half of that.
    if (!setting.enabled) controller.setEnabled(slot, true);
  }

  Future<void> _pickCustomGoal(int current) async {
    final l10n = AppLocalizations.of(context);
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => CustomMinutesDialog(
        initialMinutes: current,
        maxMinutes: kPracticeGoalMax,
        title: l10n.goalCustomTitle,
      ),
    );
    if (minutes != null) {
      ref
          .read(settingsControllerProvider.notifier)
          .setPracticeGoalMinutes(minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final reminders = ref.watch(remindersControllerProvider);
    final controller = ref.read(remindersControllerProvider.notifier);
    final masterOn = ref.watch(remindersMasterProvider);
    final goalMinutes = ref.watch(
      settingsControllerProvider.select((s) => s.practiceGoalMinutes),
    );
    final slot = _selected(reminders);
    final setting = reminders[slot]!;
    final supported = NotificationService.supported;

    return SettingsScaffold(
      title: l10n.goalTitle,
      // The same round button on both visits. Leaving it out for onboarding
      // did not remove the exit: with no `leading` the AppBar supplied its own
      // plain arrow, so the page had a back button either way, just not this
      // one.
      leading: const AppBackButton(),
      actions: widget.onboarding
          ? [
              AppPillButton(
                key: const ValueKey('goal_skip'),
                label: l10n.goalSkip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 16),
            ]
          : null,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(48, 8, 48, 0),
          child: OrnamentDivider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            children: [
              Text(
                l10n.goalHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.goalSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _GoalHero(),

        SettingsSectionHeader(l10n.goalSectionDaily),
        // First on the page: the home ring opens it, and the ring is this
        // number. Said out loud that it is not per slot, because everything
        // below the summary belongs to one time of day and this does not.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: SettingHint(l10n.goalDailyAllSlots),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final minutes in kGoalPresetMinutes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DurationChip(
                      key: ValueKey('goal_minutes_$minutes'),
                      label: l10n.meditationMinutes(minutes),
                      selected: goalMinutes == minutes,
                      onTap: () => ref
                          .read(settingsControllerProvider.notifier)
                          .setPracticeGoalMinutes(minutes),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DurationChip(
                    key: const ValueKey('goal_minutes_custom'),
                    label: kGoalPresetMinutes.contains(goalMinutes)
                        ? l10n.goalCustomMinutes
                        : l10n.meditationMinutes(goalMinutes),
                    selected: !kGoalPresetMinutes.contains(goalMinutes),
                    onTap: () => _pickCustomGoal(goalMinutes),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: SettingHint(l10n.settingsPracticeGoalHint),
        ),

        SettingsSectionHeader(l10n.goalSectionSlots),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final option in ReminderSlot.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SlotTile(
                      key: ValueKey('slot_tile_${option.name}'),
                      icon: _slotIcon(option),
                      label: option.shortLabel(l10n),
                      editing: option == slot,
                      // The check says "a reminder is set for this time of
                      // day"; the gold face says "this is the one you are
                      // editing". Two different facts, so two marks.
                      enabled: reminders[option]!.enabled,
                      onTap: () => setState(() => _editing = option),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // One panel for the slot the tiles have selected: its time, its days,
        // its switch. Days belong to a slot, so they are grouped with it —
        // loose on the page, between the tiles and a global setting, there is
        // nothing saying whose days they are.
        //
        // One child, so SettingsCard draws none of its row hairlines: those
        // separate a list of like rows, and between a heading, a row, the
        // day circles and a hint they read as stray grey lines.
        SettingsCard(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // At the start, on the line the rows below begin on: centred, it
                // floated alone above a left-aligned panel.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                    child: Text(
                      l10n.goalEditingSlot(slot.shortLabel(l10n)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SettingsTile(
                  key: const ValueKey('goal_time'),
                  icon: Icons.schedule_outlined,
                  title: l10n.goalReminderTime,
                  enabled: supported,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        setting.time.format(context),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => _pickTime(slot, setting),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          l10n.goalSectionDays,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      WeekdayPicker(
                        selected: setting.days,
                        enabled: supported,
                        onChanged: (days) => controller.setDays(slot, days),
                      ),
                    ],
                  ),
                ),
                SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: l10n.goalSlotEnabled,
                  // The reminder this switch is about, said back in one line.
                  subtitle: setting.enabled
                      ? l10n.goalSummarySlot(
                          slot.shortLabel(l10n),
                          setting.time.format(context),
                          describeWeekdays(context, setting.days),
                        )
                      : l10n.goalSlotDisabledHint,
                  enabled: supported,
                  trailing: Switch(
                    key: ValueKey('slot_switch_${slot.name}'),
                    value: setting.enabled,
                    onChanged: supported
                        ? (value) => controller.setEnabled(slot, value)
                        : null,
                  ),
                ),
                if (supported) const ExactAlarmNotice(),
                // Why every switch here is inert; the master lives on the hub, one
                // page back, so the reason is not visible from here.
                if (!masterOn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SettingHint(l10n.settingsRemindersOffHint),
                  ),
                if (!supported)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SettingHint(l10n.remindersUnsupported),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// One family, so the four read as a day: the sun coming up, overhead, going
/// down, and the moon. Evening used to be a Material light bulb, which said
/// "lamp" rather than a time of day.
IconData _slotIcon(ReminderSlot slot) => switch (slot) {
  ReminderSlot.morning => CupertinoIcons.sunrise,
  ReminderSlot.midday => CupertinoIcons.sun_max,
  ReminderSlot.evening => CupertinoIcons.sunset,
  ReminderSlot.bedtime => CupertinoIcons.moon,
};

/// The lotus-and-clock the goal artwork opens with.
class _GoalHero extends StatelessWidget {
  const _GoalHero();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12, bottom: 6),
      child: ExcludeSemantics(
        child: AppAssetImage(
          'assets/images/settings/golden_lotus_clock_emblem.png',
          // The artwork gives the hero about a sixth of the screen.
          height: 140,
          fit: BoxFit.contain,
          // The watercolor is twice as wide as it is tall; decode it whole.
          cacheWidth: 645,
        ),
      ),
    );
  }
}
