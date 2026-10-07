import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/sideways_scroll.dart';

/// Sticky bar below the reader AppBar, shared by both reading modes.
///
/// The two modes used to place these controls differently: continuous mode had
/// sticky chips on top, while one-prayer mode placed chips in the scroll body and
/// progress at the bottom. They are the same kind of information, so the top bar
/// now answers "what am I reading and how is it displayed"; the bottom controls
/// answer "where can I go next".
///
/// The bar's bottom border doubles as the progress line.
class ReadingTopBar extends StatelessWidget {
  const ReadingTopBar({
    super.key,
    required this.chips,
    this.position,
    this.positionListenable,
    this.total,
  });

  final List<Widget> chips;

  /// Static one-based prayer position for one-prayer mode.
  final int? position;

  /// Live zero-based prayer index for continuous mode.
  ///
  /// Continuous mode changes this while scrolling, so a notifier avoids rebuilding
  /// the whole category every time the visible prayer changes.
  final ValueListenable<int>? positionListenable;

  final int? total;

  Widget _bar(BuildContext context, int current, int count) =>
      LinearProgressIndicator(
        value: current / count,
        minHeight: 2,
        color: Theme.of(context).colorScheme.secondary,
        // Unreached progress uses the border color, preserving a visible bottom
        // edge even near the start.
        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
      );

  Widget _label(BuildContext context, int current, int count) => Text(
    AppLocalizations.of(context).prayerPosition(current, count),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = total ?? 0;
    final hasPosition =
        count > 1 && (position != null || positionListenable != null);
    // With neither chips nor position, leave no empty line across the screen.
    if (chips.isEmpty && !hasPosition) return const SizedBox.shrink();

    Widget withPosition(Widget Function(int current) builder) {
      final live = positionListenable;
      if (live == null) return builder(position ?? 1);
      return ValueListenableBuilder<int>(
        valueListenable: live,
        builder: (context, index, _) => builder(index + 1),
      );
    }

    return Column(
      key: const ValueKey('reading_top_bar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Padding stays outside ContentWidth like the scroll body below, aligning
        // chip left edge with content left edge.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ContentWidth(
            fillHeight: false,
            child: Row(
              children: [
                // Horizontal scroll, no wrapping. This bar is sticky; wrapping to
                // a second row would push the prayer content down mid-reading.
                //
                // SidewaysScroll enables mouse horizontal scrolling on web/desktop
                // where Flutter's default scroll behavior does not.
                Expanded(
                  child: SidewaysScroll(
                    builder: (context, controller) => SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: Row(spacing: 8, children: chips),
                    ),
                  ),
                ),
                if (hasPosition) ...[
                  const SizedBox(width: 12),
                  withPosition((current) => _label(context, current, count)),
                ],
              ],
            ),
          ),
        ),
        if (hasPosition)
          withPosition((current) => _bar(context, current, count))
        else
          Container(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
