import 'package:flutter/material.dart';

import '../../../shared/widgets/content_width.dart';

/// Places the FAB at the content column's right edge, not the screen edge.
///
/// Normal `endFloat` hugs the screen edge. On desktop, that can be half a screen
/// away from the readable column ([ContentWidth.readingWidth]), making the button
/// look unrelated to the content. On narrow screens this falls back to endFloat by
/// choosing the smaller x value.
///
/// Limited to LTR. In RTL, FABs belong on the left, and clamping to the right
/// would move them the wrong way. The app currently supports only th/en, both LTR,
/// but keep the guard explicit.
const kContentEndFloat = ContentEndFloatFabLocation();

/// End-float position kept inside the centred content column. Use
/// [kContentEndFloat].
class ContentEndFloatFabLocation extends FloatingActionButtonLocation {
  const ContentEndFloatFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final base = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    if (geometry.textDirection != TextDirection.ltr) return base;
    final contentEnd =
        (geometry.scaffoldSize.width + ContentWidth.readingWidth) / 2;
    final x = contentEnd - geometry.floatingActionButtonSize.width;
    return Offset(x < base.dx ? x : base.dx, base.dy);
  }
}
