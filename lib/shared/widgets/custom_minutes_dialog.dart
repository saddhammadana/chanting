import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'wheel_picker.dart';

/// Custom-duration dialog: a minutes wheel from 1 to [maxMinutes], or an
/// hours wheel beside a 0–59 minutes wheel when [withHours] is set.
///
/// Pops with the chosen minutes, or null when cancelled.
class CustomMinutesDialog extends StatefulWidget {
  const CustomMinutesDialog({
    super.key,
    required this.initialMinutes,
    this.maxMinutes = 180,
    this.title,
    this.withHours = false,
  });

  /// Where the wheels open; clamped into range.
  final int initialMinutes;

  /// Upper bound, and the number the hint quotes. Each caller has its own: a
  /// sitting may run three hours, a daily chanting goal may not.
  final int maxMinutes;

  /// Dialog heading; defaults to the meditation timer's wording, which is what
  /// this dialog was written for.
  final String? title;

  /// Splits the value over an hours and a minutes wheel. For durations long
  /// enough that nobody thinks of them as "150 minutes".
  final bool withHours;

  @override
  State<CustomMinutesDialog> createState() => _CustomMinutesDialogState();
}

class _CustomMinutesDialogState extends State<CustomMinutesDialog> {
  late int _minutes = widget.initialMinutes.clamp(1, widget.maxMinutes);

  late final _hoursCtl = FixedExtentScrollController(
    initialItem: _minutes ~/ 60,
  );
  late final _minutesCtl = FixedExtentScrollController(
    initialItem: widget.withHours ? _minutes % 60 : _minutes - 1,
  );

  @override
  void dispose() {
    _hoursCtl.dispose();
    _minutesCtl.dispose();
    super.dispose();
  }

  /// Two wheels can spell a duration outside the range (0:00, or minutes past
  /// [CustomMinutesDialog.maxMinutes]). Turn the minutes wheel back once a
  /// wheel comes to rest, so what is on screen is always what OK will return.
  bool _settle(ScrollEndNotification _) {
    final raw = _hoursCtl.selectedItem * 60 + _minutesCtl.selectedItem % 60;
    final fixed = raw.clamp(1, widget.maxMinutes);
    if (fixed != raw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _minutesCtl.animateToItem(
          fixed % 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
    return false;
  }

  Widget _wheels(AppLocalizations l10n) {
    final theme = Theme.of(context);
    Widget heading(String text) => SizedBox(
      width: 76,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    String pad(int n) => n.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            heading(l10n.durationHoursLabel),
            heading(l10n.durationMinutesLabel),
          ],
        ),
        NotificationListener<ScrollEndNotification>(
          onNotification: _settle,
          child: WheelPicker(
            columns: [
              WheelColumn(
                pickerKey: const ValueKey('hours_wheel'),
                controller: _hoursCtl,
                looping: false,
                labels: [
                  for (var h = 0; h <= widget.maxMinutes ~/ 60; h++) '$h',
                ],
                selected: _minutes ~/ 60,
                onChanged: (h) =>
                    setState(() => _minutes = h * 60 + _minutes % 60),
              ),
              WheelColumn(
                pickerKey: const ValueKey('minutes_wheel'),
                controller: _minutesCtl,
                labels: [for (var m = 0; m < 60; m++) pad(m)],
                selected: _minutes % 60,
                onChanged: (m) =>
                    setState(() => _minutes = _minutes ~/ 60 * 60 + m),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title ?? l10n.meditationCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.withHours)
            _wheels(l10n)
          else
            WheelPicker(
              columns: [
                WheelColumn(
                  pickerKey: const ValueKey('minutes_wheel'),
                  controller: _minutesCtl,
                  // A range with two ends reads better when it stops at them.
                  looping: false,
                  labels: [for (var m = 1; m <= widget.maxMinutes; m++) '$m'],
                  selected: _minutes - 1,
                  onChanged: (i) => setState(() => _minutes = i + 1),
                ),
              ],
            ),
          // With two wheels the range is the wheels themselves.
          if (!widget.withHours) ...[
            const SizedBox(height: 4),
            Text(
              l10n.meditationCustomHint(widget.maxMinutes),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          // Clamped again: OK can be pressed while a wheel is still turning.
          onPressed: () =>
              Navigator.of(context).pop(_minutes.clamp(1, widget.maxMinutes)),
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }
}
