import 'package:flutter/material.dart';

/// Edge glow when swiping past the end; a direct child of the reader's Stack.
class EdgeGlow extends StatelessWidget {
  const EdgeGlow({super.key, required this.edge, required this.visible});

  /// -1 = left edge, 1 = right edge.
  final int edge;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Positioned(
      left: edge == -1 ? 0 : null,
      right: edge == 1 ? 0 : null,
      top: 0,
      bottom: 0,
      width: 32,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: edge == 1 ? Alignment.centerRight : Alignment.centerLeft,
                end: edge == 1 ? Alignment.centerLeft : Alignment.centerRight,
                colors: [
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
