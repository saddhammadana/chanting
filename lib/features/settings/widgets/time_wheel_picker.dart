import 'package:flutter/material.dart';

import '../../../shared/widgets/wheel_picker.dart';

/// Asks for a time of day on two scrolling wheels.
///
/// Replaces Material's clock face, which is hard to aim at: its 24-hour dial
/// packs two rings of numbers into one circle. Pops with the chosen time, or
/// null when cancelled.
Future<TimeOfDay?> showTimeWheelPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) => showDialog<TimeOfDay>(
  context: context,
  builder: (context) =>
      _TimeWheelDialog(initialTime: initialTime, title: title),
);

class _TimeWheelDialog extends StatefulWidget {
  const _TimeWheelDialog({required this.initialTime, required this.title});

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_TimeWheelDialog> createState() => _TimeWheelDialogState();
}

class _TimeWheelDialogState extends State<_TimeWheelDialog> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  // Created on first build, because the hour wheel's starting item depends on
  // whether the clock is 12- or 24-hour, which only the context can say.
  FixedExtentScrollController? _hourCtl;
  late final _minuteCtl = FixedExtentScrollController(initialItem: _minute);
  late final _periodCtl = FixedExtentScrollController(
    initialItem: _hour < 12 ? 0 : 1,
  );

  @override
  void dispose() {
    _hourCtl?.dispose();
    _minuteCtl.dispose();
    _periodCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String pad(int n) => n.toString().padLeft(2, '0');

    final hourCtl = _hourCtl ??= FixedExtentScrollController(
      initialItem: use24 ? _hour : _hour % 12,
    );

    return AlertDialog(
      title: Text(widget.title),
      content: WheelPicker(
        columns: [
          WheelColumn(
            pickerKey: const ValueKey('time_wheel_hour'),
            controller: hourCtl,
            labels: use24
                ? [for (var h = 0; h < 24; h++) pad(h)]
                : [for (var h = 0; h < 12; h++) '${h == 0 ? 12 : h}'],
            selected: use24 ? _hour : _hour % 12,
            onChanged: (i) =>
                setState(() => _hour = use24 ? i : i + (_hour < 12 ? 0 : 12)),
          ),
          WheelColumn(
            pickerKey: const ValueKey('time_wheel_minute'),
            controller: _minuteCtl,
            labels: [for (var m = 0; m < 60; m++) pad(m)],
            selected: _minute,
            onChanged: (i) => setState(() => _minute = i),
          ),
          if (!use24)
            WheelColumn(
              pickerKey: const ValueKey('time_wheel_period'),
              controller: _periodCtl,
              looping: false,
              labels: [
                materialL10n.anteMeridiemAbbreviation,
                materialL10n.postMeridiemAbbreviation,
              ],
              selected: _hour < 12 ? 0 : 1,
              onChanged: (i) => setState(() => _hour = _hour % 12 + i * 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(TimeOfDay(hour: _hour, minute: _minute)),
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }
}
