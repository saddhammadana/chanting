import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';
import 'reading_color_picker.dart';
import 'settings_tile.dart';

/// One reading lane's color row.
class LaneColorRow extends ConsumerWidget {
  const LaneColorRow({
    super.key,
    required this.lane,
    required this.color,
    required this.page,
  });

  final ReadingLane lane;
  final ReadingColor color;
  final ReadingBackground page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // The swatch previews the colour on the chosen page, so it is the page's
    // brightness that decides which half of a custom pair is shown.
    final brightness = page.brightness;
    final swatch = color.resolve(brightness) ?? defaultReadingText(brightness);

    return ListTile(
      key: ValueKey('lane_color_${lane.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: swatch,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        // `auto` shows the theme glyph, not a picked swatch.
        child: color.isAuto
            ? Center(
                child: Text(
                  l10n.fontSizeSample,
                  style: TextStyle(
                    color: page.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            : null,
      ),
      // Same rank as the lane switches this row sits under, so it is drawn
      // with the same title style `SettingsTile` uses; a `ListTile` default
      // would make the colour rows read as a lesser kind of setting.
      title: Text(
        lane.label(l10n),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueBadge(color.label(l10n)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final picked = await showReadingColorPicker(
          context: context,
          lane: lane,
          current: color,
          brightness: brightness,
          background: page.color,
        );
        if (picked != null) {
          ref
              .read(settingsControllerProvider.notifier)
              .setLaneColor(lane, picked);
        }
      },
    );
  }
}
