import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';
import 'widgets/auto_scroll_card.dart';
import 'widgets/font_scale_card.dart';
import 'widgets/lane_color_row.dart';
import 'widgets/page_color_row.dart';
import 'widgets/reading_layout_cards.dart';
import 'widgets/reading_option_tiles.dart';
import 'widgets/reading_preview_card.dart';
import 'widgets/reading_reset_button.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// Everything about how a prayer looks while it is being read.
///
/// Laid out from `design/mobile/serene/Thai Reader Settings Preview.png`: the
/// live sample first, then the settings that change it, in the order they
/// change it — size, which layers show, spacing, paper, scrolling, screen.
/// There is no save button because nothing here is deferred; every change is
/// written the moment it is made, which is what the note under the sample
/// says.
class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    // What the reader will actually be printed on, which is what the sample
    // and the lane colours below have to be measured against.
    final page = effectiveReadingBackground(
      settings.pageBackground,
      theme.brightness,
    );
    final darkForced = theme.brightness == Brightness.dark;

    return SettingsScaffold(
      title: l10n.settingsReadingEntry,
      leading: const AppBackButton(),
      actions: [
        ReadingResetButton(onReset: controller.resetReadingDefaults),
        const SizedBox(width: 16),
      ],
      children: [
        SettingsSectionHeader(l10n.readingPreviewTitle),
        ReadingPreviewCard(settings: settings, page: page),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Center(child: SettingHint(l10n.readingPreviewNote)),
        ),

        SettingsSectionHeader(l10n.settingsFontSize),
        FontScaleCard(
          fontScale: settings.fontScale,
          onChanged: controller.setFontScale,
        ),

        SettingsSectionHeader(l10n.settingsSectionContent),
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.abc,
              title: l10n.settingsShowRomanDefault,
              subtitle: l10n.settingsShowRomanDefaultHint,
              trailing: Switch(
                key: const ValueKey('show_roman_default'),
                value: settings.showRomanDefault,
                onChanged: controller.setShowRomanDefault,
              ),
              onTap: () =>
                  controller.setShowRomanDefault(!settings.showRomanDefault),
            ),
            SettingsTile(
              icon: Icons.translate_outlined,
              title: l10n.settingsShowMeaningDefault,
              subtitle: l10n.settingsShowMeaningDefaultHint,
              trailing: Switch(
                key: const ValueKey('show_meaning_default'),
                value: settings.showMeaningDefault,
                onChanged: controller.setShowMeaningDefault,
              ),
              onTap: () => controller.setShowMeaningDefault(
                !settings.showMeaningDefault,
              ),
            ),
            SettingsTile(
              icon: Icons.format_indent_increase,
              title: l10n.settingsInlineTranslation,
              subtitle: l10n.settingsInlineTranslationHint,
              trailing: Switch(
                key: const ValueKey('inline_translation'),
                value: settings.inlineTranslation,
                onChanged: controller.setInlineTranslation,
              ),
              onTap: () =>
                  controller.setInlineTranslation(!settings.inlineTranslation),
            ),
          ],
        ),

        // Directly under the switches, because it is the same three lanes:
        // the block above says which ones show, this one says what colour each
        // is, and both are a glance away from the sample they change.
        SettingsSectionHeader(l10n.settingsTextColor),
        SettingsCard(
          children: [
            for (final lane in ReadingLane.values)
              LaneColorRow(
                lane: lane,
                color: settings.readingColors.of(lane),
                page: page,
              ),
          ],
        ),

        SettingsSectionHeader(l10n.settingsSectionLayout),
        ReadingLayoutCards(settings: settings, controller: controller),

        SettingsSectionHeader(l10n.settingsSectionBackground),
        PageColorRow(
          selected: page,
          enabled: !darkForced,
          onSelected: controller.setPageBackground,
        ),
        if (darkForced)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: SettingHint(l10n.readingBackgroundDarkNote),
          ),

        SettingsSectionHeader(l10n.settingsSectionScroll),
        AutoScrollCard(settings: settings, controller: controller),

        SettingsSectionHeader(l10n.settingsSectionScreen),
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.light_mode_outlined,
              title: l10n.settingsKeepScreenOn,
              subtitle: l10n.settingsKeepScreenOnHint,
              trailing: Switch(
                key: const ValueKey('keep_screen_on'),
                value: settings.keepScreenOn,
                onChanged: controller.setKeepScreenOn,
              ),
              onTap: () => controller.setKeepScreenOn(!settings.keepScreenOn),
            ),
            SettingsTile(
              icon: Icons.visibility_off_outlined,
              title: l10n.settingsStartImmersive,
              subtitle: l10n.settingsStartImmersiveHint,
              trailing: Switch(
                key: const ValueKey('start_immersive'),
                value: settings.startImmersive,
                onChanged: controller.setStartImmersive,
              ),
              onTap: () =>
                  controller.setStartImmersive(!settings.startImmersive),
            ),
          ],
        ),

        // Settings the app has that the artwork does not draw. They are real
        // and stay reachable; they sit last because they are chosen once.
        SettingsSectionHeader(l10n.settingsSectionMore),
        SettingsCard(
          children: [
            SettingGroup(
              icon: Icons.auto_stories_outlined,
              label: l10n.settingsReadingMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The page's own picker, as text alignment uses it: a
                  // Material segmented control was the one widget here not
                  // drawn in the app's cream-and-gold.
                  TilePicker<bool>(
                    keyPrefix: 'reading_mode',
                    inlineLabel: true,
                    tileHeight: 52,
                    options: [
                      (
                        value: false,
                        label: l10n.readingModeSwipe,
                        picture: Icon(
                          Icons.swipe_outlined,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      (
                        value: true,
                        label: l10n.readingModeContinuous,
                        picture: Icon(
                          Icons.view_day_outlined,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    selected: settings.continuousReading,
                    onSelected: controller.setContinuousReading,
                  ),
                  const SizedBox(height: 8),
                  SettingHint(
                    settings.continuousReading
                        ? l10n.readingModeContinuousHint
                        : l10n.readingModeSwipeHint,
                  ),
                ],
              ),
            ),
            SettingsTile(
              icon: Icons.title_outlined,
              title: l10n.settingsShowPartTitles,
              subtitle: l10n.settingsShowPartTitlesHint,
              trailing: Switch(
                key: const ValueKey('show_part_titles'),
                value: settings.showPartTitles,
                onChanged: controller.setShowPartTitles,
              ),
              onTap: () =>
                  controller.setShowPartTitles(!settings.showPartTitles),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Center(child: SettingHint(l10n.readingAppliesToAll)),
        ),
      ],
    );
  }
}
