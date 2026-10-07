import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How a [GoldSparkle] is drawn. One shape, two weights.
enum SparkleStyle {
  /// Traced in a thin line — a drawn ornament.
  outlined,

  /// Solid, with a soft bloom of its own — a point of light.
  filled,
}

/// The four-pointed spark the artwork scatters around the gold ring.
///
/// Taller than it is wide, with the waist between two points pulled deep in so
/// the arms read long. Pale on purpose: these are meant to be caught out of
/// the corner of the eye, not read.
///
/// The home dashboard used `Icons.auto_awesome` for the same job, which is a
/// different star altogether — one shape now serves both.
class GoldSparkle extends StatelessWidget {
  const GoldSparkle({
    super.key,
    required this.size,
    this.style = SparkleStyle.outlined,
  });

  /// The star's width. Its height is [_aspect] times this.
  final double size;

  final SparkleStyle style;

  /// Taller than wide, so the vertical pair reads as the long axis.
  static const _aspect = 1.35;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.secondary;
    return CustomPaint(
      size: Size(size, size * _aspect),
      painter: _GoldSparklePainter(
        // A solid star covers far more ground than a traced one, so it is held
        // back further to weigh the same on the page.
        color: gold.withValues(
          alpha: style == SparkleStyle.filled ? 0.30 : 0.45,
        ),
        style: style,
      ),
    );
  }
}

class _GoldSparklePainter extends CustomPainter {
  const _GoldSparklePainter({required this.color, required this.style});

  final Color color;
  final SparkleStyle style;

  /// How far each edge's control point sits from the centre, as a fraction of
  /// the half-size. The smaller it is the deeper the waist between two points
  /// is pulled in, and the longer the points read; it was 0.18, which drew a
  /// star closer to a rounded diamond than to a spark.
  static const _waist = 0.07;

  /// The bloom around the star, as a fraction of its width.
  static const _bloom = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final inX = center.dx * (1 - _waist);
    final outX = center.dx * (1 + _waist);
    final inY = center.dy * (1 - _waist);
    final outY = center.dy * (1 + _waist);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(outX, inY, size.width, center.dy)
      ..quadraticBezierTo(outX, outY, center.dx, size.height)
      ..quadraticBezierTo(inX, outY, 0, center.dy)
      ..quadraticBezierTo(inX, inY, center.dx, 0)
      ..close();
    if (style == SparkleStyle.outlined) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.width * 0.06)
          ..color = color,
      );
      return;
    }
    // The bloom first, then the star on top of it.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.55)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, size.width * _bloom),
        ),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GoldSparklePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.style != style;
}
