import 'package:flutter/material.dart';

import '../../../shared/widgets/app_asset_image.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';
import 'reading_color_picker.dart';

/// The live sample, printed on the page the reader will actually use.
class ReadingPreviewCard extends StatelessWidget {
  const ReadingPreviewCard({
    super.key,
    required this.settings,
    required this.page,
  });

  final SettingsState settings;
  final ReadingBackground page;

  /// Whether a companion lane is shown at all, per the switches above.
  bool _shows(ReadingLane lane) => switch (lane) {
    ReadingLane.chant => true,
    ReadingLane.roman => settings.showRomanDefault,
    ReadingLane.meaning => settings.showMeaningDefault,
  };

  /// One lane of the sample, in the colour it will be read in.
  Widget _line(ThemeData theme, ReadingLane lane, TextAlign align) => Text(
    // Real liturgical sample; do not move to ARB or translate.
    sampleFor(lane),
    textAlign: align,
    style: theme.textTheme.bodyLarge?.copyWith(
      // Companion lanes match the reader's smaller size.
      fontSize: (lane == ReadingLane.chant ? 18 : 15) * settings.fontScale,
      fontWeight: lane == ReadingLane.chant ? FontWeight.w600 : null,
      fontStyle: lane == ReadingLane.roman ? FontStyle.italic : null,
      height: settings.lineSpacing.height,
      // The sample is printed on the chosen page, so its colours must resolve
      // against that, not the theme.
      color:
          settings.readingColors.of(lane).resolve(page.brightness) ??
          defaultReadingText(
            page.brightness,
          ).withValues(alpha: lane == ReadingLane.chant ? 1.0 : 0.8),
    ),
  );

  /// A companion lane grouped in its own box, as the reader does when the
  /// inline switch is off. The fill follows the page, like `_supportBox`.
  Widget _companionBox(ThemeData theme, ReadingLane lane, TextAlign align) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              (page.brightness == Brightness.dark
                      ? AppColors.darkGoldSoft
                      : AppColors.goldSoft)
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _line(theme, lane, align),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = settings.justifyText ? TextAlign.justify : TextAlign.start;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: page.color,
      child: Stack(
        children: [
          // The watermark is a lotus emblem against the card's foot, kept
          // faint enough to read as paper rather than as a second element on
          // the card — which is what a stronger one did here once.
          // `Positioned.fill` plus `Align` is what allows "against whatever
          // height the card turns out to be": the card grows and shrinks with
          // the lane switches, so there is no height to position against.
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: Transform.translate(
                    offset: const Offset(18, 14),
                    child: const Opacity(
                      opacity: 0.22,
                      child: AppAssetImage(
                        'assets/images/settings/golden_ivory_lotus_emblem.png',
                        width: 175,
                        fit: BoxFit.contain,
                        cacheWidth: 320,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The sample has to answer every switch under it, or it is a
                // picture rather than a preview: the two lane switches decide
                // whether a lane appears at all, and the inline switch decides
                // whether it sits under the chant or in its own box the way
                // the reader groups them at the end of a prayer.
                _line(theme, ReadingLane.chant, align),
                for (final lane in const [
                  ReadingLane.roman,
                  ReadingLane.meaning,
                ])
                  if (_shows(lane))
                    settings.inlineTranslation
                        ? _line(theme, lane, align)
                        : _companionBox(theme, lane, align),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
