import 'package:flutter/material.dart';

import '../../../shared/widgets/app_asset_image.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';

/// Pieces the home dashboard's cards are built from, shared between the
/// hero, the shortcut tiles and the cards below them.

/// Cream face, gold hairline and warm shadow of a home dashboard card.
BoxDecoration illuminatedCardDecoration(
  ThemeData theme, {
  double radius = 18,
  double glow = 0.16,
}) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [scheme.surface, scheme.secondaryContainer.withValues(alpha: 0.22)]
          : [
              AppColors.creamLight,
              AppColors.creamField.withValues(alpha: 0.58),
            ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark
          ? scheme.secondary.withValues(alpha: 0.34)
          : DashboardTokens.cardEdge,
    ),
    boxShadow: DashboardTokens.cardShadows(theme, glow: glow),
  );
}

/// A decorated card whose ink ripple is clipped to its rounded corners.
///
/// [inkKey] lands on the `InkWell`, which is what tests tap.
class DashboardInkCard extends StatelessWidget {
  const DashboardInkCard({
    super.key,
    required this.decoration,
    required this.radius,
    required this.onTap,
    required this.child,
    this.inkKey,
  });

  final BoxDecoration decoration;
  final double radius;
  final VoidCallback onTap;
  final Widget child;
  final Key? inkKey;

  @override
  Widget build(BuildContext context) => Container(
    decoration: decoration,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(key: inkKey, onTap: onTap, child: child),
    ),
  );
}

/// Heading above a dashboard group, with an optional "view all" action.
class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle(
    this.label, {
    super.key,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          // 16pt in the artwork, not Material's 22pt titleLarge.
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (actionLabel != null && onAction != null)
        TextButton(
          key: actionKey,
          onPressed: onAction,
          // The artwork sets this in the same ink as the heading beside it, not
          // in the brown accent a TextButton takes by default.
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel!),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
    ],
  );
}

/// Shortcut tile in the home grid: gold glyph over a label.
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return DashboardInkCard(
      radius: 18,
      onTap: onTap,
      // In the artwork these tiles sit flat on the page — a hairline and no
      // drop shadow.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  scheme.surface,
                  scheme.secondaryContainer.withValues(alpha: 0.2),
                ]
              : const [
                  DashboardTokens.tileFaceTop,
                  DashboardTokens.tileFaceBottom,
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? scheme.secondary.withValues(alpha: 0.34)
              : DashboardTokens.tileEdge,
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 12,
          // A pinned tile carries a count under a two-line label; the tighter
          // padding is what lets all three lines fit the tile's fixed height.
          vertical: compact ? (subtitle == null ? 8 : 5) : 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.04 : 0.62),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GoldenIcon(icon: icon, size: compact ? 31 : 34),
            SizedBox(height: compact ? 7 : 9),
            // Flexible, so a label that still does not fit is clipped inside
            // the tile instead of overflowing it.
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.12,
                  fontSize: compact ? 13.5 : null,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icon in the artwork's deeper gold, with room around it for the tile.
class GoldenIcon extends StatelessWidget {
  const GoldenIcon({super.key, required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size + 12,
      child: Center(
        child: Icon(
          icon,
          size: size,
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.secondary
              : DashboardTokens.goldGlyph,
        ),
      ),
    );
  }
}

/// Two fading gold rules either side of a small lotus.
///
/// Not the shared `OrnamentDivider`, which centres a diamond between plain
/// dividers.
class LotusDivider extends StatelessWidget {
  const LotusDivider({super.key, this.width = 150});

  final double width;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.secondary;
    Widget rule(List<Color> colors) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      ),
    );
    return SizedBox(
      width: width,
      child: Row(
        children: [
          rule([gold, gold.withValues(alpha: 0.18)]),
          const SizedBox(width: 8),
          const AppAssetImage(
            'assets/images/shared/lotus_emblem.png',
            width: 20,
            height: 18,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          rule([gold.withValues(alpha: 0.18), gold]),
        ],
      ),
    );
  }
}
