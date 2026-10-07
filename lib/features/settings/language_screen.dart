import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_localizations.dart';
import 'settings_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// UI language picker.
///
/// A list of rows rather than the dropdown this used to be: with a page of its
/// own there is room to show every language at once, and the welcome sheet
/// still uses `LanguageDropdown` where there is not.
///
/// Language names are always shown as endonyms so users can find their own
/// language even when the current UI language is unfamiliar; only the "system"
/// option is localized. See `AppLocale.endonym`.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(
      settingsControllerProvider.select((s) => s.locale),
    );

    return SettingsScaffold(
      title: l10n.settingsLanguage,
      leading: const AppBackButton(),
      children: [
        SettingsSectionHeader(l10n.settingsLanguage),
        RadioGroup<AppLocale>(
          groupValue: selected,
          onChanged: (value) =>
              ref.read(settingsControllerProvider.notifier).setLocale(value!),
          child: SettingsCard(
            children: [
              for (final option in AppLocale.values)
                RadioListTile<AppLocale>(
                  key: ValueKey('language_${option.name}'),
                  value: option,
                  title: Text(option.endonym ?? l10n.settingsLanguageSystem),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: SettingHint(l10n.settingsLanguageContentNote),
        ),
      ],
    );
  }
}
