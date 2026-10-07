import 'package:flutter/material.dart';

import '../../../shared/widgets/gold_sparkle.dart';

/// Ornament shared by the meditation timer's two rings — the setup one
/// and the one a sitting runs on.

/// One duration for every fade a sitting makes — controls, ornament, ground.
const kMeditationFade = Duration(milliseconds: 420);

/// Fades the lotus-cloud ornaments flanking the timer ring.
///
/// The reference artwork does not set these at one strength: the lotus is drawn
/// in saturated amber and the cloud scroll-work radiating out of it falls away
/// until the outermost spirals are barely there, so the flower reads as rising
/// out of mist. A uniform `Opacity` cannot express that — turned down the lotus
/// disappears with the scrolls, turned up the scrolls shout as loudly as the
/// lotus and the ornament reads as a stamp. So the strength is a radial ramp
/// anchored on the flower instead.
///
/// The right-hand ornament wraps this in `Transform.flip`, which mirrors the
/// ramp with it and gives the pair the artwork's symmetry for free.
class LotusTonalFade extends StatelessWidget {
  const LotusTonalFade({super.key, required this.child});

  final Widget child;

  /// Centre of the lotus within `meditation_lotus_cloud.png`, in its own
  /// bounds — the ramp is anchored here, not at the image's centre.
  static const _lotusCentre = Alignment(-0.31, 0.18);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Peak sits on the flower; the edge stop keeps the far scrolls faintly
    // present rather than cutting them off.
    final peak = dark ? 0.42 : 0.80;
    final mid = dark ? 0.24 : 0.45;
    final edge = dark ? 0.05 : 0.10;

    return ShaderMask(
      // Multiplies the artwork's own alpha by the ramp's.
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => RadialGradient(
        center: _lotusCentre,
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: peak),
          Colors.white.withValues(alpha: mid),
          Colors.white.withValues(alpha: edge),
        ],
        stops: const [0.20, 0.55, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// The sparkles flanking the ring: three a side, mirrored, each a different
/// size.
///
/// Both heroes used to place them one Positioned at a time, which is how the
/// setup ring ended up with one star on the left and two on the right. Here
/// the placement is a list and each entry is drawn on both sides, so a star
/// cannot exist on one side only.
///
/// Every value is a fraction of the ring's diameter, like the rest of this
/// screen. The lowest star's bottom edge lands at 0.582 of the way down and
/// the lotus clouds start at 0.77 in both heroes, so nothing overlaps them;
/// the insets keep the stars clear of the ring's glow as well.
class TimerSparkles extends StatelessWidget {
  const TimerSparkles({super.key, required this.size, this.visible = true});

  /// The ring's diameter. Every offset below is a fraction of it.
  final double size;

  /// Fades with the rest of the ornament while a sitting settles.
  final bool visible;

  /// Inset from the box's own side, distance from the top, and the star's own
  /// size. Ordered large to small so the trio reads as scattered rather than
  /// as a row.
  static const _stars = [
    (inset: 0.085, top: 0.13, star: 0.105),
    (inset: 0.020, top: 0.33, star: 0.075),
    (inset: 0.075, top: 0.53, star: 0.052),
  ];

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: kMeditationFade,
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in _stars)
              for (final right in [false, true])
                Positioned(
                  left: right ? null : size * s.inset,
                  right: right ? size * s.inset : null,
                  top: size * s.top,
                  child: GoldSparkle(size: size * s.star),
                ),
          ],
        ),
      ),
    ),
  );
}
