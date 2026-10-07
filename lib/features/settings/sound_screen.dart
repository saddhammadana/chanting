import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/completion_signal.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/sound_volume_card.dart';
import 'settings_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// How the app announces that something has finished, laid out as the theme
/// page is: one card of choices with an icon at the end of each row, and the
/// explanation under it.
///
/// Its own page under General rather than a block on the goal page, where it
/// sat only because it came along when the reminders page was rebuilt: this
/// signal fires at the end of a meditation sitting and on a completed mala
/// round, neither of which is a reminder at a time of day.
///
/// The meditation timer keeps its own copy of the same setting as "End
/// signal", so someone already sitting does not have to leave the screen to
/// change it; both read `settingsControllerProvider`, so they cannot drift.
class SoundScreen extends ConsumerWidget {
  const SoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(
      settingsControllerProvider.select((s) => s.completionSignal),
    );
    final volume = ref.watch(
      settingsControllerProvider.select((s) => s.completionVolume),
    );
    final player = ref.read(completionSignalPlayerProvider);

    IconData icon(CompletionSignal signal) => switch (signal) {
      CompletionSignal.sound => Icons.notifications_outlined,
      CompletionSignal.haptic => Icons.vibration,
      CompletionSignal.silent => Icons.notifications_off_outlined,
    };

    return SettingsScaffold(
      title: l10n.settingsSectionSignal,
      leading: const AppBackButton(),
      children: [
        SettingsSectionHeader(l10n.settingsCompletionSignal),
        RadioGroup<CompletionSignal>(
          groupValue: selected,
          onChanged: (value) {
            ref
                .read(settingsControllerProvider.notifier)
                .setCompletionSignal(value!);
            // Heard as it is chosen, the way a nature sound is.
            if (value == CompletionSignal.sound) {
              player.preview(volume: volume);
            }
          },
          child: SettingsCard(
            children: [
              for (final signal in CompletionSignal.values)
                RadioListTile<CompletionSignal>(
                  key: ValueKey('signal_${signal.name}'),
                  value: signal,
                  // Web cannot play timer audio without a gesture.
                  enabled:
                      signal != CompletionSignal.sound ||
                      completionSoundSupported,
                  secondary: Icon(icon(signal)),
                  title: Text(signal.label(l10n)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: SettingHint(
            !completionSoundSupported && selected == CompletionSignal.sound
                ? l10n.completionSignalWebNote
                : switch (selected) {
                    CompletionSignal.sound => l10n.completionSignalHint,
                    // The platform APIs cannot report vibration state.
                    CompletionSignal.haptic => l10n.completionSignalHapticHint,
                    CompletionSignal.silent => l10n.completionSignalSilentHint,
                  },
          ),
        ),
        if (selected == CompletionSignal.sound && completionSoundSupported)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SoundVolumeCard(
              key: const ValueKey('completion_volume_card'),
              icon: icon(CompletionSignal.sound),
              title: l10n.completionSignalSound,
              subtitle: l10n.completionVolume,
              sliderLabel: l10n.completionVolume,
              sliderKey: const ValueKey('completion_volume'),
              volume: volume,
              onVolume: ref
                  .read(settingsControllerProvider.notifier)
                  .setCompletionVolume,
              // Rung once the thumb is let go, so the level is heard.
              onVolumeEnd: (value) => player.preview(volume: value),
            ),
          ),
        // The app cannot detect muted phones or disabled vibration, so trying
        // it is the only way to know it works.
        if (selected != CompletionSignal.silent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const ValueKey('completion_signal_test'),
                icon: Icon(
                  selected == CompletionSignal.sound
                      ? Icons.play_arrow
                      : Icons.vibration,
                ),
                label: Text(
                  selected == CompletionSignal.sound
                      ? l10n.completionSoundTest
                      : l10n.completionHapticTest,
                ),
                onPressed: () => player.play(selected, volume: volume),
              ),
            ),
          ),
      ],
    );
  }
}
