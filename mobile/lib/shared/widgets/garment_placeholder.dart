import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Stand-in tile for a wardrobe item that has no photo (notably the seeded
/// starter wardrobe). Instead of an identical hanger for every item, it paints
/// the item's actual colour as the background and a category silhouette on top,
/// so a white tee, blue jeans, and a black dress read as distinct at a glance.
///
/// Pure CustomPaint — no image assets. [color] is the resolved garment colour
/// (see [garmentColorFromHex] / [garmentColorFromName]); null falls back to a
/// neutral tile.
class GarmentPlaceholder extends StatelessWidget {
  final String category;
  final Color? color;

  const GarmentPlaceholder({super.key, required this.category, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.ivoryWarm;
    // Pick a glyph colour that stays legible on light or dark tiles.
    final onBg = color == null
        ? AppColors.taupeSoft
        : (bg.computeLuminance() > 0.6
            ? AppColors.espresso.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.85));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.52,
          heightFactor: 0.52,
          child: CustomPaint(
            painter: _GarmentSilhouettePainter(category, onBg),
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

class _GarmentSilhouettePainter extends CustomPainter {
  final String category;
  final Color color;
  const _GarmentSilhouettePainter(this.category, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..color = color;

    switch (category.toLowerCase()) {
      case 'bottoms':
        final path = Path()
          ..moveTo(w * 0.25, h * 0.1)
          ..lineTo(w * 0.75, h * 0.1)
          ..lineTo(w * 0.7, h * 0.95)
          ..lineTo(w * 0.56, h * 0.95)
          ..lineTo(w * 0.5, h * 0.45)
          ..lineTo(w * 0.44, h * 0.95)
          ..lineTo(w * 0.3, h * 0.95)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case 'dresses':
        final path = Path()
          ..moveTo(w * 0.38, h * 0.1)
          ..lineTo(w * 0.62, h * 0.1)
          ..lineTo(w * 0.58, h * 0.4)
          ..lineTo(w * 0.85, h * 0.92)
          ..lineTo(w * 0.15, h * 0.92)
          ..lineTo(w * 0.42, h * 0.4)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case 'shoes':
        final path = Path()
          ..moveTo(w * 0.1, h * 0.72)
          ..lineTo(w * 0.1, h * 0.52)
          ..lineTo(w * 0.42, h * 0.48)
          ..lineTo(w * 0.5, h * 0.58)
          ..quadraticBezierTo(w * 0.75, h * 0.6, w * 0.92, h * 0.66)
          ..lineTo(w * 0.92, h * 0.72)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case 'bags':
        final body = Path()
          ..moveTo(w * 0.26, h * 0.42)
          ..lineTo(w * 0.74, h * 0.42)
          ..lineTo(w * 0.82, h * 0.85)
          ..lineTo(w * 0.18, h * 0.85)
          ..close();
        canvas.drawPath(body, fill);
        // Handle arc.
        final handle = Path()
          ..moveTo(w * 0.36, h * 0.42)
          ..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.64, h * 0.42);
        canvas.drawPath(handle, stroke);
        break;
      case 'tops':
      case 'outerwear':
      default:
        // T-shirt / top silhouette (also the fallback).
        final path = Path()
          ..moveTo(w * 0.35, h * 0.15)
          ..lineTo(w * 0.2, h * 0.25)
          ..lineTo(w * 0.08, h * 0.42)
          ..lineTo(w * 0.24, h * 0.52)
          ..lineTo(w * 0.24, h * 0.88)
          ..lineTo(w * 0.76, h * 0.88)
          ..lineTo(w * 0.76, h * 0.52)
          ..lineTo(w * 0.92, h * 0.42)
          ..lineTo(w * 0.8, h * 0.25)
          ..lineTo(w * 0.65, h * 0.15)
          ..quadraticBezierTo(w * 0.5, h * 0.3, w * 0.35, h * 0.15)
          ..close();
        canvas.drawPath(path, fill);
        break;
    }
  }

  @override
  bool shouldRepaint(_GarmentSilhouettePainter old) =>
      old.category != category || old.color != color;
}
