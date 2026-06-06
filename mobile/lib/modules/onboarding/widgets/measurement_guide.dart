import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Dual-card guide for a body measurement: left = a line-drawn figure with the
/// region being measured highlighted in gold; right = a short how-to-measure
/// tip. Drawn with [CustomPaint] so there are no image assets to ship and every
/// body part stays crisp at any size.
class MeasurementGuide extends StatelessWidget {
  final String bodyPart;

  const MeasurementGuide({super.key, required this.bodyPart});

  static const _tips = <String, String>{
    'height': 'Stand tall against a wall and measure from the floor to the top of your head.',
    'weight': 'Step on a scale on a hard, flat surface — optional, it sharpens fit accuracy.',
    'shoulders': 'Measure across your back from the edge of one shoulder to the other.',
    'chest': 'Measure around the fullest part of your chest, keeping the tape level.',
    'waist': 'Measure around your natural waistline, just above the belly button.',
    'hips': 'Measure around the fullest part of your hips and seat.',
    'thigh': 'Measure around the fullest part of one thigh.',
    'inseam': 'Measure from the crotch straight down to the ankle.',
  };

  @override
  Widget build(BuildContext context) {
    final tip = _tips[bodyPart] ?? 'Keep the tape snug and level as you measure.';
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.taupeSoft),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: CustomPaint(
                painter: _BodyMeasurePainter(bodyPart),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.tanFixed,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'HOW TO MEASURE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.espressoDark,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bodyPart[0].toUpperCase() + bodyPart.substring(1),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.espressoDark,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a simple front-facing figure and highlights the region for [bodyPart]:
/// a gold band for circumference measurements (chest/waist/hips/thigh) or a gold
/// line for the inseam length.
class _BodyMeasurePainter extends CustomPainter {
  final String bodyPart;
  const _BodyMeasurePainter(this.bodyPart);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final figure = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = AppColors.taupe;

    // Vertical anchors as fractions of height.
    final headR = h * 0.07;
    final headC = Offset(cx, h * 0.12);
    final shoulderY = h * 0.24;
    final hipY = h * 0.54;
    final footY = h * 0.94;
    final halfTorso = w * 0.16;
    final halfShoulder = w * 0.20;
    final legHalfGap = w * 0.03;
    final legHalfW = w * 0.085;

    // Head.
    canvas.drawCircle(headC, headR, figure);
    // Neck.
    canvas.drawLine(Offset(cx, headC.dy + headR), Offset(cx, shoulderY), figure);
    // Torso (shoulders → hips).
    final torso = Path()
      ..moveTo(cx - halfShoulder, shoulderY)
      ..lineTo(cx + halfShoulder, shoulderY)
      ..lineTo(cx + halfTorso, hipY)
      ..lineTo(cx - halfTorso, hipY)
      ..close();
    canvas.drawPath(torso, figure);
    // Arms.
    canvas.drawLine(Offset(cx - halfShoulder, shoulderY),
        Offset(cx - halfShoulder - w * 0.04, hipY - h * 0.02), figure);
    canvas.drawLine(Offset(cx + halfShoulder, shoulderY),
        Offset(cx + halfShoulder + w * 0.04, hipY - h * 0.02), figure);
    // Legs.
    canvas.drawLine(Offset(cx - legHalfGap - legHalfW, hipY),
        Offset(cx - legHalfGap - legHalfW, footY), figure);
    canvas.drawLine(Offset(cx - legHalfGap, hipY), Offset(cx - legHalfGap, footY),
        figure);
    canvas.drawLine(Offset(cx + legHalfGap + legHalfW, hipY),
        Offset(cx + legHalfGap + legHalfW, footY), figure);
    canvas.drawLine(Offset(cx + legHalfGap, hipY), Offset(cx + legHalfGap, footY),
        figure);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gold;

    double lerp(double a, double b, double t) => a + (b - a) * t;

    if (bodyPart == 'weight') {
      // Not a tape measurement — no single region to highlight; the plain
      // figure plus the how-to card carry it.
      return;
    }

    if (bodyPart == 'height') {
      // Full-height line down the right side, with end ticks (floor → head top).
      final x = cx + halfShoulder + w * 0.10;
      final topY = headC.dy - headR;
      canvas.drawLine(Offset(x, topY), Offset(x, footY), highlight);
      canvas.drawLine(Offset(x - w * 0.04, topY), Offset(x + w * 0.04, topY), highlight);
      canvas.drawLine(Offset(x - w * 0.04, footY), Offset(x + w * 0.04, footY), highlight);
      return;
    }

    if (bodyPart == 'shoulders') {
      // Band straight across the shoulder line.
      final halfBand = halfShoulder + w * 0.03;
      canvas.drawLine(Offset(cx - halfBand, shoulderY),
          Offset(cx + halfBand, shoulderY), highlight);
      return;
    }

    if (bodyPart == 'inseam') {
      // Vertical line down the inner leg.
      final x = cx - legHalfGap - legHalfW / 2;
      canvas.drawLine(Offset(x, hipY), Offset(x, footY), highlight);
      return;
    }

    if (bodyPart == 'thigh') {
      // Band across the upper leg, below the hips.
      final y = lerp(hipY, footY, 0.22);
      canvas.drawLine(Offset(cx - legHalfGap - legHalfW * 1.4, y),
          Offset(cx - legHalfGap + legHalfW * 0.4, y), highlight);
      return;
    }

    // Circumference band: a horizontal line spanning slightly past the body
    // width at the region's height (fraction between shoulders and hips).
    final double t;
    switch (bodyPart) {
      case 'chest':
        t = 0.18;
        break;
      case 'hips':
        t = 0.95;
        break;
      case 'waist':
      default:
        t = 0.52;
    }
    final y = lerp(shoulderY, hipY, t);
    final halfBand = lerp(halfShoulder, halfTorso, t) + w * 0.03;
    canvas.drawLine(Offset(cx - halfBand, y), Offset(cx + halfBand, y), highlight);
  }

  @override
  bool shouldRepaint(_BodyMeasurePainter old) => old.bodyPart != bodyPart;
}
