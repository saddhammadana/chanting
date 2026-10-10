import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../content_update/content_update_controller.dart';
import 'reminders_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// Settings hub: four groups of rows, each opening the page that owns it.
///
/// The settings used to sit on one long page. The reference artwork makes it a
/// hub instead, which is also what the page had outgrown — sliders, colour
/// lanes, reminders and legal text on one scroll meant the setting you came
/// for was never the one on screen. Everything still exists; it lives one tap
/// deeper, under `lib/features/settings/`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final notificationsOn = ref.watch(remindersMasterProvider);

    return SettingsScaffold(
      title: l10n.settingsTitle,
      corners: true,
      actions: [
        IconButton(
          key: const ValueKey('settings_search_button'),
          icon: const Icon(Icons.search),
          tooltip: l10n.settingsSearch,
          style: appCircleIconButtonStyle(theme),
          onPressed: () => context.push('/settings/search'),
        ),
        const SizedBox(width: 8),
      ],
      children: [
        SettingsSectionHeader(l10n.settingsSectionReading),
        SettingsCard(
          watermark: true,
          children: [
            SettingsTile(
              key: const ValueKey('settings_reading'),
              icon: Icons.menu_book_outlined,
              title: l10n.settingsReadingEntry,
              subtitle: l10n.settingsReadingEntrySubtitle,
              onTap: () => context.push('/settings/reading'),
            ),
          ],
        ),
        SettingsSectionHeader(l10n.settingsSectionReminders),
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: l10n.settingsSectionReminders,
              subtitle: l10n.settingsNotificationsSubtitle,
              trailing: Switch(
                key: const ValueKey('notifications_master'),
                value: notificationsOn,
                onChanged: (value) =>
                    ref.read(remindersMasterProvider.notifier).set(value),
              ),
              onTap: () => ref
                  .read(remindersMasterProvider.notifier)
                  .set(!notificationsOn),
            ),
            SettingsTile(
              key: const ValueKey('settings_goal'),
              icon: Icons.calendar_month_outlined,
              title: l10n.settingsGoalEntry,
              subtitle: l10n.settingsGoalEntrySubtitle,
              // Reachable while off so the times can be read; the page itself
              // says why the switches there are inert.
              onTap: () => context.push('/settings/goal'),
            ),
          ],
        ),
        SettingsSectionHeader(l10n.settingsSectionGeneral),
        SettingsCard(
          children: [
            SettingsTile(
              key: const ValueKey('settings_language'),
              icon: Icons.language,
              title: l10n.settingsLanguage,
              subtitle: l10n.settingsLanguageSubtitle,
              onTap: () => context.push('/settings/language'),
            ),
            SettingsTile(
              key: const ValueKey('settings_theme'),
              icon: Icons.palette_outlined,
              title: l10n.settingsTheme,
              subtitle: l10n.settingsThemeSubtitle,
              onTap: () => context.push('/settings/theme'),
            ),
            SettingsTile(
              key: const ValueKey('settings_sound'),
              icon: Icons.volume_up_outlined,
              title: l10n.settingsSectionSignal,
              subtitle: l10n.settingsCompletionSignal,
              onTap: () => context.push('/settings/sound'),
            ),
            if (contentUpdateSupported)
              SettingsTile(
                key: const ValueKey('settings_content'),
                icon: Icons.cloud_download_outlined,
                title: l10n.settingsContentUpdate,
                subtitle: l10n.settingsContentUpdateSubtitle,
                onTap: () => context.push('/settings/content'),
              ),
          ],
        ),
        SettingsSectionHeader(l10n.aboutSectionAbout),
        SettingsCard(
          children: [
            SettingsTile(
              key: const ValueKey('settings_about'),
              icon: Icons.info_outline,
              title: l10n.aboutApp,
              subtitle: l10n.aboutAppSubtitle,
              onTap: () => context.push('/about'),
            ),
            SettingsTile(
              key: const ValueKey('settings_legal'),
              icon: Icons.verified_user_outlined,
              title: l10n.settingsLegal,
              subtitle: l10n.settingsLegalSubtitle,
              onTap: () => context.push('/legal'),
            ),
          ],
        ),
        // Read the version from package metadata instead of hardcoding.
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(
              snapshot.hasData
                  ? l10n.appVersion(
                      snapshot.data!.version,
                      snapshot.data!.buildNumber,
                    )
                  : '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
