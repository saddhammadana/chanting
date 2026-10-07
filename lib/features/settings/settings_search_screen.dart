import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../theme/dashboard_tokens.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// One searchable setting: what it is called, and the page that owns it.
typedef SettingsSearchEntry = ({
  IconData icon,
  String title,
  String section,
  String route,
});

/// Every setting the hub can reach, flattened.
///
/// The hub only shows seven rows, so a setting a user remembers by name — text
/// size, page colour, the bell — is now two pages away with nothing on screen
/// naming it. This list is what the search box looks through, and it is built
/// from the same `l10n` getters the pages use, so a renamed setting cannot go
/// stale here.
///
/// **Adding a control to a settings page means adding it here too.** Nothing
/// enforces that — the index is a hand-kept list — and a setting missing from
/// it is unfindable by name, which is the whole reason the search exists.
/// `settings_search_test` at least checks that every route named here is
/// reachable.
List<SettingsSearchEntry> settingsSearchEntries(AppLocalizations l10n) {
  const reading = '/settings/reading';
  const goal = '/settings/goal';
  return [
    (
      icon: Icons.auto_stories_outlined,
      title: l10n.settingsReadingMode,
      section: l10n.settingsSectionReading,
      route: reading,
    ),
    (
      icon: Icons.play_circle_outline,
      title: l10n.settingsAutoScroll,
      section: l10n.settingsSectionReading,
      route: reading,
    ),
    (
      icon: Icons.schedule_outlined,
      title: l10n.settingsAutoScrollDelay,
      section: l10n.settingsSectionReading,
      route: reading,
    ),
    (
      icon: Icons.format_size,
      title: l10n.settingsFontSize,
      section: l10n.settingsSectionText,
      route: reading,
    ),
    (
      icon: Icons.abc,
      title: l10n.settingsShowRomanDefault,
      section: l10n.settingsSectionContent,
      route: reading,
    ),
    (
      icon: Icons.translate_outlined,
      title: l10n.settingsShowMeaningDefault,
      section: l10n.settingsSectionContent,
      route: reading,
    ),
    (
      icon: Icons.format_indent_increase,
      title: l10n.settingsInlineTranslation,
      section: l10n.settingsSectionContent,
      route: reading,
    ),
    (
      icon: Icons.palette_outlined,
      title: l10n.settingsTextColor,
      section: l10n.settingsSectionText,
      route: reading,
    ),
    (
      icon: Icons.title_outlined,
      title: l10n.settingsShowPartTitles,
      section: l10n.settingsSectionText,
      route: reading,
    ),
    (
      icon: Icons.format_line_spacing,
      title: l10n.settingsLineSpacing,
      section: l10n.settingsSectionText,
      route: reading,
    ),
    (
      icon: Icons.format_align_justify,
      title: l10n.settingsTextAlign,
      section: l10n.settingsSectionText,
      route: reading,
    ),
    (
      icon: Icons.palette_outlined,
      title: l10n.settingsSectionBackground,
      section: l10n.settingsSectionReading,
      route: reading,
    ),
    (
      icon: Icons.light_mode_outlined,
      title: l10n.settingsKeepScreenOn,
      section: l10n.settingsSectionScreen,
      route: reading,
    ),
    (
      icon: Icons.visibility_off_outlined,
      title: l10n.settingsStartImmersive,
      section: l10n.settingsSectionScreen,
      route: reading,
    ),
    (
      icon: Icons.schedule_outlined,
      title: l10n.goalReminderTime,
      section: l10n.settingsSectionReminders,
      route: goal,
    ),
    (
      icon: Icons.calendar_month_outlined,
      title: l10n.goalSectionDays,
      section: l10n.settingsSectionReminders,
      route: goal,
    ),
    (
      icon: Icons.track_changes_outlined,
      title: l10n.settingsPracticeGoal,
      section: l10n.goalSectionDaily,
      route: goal,
    ),
    (
      icon: Icons.volume_up_outlined,
      title: l10n.settingsSectionSignal,
      section: l10n.settingsSectionGeneral,
      route: '/settings/sound',
    ),
    (
      icon: Icons.notifications_outlined,
      title: l10n.completionVolume,
      section: l10n.settingsSectionSignal,
      route: '/settings/sound',
    ),
    (
      icon: Icons.language,
      title: l10n.settingsLanguage,
      section: l10n.settingsSectionGeneral,
      route: '/settings/language',
    ),
    (
      icon: Icons.palette_outlined,
      title: l10n.settingsTheme,
      section: l10n.settingsSectionGeneral,
      route: '/settings/theme',
    ),
    (
      icon: Icons.info_outline,
      title: l10n.aboutApp,
      section: l10n.aboutSectionAbout,
      route: '/about',
    ),
    (
      icon: Icons.tour_outlined,
      title: l10n.aboutReplayTour,
      section: l10n.aboutSectionAbout,
      route: '/about',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: l10n.settingsLegal,
      section: l10n.aboutSectionAbout,
      route: '/legal',
    ),
  ];
}

/// Search across every setting, landing on the page that holds it.
class SettingsSearchScreen extends StatefulWidget {
  const SettingsSearchScreen({super.key});

  @override
  State<SettingsSearchScreen> createState() => _SettingsSearchScreenState();
}

class _SettingsSearchScreenState extends State<SettingsSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _controller.text.trim().toLowerCase();
    final matches = [
      for (final entry in settingsSearchEntries(l10n))
        if (query.isEmpty ||
            entry.title.toLowerCase().contains(query) ||
            entry.section.toLowerCase().contains(query))
          entry,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        leadingWidth: 64,
        // The same `SearchBar` `prayers_search` uses (`searchBarTheme`'s 24
        // radius, `outlineVariant` border, card fill) — a second, differently
        // framed search field would read as two kinds of search in one app.
        // Smaller because it sits inside the fixed 56px AppBar, not the body.
        // The shadow is the back button's, cast by a stadium behind the bar:
        // `SearchBar` only takes an elevation, which cannot match it.
        title: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(appCircleButtonSize / 2),
            boxShadow: DashboardTokens.softShadows(Theme.of(context)),
          ),
          child: SearchBar(
            key: const ValueKey('settings_search_field'),
            controller: _controller,
            autoFocus: true,
            hintText: l10n.settingsSearch,
            leading: const Icon(Icons.search),
            // Edged like the back button beside it; `prayers_search` in the
            // page body stays flat through `searchBarTheme`.
            side: WidgetStatePropertyAll(
              BorderSide(color: DashboardTokens.controlEdge(Theme.of(context))),
            ),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            // Exactly `appCircleButtonSize`, so the search bar and the
            // back button line up on the same height, not just under a cap.
            constraints: const BoxConstraints(
              minHeight: appCircleButtonSize,
              maxHeight: appCircleButtonSize,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.gridWidth,
        child: matches.isEmpty
            ? EmptyState(
                icon: Icons.search_off,
                message: l10n.settingsSearchEmpty,
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  SettingsCard(
                    children: [
                      for (final entry in matches)
                        SettingsTile(
                          icon: entry.icon,
                          title: entry.title,
                          subtitle: entry.section,
                          // Replace, so Back returns to the hub rather than to
                          // a search box the user has finished with.
                          onTap: () => context.pushReplacement(entry.route),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
