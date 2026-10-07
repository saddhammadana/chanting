import 'package:flutter/material.dart';

import '../../../shared/widgets/app_asset_image.dart';
import '../../../theme/app_colors.dart';

/// The picture-tile pickers the reading settings artwork uses.
///
/// Line spacing, text alignment and the page color are all "which of these
/// looks right" questions, and a row of labelled pictures answers that better
/// than a segmented control full of words — the tile *is* the preview.

/// One choice in a [TilePicker].
typedef TileOption<T> = ({T value, Widget picture, String label});

/// A row of labelled picture tiles, one of them selected.
///
/// The selected tile carries a gold rim and a check badge in its corner, which
/// is what the artwork uses to say "this one" without a radio dot.
class TilePicker<T> extends StatelessWidget {
  const TilePicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.tileHeight = 60,
    this.keyPrefix,
    this.inlineLabel = false,
  });

  final List<TileOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final double tileHeight;

  /// Widget-key prefix, so tests can name a tile rather than count them.
  final String? keyPrefix;

  /// Put the label inside the tile, beside its picture, instead of under it
  /// — for a picker given a full row, where tall narrow-picture tiles would
  /// leave most of each tile empty.
  final bool inlineLabel;

  /// The value's short name for the widget key.
  ///
  /// `'$value'` on an enum gives `ReadingBackground.sepia`, and a key holding
  /// the type name breaks the moment the enum is renamed for reasons that have
  /// nothing to do with the tile. The last dot-separated part is `sepia` for an
  /// enum and the value itself for a bool or an int.
  static String _suffix(Object? value) => '$value'.split('.').last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Tile(
                key: keyPrefix == null
                    ? null
                    : ValueKey('${keyPrefix}_${_suffix(option.value)}'),
                picture: option.picture,
                label: option.label,
                height: tileHeight,
                inlineLabel: inlineLabel,
                selected: option.value == selected,
                onTap: () => onSelected(option.value),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.picture,
    required this.label,
    required this.height,
    required this.selected,
    required this.onTap,
    this.inlineLabel = false,
  });

  final Widget picture;
  final String label;
  final double height;
  final bool inlineLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: selected ? scheme.secondary : scheme.onSurfaceVariant,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The badge overhangs the tile's corner, so the stack must not clip.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: height,
                  alignment: Alignment.center,
                  padding: inlineLabel
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : null,
                  decoration: BoxDecoration(
                    // A faint wash of the accent marks the choice as well as
                    // the rim, which reads better across a wide tile.
                    color: inlineLabel && selected
                        ? Color.alphaBlend(
                            scheme.secondary.withValues(alpha: 0.08),
                            scheme.surface,
                          )
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? scheme.secondary
                          : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: inlineLabel
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            picture,
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle,
                              ),
                            ),
                          ],
                        )
                      : picture,
                ),
                if (selected)
                  PositionedDirectional(
                    end: -6,
                    bottom: -6,
                    child: _CheckBadge(color: scheme.secondary),
                  ),
              ],
            ),
            if (!inlineLabel) ...[
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Ringed in the page colour so the badge reads as sitting on top of
        // the tile rather than being part of its border.
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
      child: Icon(
        Icons.check,
        size: 13,
        color: theme.brightness == Brightness.light
            ? Colors.white
            : theme.colorScheme.onPrimary,
      ),
    );
  }
}

/// Stacked rules showing how far apart the lines of a prayer will sit.
///
/// Drawn rather than taken from the icon font: the whole point is that the gap
/// differs between the three tiles, and no icon set has that as a family.
class LineSpacingGlyph extends StatelessWidget {
  const LineSpacingGlyph({super.key, required this.gap, this.lines = 4});

  final double gap;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Container(width: 34, height: 2, color: color),
        ],
      ],
    );
  }
}

/// Ragged rules showing left-aligned versus full-width justified text.
class TextAlignGlyph extends StatelessWidget {
  const TextAlignGlyph({super.key, required this.justify});

  final bool justify;

  /// Widths of the four rules. Justified text squares off every line but the
  /// last; left-aligned text leaves each one where it happens to end.
  static const _ragged = [34.0, 26.0, 31.0, 20.0];
  static const _justified = [34.0, 34.0, 34.0, 20.0];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    final widths = justify ? _justified : _ragged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widths.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Container(width: widths[i], height: 2, color: color),
        ],
      ],
    );
  }
}

/// A sheet of the paper a page color would give, with the lotus watermark on it.
class PageColorSwatch extends StatelessWidget {
  const PageColorSwatch({
    super.key,
    required this.color,
    required this.brightness,
  });

  final Color color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Opacity(
          // The night sheet needs a brighter mark to show at all.
          opacity: brightness == Brightness.dark ? 0.22 : 0.35,
          child: AppAssetImage(
            'assets/images/settings/minimal_beige_lotus_emblem.png',
            width: 70,
            color: brightness == Brightness.dark
                ? AppColors.darkGold
                : AppColors.watermarkGold,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
