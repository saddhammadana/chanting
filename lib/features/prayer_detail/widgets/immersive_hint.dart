import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Short hint shown when entering immersive mode; a direct child of the
/// reader's Stack.
class ImmersiveHint extends StatelessWidget {
  const ImmersiveHint({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: Center(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppLocalizations.of(context).immersiveHint,
                style: TextStyle(color: scheme.surface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
