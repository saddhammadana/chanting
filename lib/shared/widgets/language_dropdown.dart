import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_controller.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/app_localizations.dart';

/// UI language selector used by Settings and the welcome sheet.
///
/// This is a dropdown rather than a segmented control because the language list is
/// expected to grow. Segmented controls overflow after only a few languages.
///
/// Language names are always shown as endonyms so users can find their own
/// language even when the current UI language is unfamiliar. Only the "system"
/// option is localized.
class LanguageDropdown extends ConsumerWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(
      settingsControllerProvider.select((s) => s.locale),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        // The app's text field: its fill, its edge and its corner.
        color: theme.inputDecorationTheme.fillColor,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      // Plain DropdownButton, not a FormField: the visible value comes directly
      // from provider state, so there is no internal stale value to keep in sync.
      child: DropdownButton<AppLocale>(
        value: locale,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        // The menu is a popup like any other in the app.
        dropdownColor: theme.popupMenuTheme.color,
        items: [
          for (final option in AppLocale.values)
            DropdownMenuItem(
              value: option,
              child: Text(option.endonym ?? l10n.settingsLanguageSystem),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) {
            ref.read(settingsControllerProvider.notifier).setLocale(selected);
          }
        },
      ),
    );
  }
}
