import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A rounded rectangle drawn with a dashed 1dp stroke — the "needs a plan"
/// outline on the planning screens.
class DashedOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final Color? fill;

  const DashedOutline({
    super.key,
    required this.child,
    required this.color,
    this.radius = 12,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: color, radius: radius, fill: fill),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final Color? fill;
  const _DashedRRectPainter({required this.color, required this.radius, this.fill});

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ui.PathMetric metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.fill != fill;
}
