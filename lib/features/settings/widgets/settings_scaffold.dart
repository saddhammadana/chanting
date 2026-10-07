import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/floral_corners.dart';
import '../../../theme/app_colors.dart';

export '../../../shared/widgets/app_back_button.dart';

/// Page frame shared by the settings hub and every settings sub-page.
///
/// Every page gets the warm cream ground. Only the hub carries the floral
/// corners at the head and the foot ([corners]); sub-pages stay plain so the
/// controls they hold are not framed by ornament.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.leading,
    this.corners = false,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  /// Replaces the plain back arrow. Pass [AppBackButton] for the app's
  /// shared circular back button; leave null for the framework default.
  final Widget? leading;

  /// Draws the floral corners at the head and the foot of the page.
  final bool corners;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Pulled tighter into the corners than the home screen's, because
        // this bar is a third as tall and clips what reaches past it.
        flexibleSpace: corners
            ? const FloralCorners.head(top: -13, horizontal: -8)
            : null,
        leading: leading,
        leadingWidth: leading == null ? null : 64,
        actions: actions,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          // Light only. The home screen lifts its dark ground towards the top
          // too, but there the header artwork sits over the join; on a settings
          // page the AppBar is flat `scaffoldBackgroundColor` and the lighter
          // top of the gradient met it as a visible band across the screen.
          color: theme.brightness == Brightness.dark
              ? theme.scaffoldBackgroundColor
              : null,
          gradient: theme.brightness == Brightness.dark
              ? null
              : const RadialGradient(
                  center: Alignment(0, -0.78),
                  radius: 1.15,
                  colors: [AppColors.creamLight, AppColors.cream],
                ),
        ),
        child: Stack(
          children: [
            // The foot ornament sits behind the list so a long page scrolls
            // over it instead of being cut short by it. It keeps the default
            // size and inset: the piece carries only ~1% of transparent
            // margin, so an overhang crops the bud's leaf and the cloud's tail
            // off screen rather than bleeding a decorative edge.
            if (corners) const Positioned.fill(child: FloralCorners.foot()),
            ContentWidth(
              // One column for every list page; see ContentWidth.gridWidth.
              maxWidth: ContentWidth.gridWidth,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
