import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_controller.dart';
import 'settings_tile.dart';
import 'slider_track_labels.dart';

/// Auto-scroll: the switch, and under it the controls it governs.
class AutoScrollCard extends StatelessWidget {
  const AutoScrollCard({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SettingsCard(
      children: [
        SettingsTile(
          icon: Icons.play_circle_outline,
          title: l10n.settingsAutoScroll,
          // Only the off state needs a subtitle. Switched on, the row is
          // followed by the controls it governs, and the note about the ▶
          // button belongs with them rather than in the row's own line.
          subtitle: settings.autoScrollEnabled ? null : l10n.autoScrollOffHint,
          trailing: Switch(
            key: const ValueKey('auto_scroll_enabled'),
            value: settings.autoScrollEnabled,
            onChanged: controller.setAutoScrollEnabled,
          ),
          onTap: () =>
              controller.setAutoScrollEnabled(!settings.autoScrollEnabled),
        ),
        if (settings.autoScrollEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: const ValueKey('auto_scroll_slider'),
                        value: settings.autoScrollLevel.toDouble(),
                        min: kAutoScrollLevelMin.toDouble(),
                        max: kAutoScrollLevelMax.toDouble(),
                        divisions: kAutoScrollLevelMax - kAutoScrollLevelMin,
                        label: l10n.autoScrollLevel(settings.autoScrollLevel),
                        onChanged: (value) =>
                            controller.setAutoScrollLevel(value.round()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueBadge(l10n.autoScrollLevel(settings.autoScrollLevel)),
                  ],
                ),
                SliderTrackLabels(
                  start: l10n.autoScrollSlow,
                  middle: l10n.lineSpacingNormal,
                  end: l10n.autoScrollFast,
                ),
                const SizedBox(height: 4),
                SettingHint(l10n.autoScrollHint),
              ],
            ),
          ),
          SettingsTile(
            key: const ValueKey('auto_scroll_auto_start'),
            icon: Icons.bolt_outlined,
            title: l10n.autoScrollAutoStart,
            trailing: Switch(
              value: settings.autoScrollAutoStart,
              onChanged: controller.setAutoScrollAutoStart,
            ),
            onTap: () => controller.setAutoScrollAutoStart(
              !settings.autoScrollAutoStart,
            ),
          ),
          SettingsTile(
            key: const ValueKey('auto_scroll_delay'),
            icon: Icons.schedule_outlined,
            title: l10n.settingsAutoScrollDelay,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _delayLabel(l10n, settings.autoScrollDelaySeconds),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => _pickDelay(context),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDelay(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.settingsAutoScrollDelay),
        children: [
          for (final seconds in kAutoScrollDelayChoices)
            RadioListTile<int>(
              key: ValueKey('auto_scroll_delay_$seconds'),
              value: seconds,
              // A one-shot picker, so the group lives on the tile rather than
              // in a RadioGroup the dialog would have to hold state for.
              // ignore: deprecated_member_use
              groupValue: settings.autoScrollDelaySeconds,
              title: Text(_delayLabel(l10n, seconds)),
              // ignore: deprecated_member_use
              onChanged: (value) => Navigator.of(dialogContext).pop(value),
            ),
        ],
      ),
    );
    if (picked != null) {
      controller.setAutoScrollDelaySeconds(picked);
    }
  }
}

String _delayLabel(AppLocalizations l10n, int seconds) => seconds <= 0
    ? l10n.settingsAutoScrollDelayNone
    : l10n.settingsAutoScrollDelayValue(seconds);
