import 'package:flutter/material.dart';

import 'app_asset_image.dart';

/// The pair of Thai floral corners that frames a screen header or foot.
///
/// Meant for `AppBar.flexibleSpace` or a `Positioned.fill`: it fills its box,
/// draws the artwork in two corners (the right one mirrored) and never
/// intercepts the controls underneath. Screens differ only in how large and
/// how present the corners are, so those stay parameters instead of a second
/// copy of the Stack.
///
/// There is no way to name an asset: which drawing belongs to which edge is
/// one decision, and a screen that spells it out again is a screen that can
/// drift from it. Each piece is drawn for the edge it sits on, so neither is
/// ever flipped vertically.
class FloralCorners extends StatelessWidget {
  /// The lotus-and-cloud piece drawn for the head of a page: the flower opens
  /// downwards into the screen.
  ///
  /// [size] defaults under the shortest bar that carries it, because an AppBar
  /// clips its `flexibleSpace` and this artwork ends in a vine tail that a
  /// clip cuts as a hard line across it.
  const FloralCorners.head({
    super.key,
    this.size = 110,
    this.top = 0,
    this.horizontal = 0,
    this.opacity = 0.7,
    this.darkOpacity = 0.25,
  }) : asset = headAsset,
       atFoot = false;

  /// The companion piece drawn for the foot of a page: the flower rises out of
  /// the bottom edge, with the cloud trailing along it.
  ///
  /// Fainter than the head by default — it sits behind a page's own content
  /// rather than inside a bar of its own.
  const FloralCorners.foot({
    super.key,
    this.size = 150,
    this.top = -5,
    this.horizontal = 0,
    this.opacity = 0.55,
    this.darkOpacity = 0.25,
  }) : asset = footAsset,
       atFoot = true;

  /// Artwork for [FloralCorners.head]; 3:2 is the foot's shape, this one is
  /// square, so `size` is its drawn size in both directions.
  static const headAsset =
      'assets/images/shared/golden_lotus_cloud_corner_ornament_top.png';

  /// Artwork for [FloralCorners.foot]. It is 3:2, so `BoxFit.contain` draws it
  /// [size] wide and two thirds as tall.
  static const footAsset =
      'assets/images/shared/golden_lotus_cloud_corner_ornament_bottom.png';

  /// Which artwork to draw, set by [FloralCorners.head] or [FloralCorners.foot].
  final String asset;

  /// Side of the square the artwork is drawn into.
  final double size;

  /// Distance from the top of the bar; negative lets the corner overhang.
  final double top;

  /// Distance from each side; negative lets the corner overhang.
  final double horizontal;

  /// Strength in a light theme.
  final double opacity;

  /// Strength in a dark theme, where the gold sits on a much darker ground.
  final double darkOpacity;

  /// Anchors the pair to the bottom of the box so it frames the foot of a
  /// page instead of its header. [top] is then measured from the bottom.
  final bool atFoot;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          // The offsets are allowed to be negative, so the corners must be
          // able to reach outside the bar.
          clipBehavior: Clip.none,
          children: [
            for (final right in [false, true])
              Positioned(
                top: atFoot ? null : top,
                bottom: atFoot ? top : null,
                left: right ? null : horizontal,
                right: right ? horizontal : null,
                child: Transform.flip(
                  flipX: right,
                  child: Opacity(
                    opacity: dark ? darkOpacity : opacity,
                    child: AppAssetImage(
                      asset,
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      // `contain` letterboxes an artwork that is not square,
                      // so align it with the edge it frames instead of
                      // leaving a gap between the corner and the page edge.
                      alignment: atFoot
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
