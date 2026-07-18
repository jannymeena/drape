import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Stand-in tile for a wardrobe item that has no photo (notably the seeded
/// starter wardrobe). Drawn boutique-style: hanging pieces (tops, outerwear,
/// dresses) drape from a slim wooden-tone hanger, trousers fold over the bar,
/// and shelf pieces (shoes, bags, belts) sit low with a soft ground shadow.
/// The garment renders in the item's actual colour with tailored, slightly
/// elongated silhouettes and fine seam lines — editorial flat-sketch, not
/// icon.
///
/// Pure CustomPaint — no image assets. [color] is the resolved garment colour
/// (see [garmentColorFromHex] / [garmentColorFromName]); null falls back to a
/// neutral cloth tone.
class GarmentPlaceholder extends StatelessWidget {
  final String category;
  final Color? color;

  const GarmentPlaceholder({super.key, required this.category, this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Subtle vertical warmth so the tile reads as lit shelf space.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.ivoryWarm,
            Color.lerp(AppColors.ivoryWarm, const Color(0xFFE4D9C8), 0.5)!,
          ],
        ),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.66,
          heightFactor: 0.72,
          child: CustomPaint(
            painter: _GarmentFlatPainter(
              category,
              color ?? const Color(0xFFCDC3B4), // neutral undyed-cloth tone
            ),
          ),
        ),
      ),
    );
  }
}

/// Parse `#RRGGBB` / `#AARRGGBB` (or without the leading `#`). Null on anything
/// unparseable.
Color? garmentColorFromHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Map the common colour names the templates / scanner emit to a representative
/// swatch. Null for unknown names (caller falls back to a neutral tile).
Color? garmentColorFromName(String? name) {
  if (name == null) return null;
  return _namedColors[name.trim().toLowerCase()];
}

const _namedColors = <String, Color>{
  'white': Color(0xFFF5F3EF),
  'cream': Color(0xFFEFE7D8),
  'beige': Color(0xFFD9CBB3),
  'tan': Color(0xFFCBB28C),
  'brown': Color(0xFF6F4E37),
  'black': Color(0xFF1F1D1B),
  'grey': Color(0xFF8A8784),
  'gray': Color(0xFF8A8784),
  'navy': Color(0xFF2A3550),
  'blue': Color(0xFF3B5C8C),
  'green': Color(0xFF53643A),
  'olive': Color(0xFF6B6B3A),
  'red': Color(0xFFB23B3B),
  'pink': Color(0xFFE0A9B0),
  'purple': Color(0xFF6E5A82),
  'yellow': Color(0xFFE3C567),
  'orange': Color(0xFFC97B40),
};

/// The categories that hang from the hanger (everything else sits low).
const _hanging = {'tops', 'outerwear', 'dresses', 'bottoms'};

class _GarmentFlatPainter extends CustomPainter {
  final String category;
  final Color color;
  const _GarmentFlatPainter(this.category, this.color);

  static const _hangerColor = Color(0xFF9B8468); // warm walnut

  // Seam/outline shades that stay visible on any garment colour.
  Color get _line => color.computeLuminance() > 0.45
      ? Color.lerp(color, const Color(0xFF3A322A), 0.42)!
      : Color.lerp(color, Colors.white, 0.36)!;

  Color get _outline => color.computeLuminance() > 0.45
      ? Color.lerp(color, const Color(0xFF3A322A), 0.32)!
      : Color.lerp(color, Colors.white, 0.22)!;

  String get _cat => category.toLowerCase();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hangs = _hanging.contains(_cat);

    if (hangs) {
      _drawHanger(canvas, w, h);
    } else {
      // Ground shadow for shelf pieces.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.94),
          width: w * 0.60,
          height: h * 0.05,
        ),
        Paint()
          ..color = const Color(0xFF3A322A).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    final body = _bodyPath(w, h);

    canvas.drawPath(body, Paint()..color = color);

    // Volume: light from the upper left, shade pooling low right.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.0),
            const Color(0xFF201A14).withValues(alpha: 0.13),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.restore();

