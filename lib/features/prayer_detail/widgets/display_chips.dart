import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import 'prayer_content.dart';

/// Display chips for one prayer in paged mode, for `ReadingTopBar.chips`.
///
/// A list rather than a widget because the top bar collapses when it has no
/// chips to show.
List<Widget> displayChips(
  BuildContext context, {
  required Prayer prayer,
  required bool showPali,
  required ValueChanged<bool> onTogglePali,
  required bool showMeaning,
  required ValueChanged<bool> onToggleMeaning,
  required bool inlineTranslation,
  required ValueChanged<bool> onInlineTranslationChanged,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final canInline =
      (showPali && PrayerContent.canInlinePali(prayer)) ||
      (showMeaning && PrayerContent.canInlineMeaning(prayer));
  return [
    if (prayer.hasDistinctPali)
      FilterChip(
        label: Text(l10n.labelPali),
        selected: showPali,
        onSelected: onTogglePali,
      ),
    if (prayer.meaning != null)
      FilterChip(
        label: Text(l10n.labelMeaning),
        selected: showMeaning,
        onSelected: onToggleMeaning,
      ),
    if (showPali || showMeaning)
      if (canInline)
        ActionChip(
          avatar: Icon(
            Icons.swap_vert,
            size: 18,
            color: theme.colorScheme.secondary,
          ),
          label: Text(
            inlineTranslation ? l10n.chipInline : l10n.chipEndOfPrayer,
          ),
          onPressed: () => onInlineTranslationChanged(!inlineTranslation),
        )
      else
        Tooltip(
          message: l10n.inlineUnavailable,
          triggerMode: TooltipTriggerMode.tap,
          child: ActionChip(
            avatar: const Icon(Icons.swap_vert, size: 18),
            label: Text(l10n.chipEndOfPrayer),
            onPressed: null,
          ),
        ),
  ];
}
