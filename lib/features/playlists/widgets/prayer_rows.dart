import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../playlist_detail_screen.dart' show PrayerMinutes;
import 'edit_decorations.dart';
import 'marked_spans.dart';

/// A small soft-gold tag: the prayer's category.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: editBeige(theme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Length (when known) and category under a prayer's title.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.minutes, required this.tag});

  final int? minutes;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    if (minutes == null && tag == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (minutes != null) ...[
            PrayerMinutes(minutes: minutes!),
            const SizedBox(width: 10),
          ],
          if (tag != null) Flexible(child: _Tag(tag!)),
        ],
      ),
    );
  }
}

Color _rowColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColors.darkBackground.withValues(alpha: 0.45)
    : Colors.white;

/// A row's face inside the panel: white with a faint hairline, or washed
/// with pale gold once the prayer is in the set, so a long list shows what
/// has been picked without reading every button.
BoxDecoration _rowDecoration(ThemeData theme, {bool selected = false}) {
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: !selected
        ? _rowColor(theme)
        : dark
        ? AppColors.darkGoldSoft.withValues(alpha: 0.55)
        : Color.alphaBlend(
            AppColors.goldSoft.withValues(alpha: 0.4),
            Colors.white,
          ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: !selected
          ? (dark ? AppColors.darkBorder : AppColors.rowEdge)
          : (dark ? AppColors.darkGold : AppColors.creamBorder).withValues(
              alpha: 0.5,
            ),
    ),
  );
}

TextStyle? _rowTitle(ThemeData theme) => theme.textTheme.titleMedium?.copyWith(
  fontWeight: FontWeight.w700,
  color: theme.colorScheme.primary,
);

Color _gold(ThemeData theme) =>
    theme.brightness == Brightness.dark ? AppColors.darkGold : AppColors.gold;

/// The round + / ✓ / − at the end of a row. One recipe in any colour — a
/// pale disc, a fine rim and a full-strength glyph — so the gold add and the
/// red remove weigh the same on either tab and differ only in hue.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: color,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        fixedSize: const Size.square(_size),
        minimumSize: const Size.square(_size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: onPressed,
    );
  }
}

/// A prayer on the choose tab: gold + to add it, a gold tick once added.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.prayer,
    required this.tag,
    required this.selected,
    required this.onToggle,
    this.highlight = '',
  });

  final Prayer prayer;
  final String? tag;
  final bool selected;
  final VoidCallback onToggle;

  /// The search box's text, marked in the title the way the all-prayers
  /// list marks it; empty marks nothing.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final description = prayer.description;
    return DecoratedBox(
      decoration: _rowDecoration(theme, selected: selected),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: markedSpans(
                            prayer.title,
                            highlight,
                            _rowTitle(theme),
                            theme.colorScheme.secondaryContainer,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description != null && description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      _MetaLine(minutes: prayer.durationMinutes, tag: tag),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RowAction(
                  icon: selected ? Icons.check_rounded : Icons.add_rounded,
                  color: _gold(theme),
                  tooltip: selected
                      ? l10n.playlistRemovePrayer
                      : l10n.playlistAddToSet,
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A chosen prayer: the handle and its place leading, then title and tags,
/// with the remove at the far end. The handle is the same glyph as the hint
/// above the list, so the two read as one instruction.
class SelectedRow extends StatelessWidget {
  const SelectedRow({
    super.key,
    required this.index,
    required this.title,
    required this.minutes,
    required this.tag,
    required this.onRemove,
  });

  final int index;
  final String title;
  final int? minutes;
  final String? tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: _rowDecoration(theme),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 10, 14, 10),
      child: Row(
        children: [
          ReorderableDragStartListener(
            key: const ValueKey('selected_drag_handle'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.drag_indicator,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _rowTitle(theme),
                ),
                _MetaLine(minutes: minutes, tag: tag),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _RowAction(
            icon: Icons.remove_rounded,
            color: scheme.error,
            tooltip: l10n.playlistRemovePrayer,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
