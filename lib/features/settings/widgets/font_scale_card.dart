import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'settings_tile.dart';
import 'slider_track_labels.dart';

/// The text size slider, between a small and a large sample glyph.
class FontScaleCard extends StatelessWidget {
  const FontScaleCard({
    super.key,
    required this.fontScale,
    required this.onChanged,
  });

  final double fontScale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    l10n.fontSizeSample,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                  ),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('font_scale_slider'),
                      value: fontScale,
                      min: kFontScaleMin,
                      max: kFontScaleMax,
                      divisions:
                          ((kFontScaleMax - kFontScaleMin) / kFontScaleStep)
                              .round(),
                      label: l10n.fontScalePercent((fontScale * 100).round()),
                      onChanged: onChanged,
                    ),
                  ),
                  Text(
                    l10n.fontSizeSample,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  // The percentage, not the word under the track: the word
                  // says roughly where the thumb is, the number says what
                  // was actually chosen, and only one of those can be read
                  // back to someone.
                  ValueBadge(l10n.fontScalePercent((fontScale * 100).round())),
                ],
              ),
              SliderTrackLabels(
                start: l10n.fontSizeSmall,
                middle: l10n.fontSizeNormal,
                end: l10n.fontSizeLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
