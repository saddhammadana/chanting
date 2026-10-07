import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_asset_image.dart';

/// The artwork's progress ring: a gold band with a glow around it, a deeper
/// gold arc for [progress], and a lotus straddling the top edge.
///
/// Every measurement is a fraction of the diameter, so the ring keeps its look
/// at whatever width its column gives it. Used by the home dashboard's daily
/// goal and by the meditation timer.
class GoldRing extends StatelessWidget {
  const GoldRing({
    super.key,
    required this.size,
    required this.progress,
    required this.child,
    this.showLotus = true,
    this.illuminated = false,
  });

  /// Outer diameter.
  final double size;

  /// 0..1; no arc is drawn at 0.
  final double progress;

  /// Sits inside the ring, centred, and is rendered without text scaling; see
  /// [build].
  final Widget child;

  final bool showLotus;

  /// Adds the polished edge: a sheen along the band's two rims and a hairline
  /// on each. The glow is not part of this — every ring gets that, because a
  /// ring that does not glow is not this ring.
  final bool illuminated;

  static const _band = 0.0645;
  static const _lotusWidth = 0.31;
  static const _lotusHeight = 0.255;

  /// Band thickness for a ring of [size], for callers laying out the inside.
  static double bandFor(double size) => size * _band;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final band = size * _band;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GoldRingPainter(
              progress: progress.clamp(0.0, 1.0),
              band: band,
              illuminated: illuminated,
              // The band is a gold ring you can see, not a hint of one. It
              // still reads under the arc because the arc is the saturated
              // colour and this is the same hue held back.
              track: scheme.secondary.withValues(alpha: dark ? 0.46 : 0.42),
              // Warm, never white. The ground is `AppColors.cream` (#FFF9EE)
              // and pure white against it differs by 17/255 on one channel —
              // a glow nobody can see. The light comes from the blur.
              glow: dark
                  ? AppColors.darkGold.withValues(alpha: 0.34)
                  : AppColors.gold.withValues(alpha: 0.38),
              // A highlight on gold is paler gold, never white. This used
              // to be `Colors.white` and got away with it only because the
              // band was a 16%-alpha ghost — against a band with real colour
              // in it, opaque white reads as a white line drawn around the
              // circle, which is what it looked like.
              sheen: dark
                  ? AppColors.darkCream.withValues(alpha: 0.40)
                  : AppColors.goldSoft.withValues(alpha: 0.90),
              fill: scheme.surface.withValues(alpha: dark ? 0.28 : 0.55),
              arc: dark
                  ? const [AppColors.darkGold, AppColors.gold]
                  : const [AppColors.gold, AppColors.goldDark],
            ),
          ),
          // The numerals inside a ring are drawn to its diameter
          // (`fontSize: size * …`), so the reader's text size must not
          // multiply them again: at the largest setting they outgrew the ring
          // and were clipped.
          MediaQuery.withNoTextScaling(child: child),
          if (showLotus)
            // Centred on the band's outer edge, half in and half above the
            // ring, exactly as the artwork places it.
            Positioned(
              top: -size * _lotusHeight / 2,
              child: AppAssetImage(
                'assets/images/shared/golden_lotus_emblem.png',
                width: size * _lotusWidth,
                height: size * _lotusHeight,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}

class _GoldRingPainter extends CustomPainter {
  const _GoldRingPainter({
    required this.progress,
    required this.band,
    required this.track,
    required this.glow,
    required this.sheen,
    required this.fill,
    required this.arc,
    required this.illuminated,
  });

  final double progress;
  final double band;
  final Color track;
  final Color glow;
  final Color sheen;
  final Color fill;
  final List<Color> arc;
  final bool illuminated;

  /// How far past the band the glow reaches, and how soft it is — both as
  /// fractions of the band, so a small ring glows in proportion.
  static const _glowSpread = 2.3;
  static const _glowBlur = 0.85;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - band) / 2;

    // Down first, and wider than the band, so it is light coming off the ring
    // rather than an outline drawn on it — and so a full arc cannot cover it.
    // Painted under the arc, the glow vanished at exactly 100%, which on the
    // meditation timer is the moment a sitting begins.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * _glowSpread
        ..color = glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * _glowBlur),
    );

    canvas.drawCircle(center, radius - band / 2, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band
        ..color = track,
    );
    if (illuminated) {
      final bounds = Rect.fromCircle(center: center, radius: radius + band / 2);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band
          // The band occupies the outer 0.871..1 of these bounds, so the
          // first stop sits inside it: pulling it in from 0.84 is what keeps
          // the inner rim a hint rather than most of the band's width.
          ..shader = RadialGradient(
            colors: [sheen, track, sheen],
            stops: const [0.78, 0.93, 1],
          ).createShader(bounds),
      );
      for (final edge in [radius - band / 2, radius + band / 2]) {
        canvas.drawCircle(
          center,
          edge,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = band * 0.03
            ..color = AppColors.gold.withValues(alpha: 0.5),
        );
      }
    }
    if (progress <= 0) return;

    final circle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      circle,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band
        ..strokeCap = illuminated ? StrokeCap.butt : StrokeCap.round
        ..shader = SweepGradient(
          colors: arc,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(circle),
    );
  }

  @override
  bool shouldRepaint(_GoldRingPainter old) =>
      old.progress != progress ||
      old.band != band ||
      old.track != track ||
      old.glow != glow ||
      old.sheen != sheen ||
      old.illuminated != illuminated ||
      old.fill != fill;
}
