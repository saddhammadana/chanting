import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative divider: thin lines on both sides with a small gold diamond center.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.secondary;
    return Row(
      children: [
        const Expanded(child: Divider(endIndent: 12)),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        const Expanded(child: Divider(indent: 12)),
      ],
    );
  }
}
