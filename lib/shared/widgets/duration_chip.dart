import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/dashboard_tokens.dart';

/// Duration preset drawn as the artwork draws it: a flat cream card that fills
/// with the gold face when chosen, a pale rim line running just inside its
/// edge.
class DurationChip extends StatelessWidget {
  const DurationChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      // The card is 50 high but the `InkWell` inside it is only as big as the
      // card minus its border, which a selected chip draws at 1.6 — under the
      // 48 a touch target wants. A node around the card is what the
      // guidelines then measure, and it announces the chip as a button.
      child: Semantics(
        container: true,
        button: true,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? (dark
                        ? [AppColors.darkGold, AppColors.gold]
                        : const [
                            DashboardTokens.chipFaceTop,
                            DashboardTokens.chipFaceBottom,
                          ])
                  : (dark
                        ? [scheme.surface, scheme.surface]
                        : const [
                            DashboardTokens.tileFaceTop,
                            DashboardTokens.tileFaceBottom,
                          ]),
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? (dark ? AppColors.goldDark : DashboardTokens.chipEdge)
                  : (dark
                        ? scheme.secondary.withValues(alpha: 0.34)
                        : DashboardTokens.tileEdge),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [DashboardTokens.warmShadow(0.15, blur: 3, dy: 2)]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Stacked behind the label rather than wrapped around it, so
                  // choosing a chip does not move its text.
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.all(1.2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11.2),
                          border: Border.all(
                            color: dark
                                ? DashboardTokens.goldRim.withValues(alpha: 0.7)
                                : DashboardTokens.chipRim,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? (dark
                                      ? AppColors.darkBackground
                                      : Colors.white)
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