    // Fine tailored outline.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = _outline,
    );

    // Seams, drape, hems — hairline weight.
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.011
      ..strokeCap = StrokeCap.round
      ..color = _line.withValues(alpha: 0.8);
    canvas.save();
    canvas.clipPath(body);
    _drawDetails(canvas, w, h, detail);
    canvas.restore();
    _drawOverlayDetails(canvas, w, h);
  }

  // ---------------------------------------------------------------- hanger --

  void _drawHanger(Canvas canvas, double w, double h) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round
      ..color = _hangerColor;
    // Hook.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.115)
        ..lineTo(w * 0.5, h * 0.075)
        ..quadraticBezierTo(w * 0.5, h * 0.015, w * 0.56, h * 0.022)
        ..quadraticBezierTo(w * 0.60, h * 0.028, w * 0.595, h * 0.06),
      p,
    );
    if (_cat == 'bottoms') {
      // Straight bar the trousers fold over.
      canvas.drawLine(
        Offset(w * 0.14, h * 0.20),
        Offset(w * 0.86, h * 0.20),
        p,
      );
      canvas.drawLine(Offset(w * 0.5, h * 0.115), Offset(w * 0.30, h * 0.20), p);
      canvas.drawLine(Offset(w * 0.5, h * 0.115), Offset(w * 0.70, h * 0.20), p);
    } else {
      // Shoulder arms sloping out from under the hook.
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.09, h * 0.265)
          ..quadraticBezierTo(w * 0.47, h * 0.10, w * 0.5, h * 0.115)
          ..quadraticBezierTo(w * 0.53, h * 0.10, w * 0.91, h * 0.265),
        p,
      );
    }
  }

  // ---------------------------------------------------------------- shapes --

  Path _bodyPath(double w, double h) {
    switch (_cat) {
      case 'bottoms':
        return _foldedTrousers(w, h);
      case 'dresses':
        return _slipDress(w, h);
      case 'shoes':
        return _sleekSneaker(w, h);
      case 'bags':
        return _handbag(w, h);
      case 'accessories':
        return _beltCoil(w, h);
      case 'outerwear':
        return _trench(w, h);
      case 'tops':
      default:
        return _drapedTee(w, h);
    }
  }

  /// Tee draping from the hanger arms — soft shoulders, a hint of waist.
  Path _drapedTee(double w, double h) => Path()
    ..moveTo(w * 0.365, h * 0.175)
    // Left shoulder along the hanger arm, short sleeve falling
    ..quadraticBezierTo(w * 0.22, h * 0.205, w * 0.125, h * 0.275)
    ..quadraticBezierTo(w * 0.085, h * 0.335, w * 0.10, h * 0.475)
    ..lineTo(w * 0.235, h * 0.50)
    ..quadraticBezierTo(w * 0.26, h * 0.46, w * 0.275, h * 0.425)
    // Body drape: in at the waist, out at the hem
    ..quadraticBezierTo(w * 0.255, h * 0.62, w * 0.285, h * 0.885)
    ..quadraticBezierTo(w * 0.5, h * 0.925, w * 0.715, h * 0.885)
    ..quadraticBezierTo(w * 0.745, h * 0.62, w * 0.725, h * 0.425)
    ..quadraticBezierTo(w * 0.74, h * 0.46, w * 0.765, h * 0.50)
    ..lineTo(w * 0.90, h * 0.475)
    ..quadraticBezierTo(w * 0.915, h * 0.335, w * 0.875, h * 0.275)
    ..quadraticBezierTo(w * 0.78, h * 0.205, w * 0.635, h * 0.175)
    // Scooped neckline under the hook
    ..quadraticBezierTo(w * 0.5, h * 0.26, w * 0.365, h * 0.175)
    ..close();

  /// Long open trench with a belt — hangs past the tee line.
  Path _trench(double w, double h) => Path()
    ..moveTo(w * 0.40, h * 0.155)
    ..quadraticBezierTo(w * 0.235, h * 0.185, w * 0.15, h * 0.26)
    // Slim sleeve hanging close to the body
    ..quadraticBezierTo(w * 0.095, h * 0.36, w * 0.10, h * 0.72)
    ..lineTo(w * 0.195, h * 0.735)
    ..lineTo(w * 0.225, h * 0.42)
    ..lineTo(w * 0.235, h * 0.945)
    ..quadraticBezierTo(w * 0.5, h * 0.975, w * 0.765, h * 0.945)
    ..lineTo(w * 0.775, h * 0.42)
    ..lineTo(w * 0.805, h * 0.735)
    ..lineTo(w * 0.90, h * 0.72)
    ..quadraticBezierTo(w * 0.905, h * 0.36, w * 0.85, h * 0.26)
    ..quadraticBezierTo(w * 0.765, h * 0.185, w * 0.60, h * 0.155)
    // Open collar falling to a deep V
    ..lineTo(w * 0.5, h * 0.30)
    ..close();

  /// Trousers folded over the hanger bar — wide leg, front crease.
  Path _foldedTrousers(double w, double h) => Path()
    // Fold bulge over the bar
    ..moveTo(w * 0.315, h * 0.245)
    ..quadraticBezierTo(w * 0.32, h * 0.165, w * 0.38, h * 0.155)
    ..lineTo(w * 0.62, h * 0.155)
    ..quadraticBezierTo(w * 0.68, h * 0.165, w * 0.685, h * 0.245)
    // Legs falling straight and slightly widening (wide-leg drape)
    ..quadraticBezierTo(w * 0.70, h * 0.55, w * 0.715, h * 0.90)
    ..quadraticBezierTo(w * 0.5, h * 0.93, w * 0.285, h * 0.90)
    ..quadraticBezierTo(w * 0.30, h * 0.55, w * 0.315, h * 0.245)
    ..close();

  /// Bias-cut slip dress — thin straps, cowl hint, long sway hem.
  Path _slipDress(double w, double h) => Path()
    // Left strap
    ..moveTo(w * 0.375, h * 0.135)
    ..lineTo(w * 0.405, h * 0.235)
    // Cowl neckline
    ..quadraticBezierTo(w * 0.5, h * 0.315, w * 0.595, h * 0.235)
    ..lineTo(w * 0.625, h * 0.135)
    ..lineTo(w * 0.655, h * 0.145)
    // Fitted through the ribs, easing at the hip
    ..quadraticBezierTo(w * 0.66, h * 0.33, w * 0.635, h * 0.46)
    ..quadraticBezierTo(w * 0.72, h * 0.68, w * 0.74, h * 0.895)
    // Sway hem — asymmetric, like caught mid-motion
    ..quadraticBezierTo(w * 0.62, h * 0.945, w * 0.46, h * 0.935)
    ..quadraticBezierTo(w * 0.32, h * 0.925, w * 0.265, h * 0.885)
    ..quadraticBezierTo(w * 0.29, h * 0.66, w * 0.365, h * 0.46)
    ..quadraticBezierTo(w * 0.34, h * 0.33, w * 0.345, h * 0.145)
    ..close();

  /// Minimal leather sneaker — long low profile, thin sole.
  Path _sleekSneaker(double w, double h) => Path()
    ..moveTo(w * 0.075, h * 0.815)
    ..lineTo(w * 0.075, h * 0.615)
    ..quadraticBezierTo(w * 0.08, h * 0.545, w * 0.17, h * 0.535)
    ..quadraticBezierTo(w * 0.25, h * 0.53, w * 0.315, h * 0.575)
    ..quadraticBezierTo(w * 0.35, h * 0.535, w * 0.42, h * 0.55)
    // Long, low vamp to a slightly pointed toe
    ..quadraticBezierTo(w * 0.60, h * 0.60, w * 0.77, h * 0.665)
    ..quadraticBezierTo(w * 0.90, h * 0.715, w * 0.935, h * 0.765)
    ..quadraticBezierTo(w * 0.95, h * 0.79, w * 0.945, h * 0.825)
    ..lineTo(w * 0.945, h * 0.845)
    ..quadraticBezierTo(w * 0.5, h * 0.895, w * 0.08, h * 0.85)
    ..close();

  /// Structured flap handbag with a single rounded handle.
  Path _handbag(double w, double h) => Path()
    ..moveTo(w * 0.285, h * 0.475)
    ..lineTo(w * 0.715, h * 0.475)
    ..quadraticBezierTo(w * 0.77, h * 0.475, w * 0.78, h * 0.535)
    ..lineTo(w * 0.815, h * 0.83)
    ..quadraticBezierTo(w * 0.82, h * 0.895, w * 0.75, h * 0.895)
    ..lineTo(w * 0.25, h * 0.895)
    ..quadraticBezierTo(w * 0.18, h * 0.895, w * 0.185, h * 0.83)
    ..lineTo(w * 0.22, h * 0.535)
    ..quadraticBezierTo(w * 0.23, h * 0.475, w * 0.285, h * 0.475)
    ..close();

  /// Coiled leather belt, viewed from above.
  Path _beltCoil(double w, double h) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.60),
      width: w * 0.68,
      height: h * 0.55,
    ))
    ..addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.60),
      width: w * 0.38,
      height: h * 0.28,
    ));

  // --------------------------------------------------------------- details --

  void _drawDetails(Canvas canvas, double w, double h, Paint p) {
    switch (_cat) {
      case 'bottoms':
        // Fold shadow at the bar, front creases, cuff line.
        canvas.drawLine(Offset(w * 0.33, h * 0.27), Offset(w * 0.675, h * 0.27), p);
        canvas.drawLine(Offset(w * 0.425, h * 0.30), Offset(w * 0.405, h * 0.885), p);
        canvas.drawLine(Offset(w * 0.575, h * 0.30), Offset(w * 0.595, h * 0.885), p);
        break;
      case 'dresses':
        // Cowl fold + bias drape sweeping with the hem.
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.43, h * 0.27)
            ..quadraticBezierTo(w * 0.5, h * 0.345, w * 0.57, h * 0.27),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.42, h * 0.52)
            ..quadraticBezierTo(w * 0.38, h * 0.72, w * 0.40, h * 0.90),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.565, h * 0.54)
            ..quadraticBezierTo(w * 0.60, h * 0.72, w * 0.635, h * 0.885),
          p,
        );
        break;
      case 'shoes':
        // Thin sole line, minimal two-eyelet lacing, quarter seam.
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.075, h * 0.79)
            ..quadraticBezierTo(w * 0.5, h * 0.835, w * 0.945, h * 0.795),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.235, h * 0.565)
            ..quadraticBezierTo(w * 0.29, h * 0.68, w * 0.26, h * 0.795),
          p,
        );
        canvas.drawLine(Offset(w * 0.455, h * 0.585), Offset(w * 0.525, h * 0.545), p);
        canvas.drawLine(Offset(w * 0.545, h * 0.625), Offset(w * 0.615, h * 0.585), p);
        break;
      case 'bags':
        // Flap edge + stitch line.
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.20, h * 0.60)
            ..quadraticBezierTo(w * 0.5, h * 0.655, w * 0.80, h * 0.60),
          p,
        );
        break;
      case 'accessories':
        // Stitched edge along the coil.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.60),
            width: w * 0.60,
            height: h * 0.475,
          ),
          p,
        );
        break;
      case 'outerwear':
        // Open front, lapel rolls, waist belt.
        canvas.drawLine(Offset(w * 0.5, h * 0.30), Offset(w * 0.5, h * 0.955), p);
        canvas.drawLine(Offset(w * 0.40, h * 0.155), Offset(w * 0.5, h * 0.355), p);
        canvas.drawLine(Offset(w * 0.60, h * 0.155), Offset(w * 0.5, h * 0.355), p);
        final belt = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.030
          ..color = _line.withValues(alpha: 0.8);
        canvas.drawLine(Offset(w * 0.24, h * 0.565), Offset(w * 0.76, h * 0.565), belt);
        break;
      case 'tops':
      default:
        // Neckline ribbing, sleeve hems, gentle bottom-hem curve.
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.385, h * 0.19)
            ..quadraticBezierTo(w * 0.5, h * 0.285, w * 0.615, h * 0.19),
          p,
        );
        canvas.drawLine(Offset(w * 0.115, h * 0.45), Offset(w * 0.245, h * 0.475), p);
        canvas.drawLine(Offset(w * 0.885, h * 0.45), Offset(w * 0.755, h * 0.475), p);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.295, h * 0.86)
            ..quadraticBezierTo(w * 0.5, h * 0.895, w * 0.705, h * 0.86),
          p,
        );
        break;
    }
  }

  /// Details that sit outside the body clip (handles, buckles, belt tail).
  void _drawOverlayDetails(Canvas canvas, double w, double h) {
    switch (_cat) {
      case 'bags':
        final handle = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.030
          ..strokeCap = StrokeCap.round
          ..color = _outline;
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.375, h * 0.48)
            ..quadraticBezierTo(w * 0.5, h * 0.235, w * 0.625, h * 0.48),
          handle,
        );
        break;
      case 'accessories':
        final buckle = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.026
          ..strokeJoin = StrokeJoin.round
          ..color = _outline;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.315),
              width: w * 0.155,
              height: h * 0.125,
            ),
            Radius.circular(w * 0.03),
          ),
          buckle,
        );
        canvas.drawLine(
          Offset(w * 0.5, h * 0.265),
          Offset(w * 0.5, h * 0.365),
          buckle..strokeWidth = w * 0.018,
        );
        break;
      case 'outerwear':
        // Belt tail slipping out of the knot.
        final tail = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.028
          ..strokeCap = StrokeCap.round
          ..color = _line.withValues(alpha: 0.8);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.575)
            ..quadraticBezierTo(w * 0.545, h * 0.635, w * 0.53, h * 0.70),
          tail,
        );
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_GarmentFlatPainter old) =>
      old.category != category || old.color != color;
}
