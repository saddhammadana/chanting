import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/dashboard_tokens.dart';
import '../share_page_parts.dart';
import 'edit_decorations.dart';

/// Folder tabs, as the artwork draws them: the selected tab is the top of
/// the panel below it and flares into it at its foot, the other sits behind
/// it in soft gold, a little lower, tucked under its edge.
class EditTabs extends StatelessWidget {
  const EditTabs({
    super.key,
    required this.onSelected,
    required this.selectedCount,
    required this.onChanged,
  });

  final bool onSelected;
  final int selectedCount;
  final ValueChanged<bool> onChanged;

  static const _radius = 18.0;
  static const _drop = 6.0;
  static const _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final panel = editPanelColor(theme);
    // The choose tab is on the left.
    final leftSelected = !onSelected;

    Widget label(String text, bool selected) => IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          // As wide as the label, growing out from its centre. Scaled
          // rather than sized: IntrinsicWidth measures this column, and a
          // fractional box at factor 0 has no intrinsic width to report.
          TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? 1 : 0),
            duration: _duration,
            curve: Curves.easeOut,
            builder: (context, t, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(t, 1, 1),
              child: child,
            ),
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: shareGold(theme),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );

    Widget tab({
      required Key key,
      required String text,
      required bool selected,
      required bool value,
      required BorderRadius radius,
      EdgeInsets inset = EdgeInsets.zero,
    }) => Semantics(
      selected: selected,
      button: true,
      child: ConstrainedBox(
        // The tab behind is drawn [_drop] lower than the selected one, so the
        // band has to be that much taller than 48 for the shorter of the two
        // to still be a touch target. Set on the tab rather than the band: the
        // selected tab is what the Stack measures.
        constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimension + _drop,
        ),
        child: Material(
          key: key,
          color: selected ? panel : editBeige(theme),
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onChanged(value),
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(
                    8,
                    // The tab behind is [_drop] shorter, so the same content
                    // must fit in that much less.
                    selected ? 12 : 12 - _drop,
                    8,
                    8,
                  ) +
                  inset,
              child: Center(child: label(text, selected)),
            ),
          ),
        ),
      ),
    );

    final choose = l10n.playlistTabChoose;
    final chosen = l10n.playlistTabSelected(selectedCount);
    const round = Radius.circular(_radius);

    return LayoutBuilder(
      builder: (context, box) {
        final half = box.maxWidth / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The tab behind reaches under the selected one, so its inner
            // edge is hidden and only its outer corner is rounded.
            Positioned(
              top: _drop,
              bottom: 0,
              left: leftSelected ? half - _radius : 0,
              right: leftSelected ? 0 : half - _radius,
              child: tab(
                key: ValueKey(
                  leftSelected ? 'edit_tab_selected' : 'edit_tab_choose',
                ),
                text: leftSelected ? chosen : choose,
                selected: false,
                value: leftSelected,
                radius: BorderRadius.only(
                  topLeft: leftSelected ? Radius.zero : round,
                  topRight: leftSelected ? round : Radius.zero,
                ),
                inset: leftSelected
                    ? const EdgeInsets.only(left: _radius)
                    : const EdgeInsets.only(right: _radius),
              ),
            ),
            // The selected tab's shape — flare included — filled in the
            // panel's colour over its soft shadow, which falls on the tab
            // behind. The tab itself is drawn on top in the same colour.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TabShapePainter(
                    color: panel,
                    shadow: DashboardTokens.softShadowColor(theme),
                    leftSelected: leftSelected,
                    radius: _radius,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                if (!leftSelected) const Spacer(),
                Expanded(
                  child: tab(
                    key: ValueKey(
                      leftSelected ? 'edit_tab_choose' : 'edit_tab_selected',
                    ),
                    text: leftSelected ? choose : chosen,
                    selected: true,
                    value: !leftSelected,
                    radius: const BorderRadius.vertical(top: round),
                  ),
                ),
                if (leftSelected) const Spacer(),
              ],
            ),
            // Bridges the seam where the band ends and the panel begins
            // under the selected tab and its flare, so no hairline of
            // anti-aliasing or of the panel's own shadow shows between.
            Positioned(
              bottom: -1,
              height: 1.5,
              left: leftSelected ? 0 : half - _radius,
              right: leftSelected ? half - _radius : 0,
              child: ColoredBox(color: panel),
            ),
            // Drawn after the bridge above, which would otherwise cut the
            // line's tail where it joins the panel's top border.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TabLinePainter(
                    color: editPanelLine(theme),
                    leftSelected: leftSelected,
                    radius: _radius,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The selected tab's outline, on the same geometry as [_TabShapePainter]
/// but half a pixel inside it, as the panel's [Border] sits inside the
/// panel: so it runs straight into the panel's side border at the outer
/// edge and, through the flare, into its top border at the inner one.
class _TabLinePainter extends CustomPainter {
  const _TabLinePainter({
    required this.color,
    required this.leftSelected,
    required this.radius,
  });

  final Color color;
  final bool leftSelected;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const e = 0.5;
    final w = size.width;
    final h = size.height;
    final half = w / 2;
    final r = radius;
    final path = Path()
      ..moveTo(e, h + 1)
      ..lineTo(e, r)
      ..arcToPoint(Offset(r, e), radius: Radius.circular(r - e))
      ..lineTo(half - r, e)
      ..arcToPoint(Offset(half - e, r), radius: Radius.circular(r - e))
      ..lineTo(half - e, h - r)
      ..arcToPoint(
        Offset(half + r, h + e),
        radius: Radius.circular(r + e),
        clockwise: false,
      );
    canvas.save();
    if (!leftSelected) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabLinePainter old) =>
      old.color != color ||
      old.leftSelected != leftSelected ||
      old.radius != radius;
}

/// The selected tab as one shape — its left half of the band (mirrored when
/// it is on the right) with rounded top corners and a circular flare into
/// the panel at the inner foot — painted as a blurred shadow, then filled.
/// Nothing is drawn below the band, so the shadow never lies across the
/// panel the tab opens into.
class _TabShapePainter extends CustomPainter {
  const _TabShapePainter({
    required this.color,
    required this.shadow,
    required this.leftSelected,
    required this.radius,
  });

  final Color color;
  final Color shadow;
  final bool leftSelected;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final half = w / 2;
    final r = radius;
    // Runs on below the band so the blur has no edge there; the clip below
    // cuts it at the band's foot.
    const below = 24.0;
    final path = Path()
      ..moveTo(0, h + below)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(half - r, 0)
      ..arcToPoint(Offset(half, r), radius: Radius.circular(r))
      ..lineTo(half, h - r)
      ..arcToPoint(
        Offset(half + r, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(half + r, h + below)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-below, -below, w + below, h));
    if (!leftSelected) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      path.shift(const Offset(0, -1)),
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          Shadow.convertRadiusToSigma(DashboardTokens.softShadowBlur),
        ),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabShapePainter old) =>
      old.color != color ||
      old.shadow != shadow ||
      old.leftSelected != leftSelected ||
      old.radius != radius;
}
