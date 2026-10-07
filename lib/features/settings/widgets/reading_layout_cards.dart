import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';
import 'reading_option_tiles.dart';
import 'settings_tile.dart';

/// Line spacing and text alignment, each on its own row.
class ReadingLayoutCards extends StatelessWidget {
  const ReadingLayoutCards({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final spacing = _LabelledCard(
      icon: Icons.format_line_spacing,
      title: l10n.settingsLineSpacing,
      child: TilePicker<AppLineSpacing>(
        keyPrefix: 'line_spacing',
        inlineLabel: true,
        tileHeight: 52,
        options: [
          for (final value in AppLineSpacing.values)
            (
              value: value,
              label: value.label(l10n),
              picture: LineSpacingGlyph(
                gap: switch (value) {
                  AppLineSpacing.compact => 3,
                  AppLineSpacing.normal => 6,
                  AppLineSpacing.loose => 9,
                },
              ),
            ),
        ],
        selected: settings.lineSpacing,
        onSelected: controller.setLineSpacing,
      ),
    );

    final alignment = _LabelledCard(
      icon: Icons.format_align_left,
      title: l10n.settingsTextAlign,
      child: TilePicker<bool>(
        keyPrefix: 'text_align',
        inlineLabel: true,
        tileHeight: 52,
        options: [
          (
            value: false,
            label: l10n.textAlignStart,
            picture: const TextAlignGlyph(justify: false),
          ),
          (
            value: true,
            label: l10n.textAlignJustify,
            picture: const TextAlignGlyph(justify: true),
          ),
        ],
        selected: settings.justifyText,
        onSelected: controller.setJustifyText,
      ),
    );

    // One above the other, each card the full width (owner decision,
    // September 2026): side by side, as the artwork pairs them, left each
    // tile too narrow for its label on a phone.
    return Column(children: [spacing, alignment]);
  }
}

/// A card whose own small heading — an accent icon and a title, at the
/// start like every other setting row — sits above its contents.
class _LabelledCard extends StatelessWidget {
  const _LabelledCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RaisedCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
