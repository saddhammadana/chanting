import 'package:flutter/material.dart';

/// Pads a control out to a [kMinInteractiveDimension] touch area without
/// changing what it draws.
///
/// The artwork draws several controls smaller than a finger — the gold play
/// disc is 38px in a set's rows, the golden pill is 40 high — and Material
/// solves that for its own buttons by laying them out at 48 while painting the
/// smaller face inside (see [appCircleButtonSize], where the back button's 40px
/// circle sits in a 48px box). This does the same for the hand-built controls:
/// the child keeps its size and position inside the box, and the box is what a
/// tap, and `test/accessibility_test.dart`, measures.
///
/// [Semantics] with `container: true` is part of the deal, not decoration: the
/// inner `InkWell` reports its own smaller box to the accessibility guidelines
/// unless its semantics merge into a node that spans the padded area.
class TapTarget extends StatelessWidget {
  const TapTarget({
    super.key,
    required this.child,
    this.tooltip,
    this.stretch = false,
  });

  final Widget child;

  /// Long-press message, and the padded node's label with it. Passed here
  /// rather than wrapped around this widget: a `Tooltip` outside the node
  /// lands on its parent, leaving the control itself without a name.
  final String? tooltip;

  /// Let the child take all the width it is offered, for a control that is
  /// already as wide as its slot. The default shrink-wraps the width, which a
  /// child sized `double.infinity` cannot do.
  final bool stretch;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kMinInteractiveDimension,
        minHeight: kMinInteractiveDimension,
      ),
      // Align, not SizedBox: the minimum must not be passed down as a tight
      // constraint, or the face it pads would stretch to fill it.
      child: Align(
        alignment: Alignment.center,
        heightFactor: 1,
        widthFactor: stretch ? null : 1,
        child: tooltip == null
            ? child
            : Tooltip(message: tooltip!, child: child),
      ),
    ),
  );
}
