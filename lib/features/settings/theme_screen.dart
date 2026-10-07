import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// App theme picker: light, dark, or whatever the device is set to.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );

    String label(ThemeMode mode) => switch (mode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
    IconData icon(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };

    return SettingsScaffold(
      title: l10n.settingsTheme,
      leading: const AppBackButton(),
      children: [
        SettingsSectionHeader(l10n.settingsTheme),
        RadioGroup<ThemeMode>(
          groupValue: selected,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setThemeMode(value!),
          child: SettingsCard(
            children: [
              // Ordered light, dark, system — the two real choices first, the
              // deferral last, matching the segmented control this replaced.
              for (final mode in [
                ThemeMode.light,
                ThemeMode.dark,
                ThemeMode.system,
              ])
                RadioListTile<ThemeMode>(
                  key: ValueKey('theme_${mode.name}'),
                  value: mode,
                  secondary: Icon(icon(mode)),
                  title: Text(label(mode)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: SettingHint(l10n.settingsThemeSubtitle),
        ),
      ],
    );
  }
}
