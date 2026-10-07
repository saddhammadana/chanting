import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';

/// A prayer as a row in a list: its title and a preview of the text.
class PrayerCard extends StatelessWidget {
  const PrayerCard({
    super.key,
    required this.prayer,
    required this.onTap,
    this.highlight = '',
    this.badge,
    this.trailing,
    this.order,
  });

  final Prayer prayer;
  final VoidCallback onTap;

  /// Prayer order in the currently displayed list, starting at 1. Shown as the
  /// leading circular number.
  ///
  /// Previously every row used the same book icon, which consumed width without
  /// adding information. The number conveys chanting order inside the section or
  /// playlist, which is useful when chanting sequentially.
  ///
  /// Null means order is not meaningful, such as favorites ordered by save time;
  /// those rows use the book icon.
  final int? order;

  /// Search term to highlight in title and preview; empty means no highlight.
  final String highlight;

  /// Small badge under the title, such as "user-added", identifying prayers that
  /// were appended by the user rather than shipped with the section.
  final String? badge;

  /// Trailing widget replacing the chevron, such as a remove-extra-prayer button.
  final Widget? trailing;

  /// Split text into normal spans and highlighted spans matching the query.
  List<TextSpan> _spans(String text, TextStyle? base, Color highlightColor) {
    if (highlight.isEmpty || !text.contains(highlight)) {
      return [TextSpan(text: text, style: base)];
    }
    final marked = base?.copyWith(
      backgroundColor: highlightColor,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final index = text.indexOf(highlight, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: base));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style: marked,
        ),
      );
      start = index + highlight.length;
    }
    return spans;
  }

  /// Prayer preview line, **skipping leader prompt lines**.
  ///
  /// Many prayers start with the same leader-prompt prefix, pushing the unique
  /// words beyond row width. In morning chanting, several adjacent rows then look
  /// identical. The next line is the actual chant and differs clearly; data has
  /// been checked so every leader-prompt prayer has content after it.
  ///
  /// Check "(" rather than a Thai word because parenthesized lines mark chant
  /// instructions across editions. If no suitable line remains, fall back to the
  /// first line instead of leaving the row blank.
  static String _previewLine(List<String> lines) => lines.firstWhere(
    (line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('('),
    orElse: () => lines.first,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Preview shows the matching line when searching, so users see where the hit
    // occurred. If the query matches a leader prompt, show that exact line.
    final lines = prayer.text.split('\n');
    final preview = highlight.isEmpty
        ? _previewLine(lines)
        : lines.firstWhere(
            (line) => line.contains(highlight),
            orElse: () => _previewLine(lines),
          );
    final highlightColor = theme.colorScheme.secondaryContainer;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: order == null
                    ? Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer,
                      )
                    : Text(
                        '$order',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: _spans(
                          prayer.title,
                          theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          highlightColor,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: _spans(
                          preview,
                          theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          highlightColor,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
