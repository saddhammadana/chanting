import 'package:flutter/material.dart';

import '../../theme/dashboard_tokens.dart';
import 'tap_target.dart';

/// Diameter of [AppBackButton] and any control meant to sit the same height
/// next to it (e.g. a page's own search bar).
///
/// Smaller than the framework's default `IconButton` box (which lands at
/// 48px once its 48x48 minimum tap target wins over the 24px icon), because
/// at 48px a bare glyph reads as oversized against a page's own title.
const double appCircleButtonSize = 40;

/// Fill, [DashboardTokens.controlEdge] outline and [DashboardTokens.softShadows]
/// for a circular icon button on a page's AppBar.
///
/// Shared so every page's back button (and paired controls, like a search
/// button or an options menu) draws from one decision instead of several
/// that drift apart.
///
/// The shadow is painted by `backgroundBuilder`, inside the button's own
/// 40px face: a wrapper outside it would be sized by the padded 48px tap
/// target and cast a bigger circle than the one on screen. The face is
/// filled there too, because a `BoxShadow` darkens the box it sits under
/// unless the box is opaque — and edged there, since that opaque fill would
/// otherwise sit over the button's own `side`.
///
/// [fill] replaces the theme's surface for a bar that is not theme-coloured:
/// the reading screen paints its bar in the page colour.
ButtonStyle appCircleIconButtonStyle(ThemeData theme, {Color? fill}) =>
    IconButton.styleFrom(
      backgroundColor: fill ?? theme.colorScheme.surface,
      shape: const CircleBorder(),
      minimumSize: const Size.square(appCircleButtonSize),
      fixedSize: const Size.square(appCircleButtonSize),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ).copyWith(
      backgroundBuilder: (context, states, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill ?? theme.colorScheme.surface,
          border: Border.all(color: DashboardTokens.controlEdge(theme)),
          boxShadow: DashboardTokens.softShadows(theme),
        ),
        child: child,
      ),
    );

/// Width an `AppBar` must give its `leading` slot to hold [AppBackButton]:
/// the 16px start inset plus the button's 48px tap target.
const double appBackButtonLeadingWidth = 64;

/// Back arrow drawn as a circle in [appCircleIconButtonStyle]. Every page
/// that can be left uses this one, so "back" looks the same across the app.
///
/// It keeps [BackButton]'s behaviour — the platform icon and the "back"
/// semantics — so only the paint is ours. Not `BackButton` itself: its icon
/// cannot be replaced, and this was built to draw a chevron on every
/// platform rather than Android's boxed arrow.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fill, this.foreground});

  /// Face and glyph colours for a bar that does not follow the theme; see
  /// [appCircleIconButtonStyle]. Both default to the theme's own.
  final Color? fill;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      // AppBar's leading slot hands its child *tight* constraints — width
      // fixed by `leadingWidth`, height fixed to the toolbar height, not a
      // square. Without `Align`, `fixedSize` is powerless against a tight
      // constraint, and `CircleBorder` paints whatever box it is actually
      // given as an ellipse, not a circle — a taller, wider "circle" than
      // intended. `Align` keeps the tight outer box (so it still satisfies
      // the AppBar) but gives the button loose constraints, so it renders at
      // its own size.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: IconButton(
          key: const ValueKey('app_back_button'),
          icon: Icon(Icons.chevron_left, color: foreground),
          tooltip: l10n.backButtonTooltip,
          style: appCircleIconButtonStyle(theme, fill: fill),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

/// A labelled AppBar action in the same face as [AppBackButton]: the same
/// height, edge and shadow, stretched into a pill around its text. Every
/// text action in an AppBar uses this one, so "ข้าม" and "คืนค่า" cannot
/// drift apart the way two hand-built pills did.
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(appCircleButtonSize / 2);
    return Center(
      // Same height as the back button beside it, and the same padded tap
      // target the back button gets from `IconButton`.
      child: TapTarget(
        child: Container(
          height: appCircleButtonSize,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: radius,
            border: Border.all(color: DashboardTokens.controlEdge(theme)),
            boxShadow: DashboardTokens.softShadows(theme),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
