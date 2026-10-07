import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'reading_option_tiles.dart';

/// The four sheets of paper, as a row of swatches.
class PageColorRow extends StatelessWidget {
  const PageColorRow({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final ReadingBackground selected;
  final bool enabled;
  final ValueChanged<ReadingBackground> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: IgnorePointer(
          ignoring: !enabled,
          child: TilePicker<ReadingBackground>(
            keyPrefix: 'page_color',
            tileHeight: 76,
            options: [
              for (final value in ReadingBackground.values)
                (
                  value: value,
                  label: value.label(l10n),
                  picture: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox.expand(
                      child: PageColorSwatch(
                        color: value.color,
                        brightness: value.brightness,
                      ),
                    ),
                  ),
                ),
            ],
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }
}
