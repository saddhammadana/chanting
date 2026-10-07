import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/dashboard_tokens.dart';
import 'tap_target.dart';

/// The home screen's "continue chanting" play disc: a flat gold face inside a
/// white ring, one warm shadow.
///
/// Every "start chanting from here" control draws this, so the home card, the
/// prayer-set list and a prayer set's own page read as the same action. With
/// no [onPressed] it is only a mark, for a card that is itself the button.
class GoldPlayButton extends StatelessWidget {
  const GoldPlayButton({
    super.key,
    this.size = 50,
    this.tooltip,
    this.onPressed,
  });

  final double size;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.playDiscTop, AppColors.playDiscBottom],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [DashboardTokens.warmShadow(0.17, blur: 2.5, dy: 1.5)],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            Icons.play_arrow_rounded,
            // White glyph on the gold face, as in the artwork.
            color: dark ? AppColors.darkBackground : Colors.white,
            size: size * 0.6,
          ),
        ),
      ),
    );
    if (onPressed == null) return disc;
    // The artwork draws this disc at 38 in a set's rows; the box around it is
    // what a finger gets.
    return TapTarget(tooltip: tooltip, child: disc);
  }
}
