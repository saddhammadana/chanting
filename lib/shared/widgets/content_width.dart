import 'package:flutter/material.dart';

/// Caps content width on wide screens and centers it.
///
/// Long text becomes uncomfortable if it stretches across a tablet or desktop
/// viewport. List/settings pages can wrap the whole scrollable; the reader wraps
/// inside the scrollable so the scroll area still spans the screen for edge
/// gestures. See `prayer_detail_screen`.
///
/// The reader bottom bar must also use this wrapper. If only the content is capped,
/// the progress bar stretches across the full screen while the text column stays
/// narrow, making the position label visually detach from the content.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = readingWidth,
    this.fillHeight = true,
  });

  /// Width based on comfortable long-form reading line length at normal text size.
  static const readingWidth = 700.0;

  /// Width for grid/card pages rather than long-form text.
  ///
  /// Every page that is a list of cards or rows uses this, pushed pages
  /// included, so moving between tabs or into a category does not change the
  /// column under the user. The exceptions are the reader ([readingWidth]) and
  /// the single-composition pages ([composedWidth]).
  ///
  /// The home screen uses this because Material 3 `SearchBar` is already 800 px
  /// wide, so the grid and search field align cleanly.
  static const gridWidth = 800.0;

  /// Width for a page whose layout is a single centred composition rather than
  /// a column of full-width rows.
  ///
  /// The meditation timer needs it: its ring is capped at 300 px so it cannot
  /// swallow a tablet column, but in a 700 px column that leaves the ring and
  /// the lotus ornaments flanking it as a small island while the option rows
  /// below stretch the full width — the two halves of the screen stop reading
  /// as one design. Holding the page near phone width keeps the proportions the
  /// artwork was drawn at.
  static const composedWidth = 440.0;

  /// Width cap for this page. Defaults to [readingWidth].
  final double maxWidth;

  /// Whether to fill the incoming height.
  ///
  /// Set this to `false` for children that should be only as tall as their content,
  /// such as `bottomNavigationBar`. Inside scrollables the max height is infinite
  /// and `Align` shrink-wraps naturally; bounded parents such as Scaffold bottom
  /// slots would otherwise make this wrapper fill the whole screen and intercept
  /// taps.
  final bool fillHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `Alignment.center` preserves Center behavior when fillHeight is true. With
    // heightFactor = 1 the box is child-height, so vertical alignment is irrelevant.
    return Align(
      alignment: Alignment.center,
      heightFactor: fillHeight ? null : 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
