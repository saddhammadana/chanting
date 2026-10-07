import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/dashboard_tokens.dart';
import 'tap_target.dart';

/// Glyph and label colour on the gold face. The artwork sets it in white;
/// dark mode keeps a dark glyph because its gold is much lighter.
Color _goldenForeground(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColors.darkBackground
    : Colors.white;

/// Transparent button with a gold outline, from the home dashboard's "open
/// prayer" — the quieter partner of [GoldenPillButton] for actions that do not
/// start a sitting.
ButtonStyle goldOutlinedButtonStyle(ThemeData theme) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return OutlinedButton.styleFrom(
    foregroundColor: scheme.onSurface,
    minimumSize: const Size(128, 40),
    padding: const EdgeInsets.symmetric(horizontal: 22),
    side: BorderSide(
      color: dark
          ? scheme.secondary.withValues(alpha: 0.9)
          : DashboardTokens.outlineEdge,
      width: 1.3,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    // The artwork lets the card show through.
    backgroundColor: dark
        ? scheme.surface.withValues(alpha: 0.72)
        : Colors.transparent,
    textStyle: theme.textTheme.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// The artwork's raised gold pill: a warm face, a gold rim just inside its
/// edge, a white label, and a single warm shadow.
///
/// Shared by the home dashboard's "start chanting" and the meditation timer's
/// "start sitting", which the artwork draws the same way at different widths.
/// Gold is for starting something; other actions take
/// [goldOutlinedButtonStyle].
class GoldenPillButton extends StatelessWidget {
  const GoldenPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 40,
    this.width = 140,
    this.expand = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Drawn before the label, in the label's own colour.
  final Widget? icon;

  final double height;

  /// Ignored when [expand] is set.
  final double width;

  /// Fill the available width instead of using [width].
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = _goldenForeground(theme);

    return _GoldenFace(
      height: height,
      width: expand ? double.infinity : width,
      minWidth: expand ? null : width,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: icon!,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.32)
                        : AppColors.goldDark.withValues(alpha: 0.45),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [GoldenPillButton]'s face as a circle holding one glyph, for a floating
/// control too small to carry a label (the reader's auto-scroll toggle).
class GoldenIconButton extends StatelessWidget {
  const GoldenIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _GoldenFace(
      height: size,
      width: size,
      tooltip: tooltip,
      onPressed: onPressed,
      child: IconTheme.merge(
        data: IconThemeData(color: _goldenForeground(Theme.of(context))),
        child: icon,
      ),
    );
  }
}

/// Gold face, rim, halo and ripple shared by the golden buttons.
///
/// A 999 radius is a pill on a wide box and a circle on a square one, so both
/// buttons draw from the one decoration.
class _GoldenFace extends StatelessWidget {
  const _GoldenFace({
    required this.height,
    required this.width,
    required this.onPressed,
    required this.child,
    this.minWidth,
    this.tooltip,
    this.padding = EdgeInsets.zero,
  });

  final double height;
  final double width;
  final double? minWidth;
  final VoidCallback onPressed;

  /// For a face with a glyph and no label; see [TapTarget.tooltip].
  final String? tooltip;
  final EdgeInsets padding;
  final Widget child;

  static final _radius = BorderRadius.circular(999);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    // The artwork's face is 40 high, under the 48 a touch target wants, so the
    // face is painted at its own size inside a padded box.
    return TapTarget(
      stretch: width == double.infinity,
      tooltip: tooltip,
      child: Container(
        height: height,
        width: width,
        constraints: minWidth == null
            ? null
            : BoxConstraints(minWidth: minWidth!),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [AppColors.darkGold, AppColors.gold]
                : const [
                    DashboardTokens.goldFaceTop,
                    DashboardTokens.goldFaceBottom,
                  ],
          ),
          borderRadius: _radius,
          border: Border.all(
            color: dark ? AppColors.goldDark : DashboardTokens.goldEdge,
            width: 1.4,
          ),
          // The artwork lights this button with a warm halo only; a black
          // shadow under it greyed the cream card it sits on.
          boxShadow: [
            if (dark) ...[
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.20),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] else
              DashboardTokens.warmShadow(0.195, blur: 3.5, dy: 2),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: _radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: _radius,
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.42)
                      : DashboardTokens.goldRim.withValues(alpha: 0.9),
                  width: 1,
                ),
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
