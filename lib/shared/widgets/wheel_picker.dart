import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

const _kWheelItemExtent = 44.0;

/// The frame around one or more [WheelColumn]s: five rows tall, with a single
/// band behind the selected row of all of them.
class WheelPicker extends StatelessWidget {
  const WheelPicker({super.key, required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kWheelItemExtent * 5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: _kWheelItemExtent,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: columns),
        ],
      ),
    );
  }
}

/// One scrolling wheel of [labels]. Put the key on this widget's
/// [pickerKey] to reach the wheel's controller from a test.
class WheelColumn extends StatelessWidget {
  const WheelColumn({
    super.key,
    required this.pickerKey,
    required this.controller,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.looping = true,
    this.width = 76,
  });

  final Key pickerKey;
  final FixedExtentScrollController controller;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool looping;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: CupertinoPicker(
        key: pickerKey,
        scrollController: controller,
        itemExtent: _kWheelItemExtent,
        looping: looping,
        // WheelPicker draws one band behind every column instead.
        selectionOverlay: null,
        // A looping wheel reports indexes outside the list in both directions.
        onSelectedItemChanged: (i) => onChanged(i % labels.length),
        children: [
          for (final (i, label) in labels.indexed)
            Center(
              child: Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                  color: i == selected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
