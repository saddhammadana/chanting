import 'package:flutter/material.dart';

import '../../../shared/widgets/content_width.dart';
import '../../mala/mala_counter_overlay.dart';

/// Floating mala counter in the reader's bottom-right corner; a direct child
/// of the reader's Stack.
///
/// Counts live in malaController, so closing the panel does not reset them.
class MalaCounterLayer extends StatelessWidget {
  const MalaCounterLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        // Align the floating counter with the content column.
        child: ContentWidth(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 88),
              child: MalaCounterOverlay(onClose: onClose),
            ),
          ),
        ),
      ),
    );
  }
}
