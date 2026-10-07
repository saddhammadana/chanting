import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'app_asset_image.dart';
import 'spotlight_tour.dart';

// Values sampled from the navigation-bar reference artwork. The
// bar is its own warm cream, a shade deeper than the page behind it, and the
// start button is three concentric circles: a dark gold rim, a bright gold
// hairline, then the gradient disc.
const _navBarLight = AppColors.navBar;
const _navBorderLight = AppColors.navBorder;
const _navRestLight = AppColors.navRest;
const _navActiveIcon = AppColors.navActiveIcon;
const _navActiveLabel = AppColors.navActiveLabel;

const _startDiameter = 80.0;
const _startRimWidth = 2.5;
const _startHaloWidth = 2.5;

/// How far the start button is pushed below the docked position, so it sits
/// mostly inside the bar instead of half above it. Keep
/// `_startDrop + _startDiameter / 2` at or under [_navBarHeight] so the disc
/// never hangs below the bar.
const _startDrop = 22.0;

const _navBarHeight = 66.0;

/// How far the start button reaches above the top of the bar.
const _startRise = _startDiameter / 2 - _startDrop;
const _navIconSize = 29.0;

/// Persistent navigation for the five primary app destinations.
///
/// Reading and editing routes intentionally live outside this shell so chanting
/// remains immersive and focused.
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int get _selectedIndex => switch (location) {
    '/' => 0,
    '/all' => 1,
    '/start' => 2,
    '/playlists' => 3,
    '/settings' => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // A SnackBar raised by a page outside the shell (the set editor, a set's
    // page) lives in the root messenger and is still showing when that page
    // pops back here, where this Scaffold lays it out. Fixed, it sat on the bar
    // and the Scaffold lifted the start button off the bar to sit above it.
    // Floating, the button stays put and the SnackBar clears it.
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
        ),
      ),
      child: _scaffold(context, theme, l10n),
    );
  }

  Widget _scaffold(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final light = theme.brightness == Brightness.light;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final barColor = light ? _navBarLight : AppColors.darkSurface;
    final borderColor = light ? _navBorderLight : AppColors.darkBorder;

    return Scaffold(
      // Pages inside the shell get their own messenger so a SnackBar is laid
      // out by the page's Scaffold, which knows the page's FAB. Left to the
      // shell's root messenger it sat flush on the bar, over the start button
      // and over any page FAB. Floating, with room for the part of the start
      // button that rises above the bar.
      body: Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(
            behavior: SnackBarBehavior.floating,
            insetPadding: const EdgeInsets.fromLTRB(15, 5, 15, 10 + _startRise),
          ),
        ),
        child: ScaffoldMessenger(child: child),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // The keyboard covers the bar but a Scaffold lifts its FAB above the
      // keyboard, which left the start button floating over the page alone.
      // Hidden rather than removed: a Scaffold animates a FAB in and out when
      // it comes and goes, and the bar it belongs to does no such thing.
      floatingActionButton: Visibility(
        visible: !keyboardOpen,
        child: Transform.translate(
          offset: const Offset(0, _startDrop),
          child: Semantics(
            button: true,
            selected: _selectedIndex == 2,
            label: l10n.navStart,
            child: _StartButton(
              key: tourStartButtonKey,
              label: l10n.navStart,
              onTap: () => context.go('/start'),
            ),
          ),
        ),
      ),
      // Plain: one flat strip across the screen with a single hairline on
      // top — no frame, shadow or shape to compete with the start button.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: _navBarHeight + bottomInset,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: _NavDestination(
                      key: const ValueKey('nav_home'),
                      icon: CupertinoIcons.house,
                      selectedIcon: CupertinoIcons.house_fill,
                      label: l10n.navHome,
                      selected: _selectedIndex == 0,
                      onTap: () => context.go('/'),
                    ),
                  ),
                  Expanded(
                    child: _NavDestination(
                      key: const ValueKey('nav_prayers'),
                      icon: CupertinoIcons.book,
                      selectedIcon: CupertinoIcons.book_fill,
                      label: l10n.navPrayers,
                      selected: _selectedIndex == 1,
                      onTap: () => context.go('/all'),
                    ),
                  ),
                  const SizedBox(width: 90),
                  Expanded(
                    child: _NavDestination(
                      key: const ValueKey('nav_library'),
                      icon: CupertinoIcons.folder,
                      selectedIcon: CupertinoIcons.folder_fill,
                      label: l10n.navLibrary,
                      selected: _selectedIndex == 3,
                      onTap: () => context.go('/playlists'),
                    ),
                  ),
                  Expanded(
                    child: _NavDestination(
                      key: const ValueKey('nav_settings'),
                      icon: CupertinoIcons.gear_alt,
                      selectedIcon: CupertinoIcons.gear_alt_fill,
                      label: l10n.navSettings,
                      selected: _selectedIndex == 4,
                      onTap: () => context.go('/settings'),
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

class _StartButton extends StatelessWidget {
  const _StartButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.square(
      dimension: _startDiameter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Rim, halo, disc — drawn as nested circles rather than borders so
          // each ring keeps its own gradient.
          DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navStartRimTop, AppColors.navStartRimBottom],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navStartShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_startRimWidth),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.navStartHaloTop,
                      AppColors.navStartHaloBottom,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_startHaloWidth),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.navStartDiscTop,
                          AppColors.navStartDiscBottom,
                        ],
                      ),
                    ),
                    child: ExcludeSemantics(
                      // Sized to sit well inside the disc: the label is the
                      // widest thing in it and rides low, where the circle
                      // narrows, so a larger lotus pushed it against the rim.
                      // Lifted a touch for the same reason.
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppAssetImage(
                              'assets/images/shared/lotus_white_outline.png',
                              width: 33,
                              height: 25,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.15,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The ripple rides on top so it is not hidden by the rings.
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(key: const ValueKey('nav_start'), onTap: onTap),
          ),
        ],
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    // The reference art keeps the resting state a deep warm brown, not the
    // scheme's neutral variant, which reads grey against the cream bar.
    final restColor = light ? _navRestLight : AppColors.darkCream;
    final iconColor = selected
        ? (light ? _navActiveIcon : AppColors.darkGold)
        : restColor;
    final labelColor = selected
        ? (light ? _navActiveLabel : AppColors.darkGold)
        : restColor;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: ExcludeSemantics(
          // Material icons carry padding inside their box that the reference
          // art does not, so the pair is nudged up off centre to land where the
          // drawing puts it.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cupertino's glyphs: a hairline stroke, where Material's
                // outlined set draws ~2px and `weight` has no effect on it
                // (the Material Icons font is not variable).
                Icon(
                  selected ? selectedIcon : icon,
                  color: iconColor,
                  size: _navIconSize,
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    fontSize: 11,
                    height: 1.15,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
