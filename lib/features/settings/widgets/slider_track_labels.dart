import 'package:flutter/material.dart';

/// Small labels under a slider track, saying what its ends and middle mean.
class SliderTrackLabels extends StatelessWidget {
  const SliderTrackLabels({
    super.key,
    required this.start,
    required this.middle,
    required this.end,
  });

  final String start;
  final String middle;
  final String end;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      // Inset to the track, which Material starts a thumb-radius in.
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
      child: Row(
        children: [
          Text(start, style: style),
          Expanded(
            child: Center(child: Text(middle, style: style)),
          ),
          Text(end, style: style),
        ],
      ),
    );
  }
}
