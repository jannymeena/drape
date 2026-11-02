import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Whether a stroke is part of the figure or a faint guide line around it.
enum GlyphTone { body, guide }

/// One stroke of a [LineGlyph]: an SVG-style path or an ellipse.
///
/// Paths take the subset of SVG path syntax the design exports use — `M`, `L`,
/// `H`, `V`, `C`, `S` and `Z`, absolute or relative, with implicit repeats —
/// so silhouettes can be pasted from the mockups verbatim instead of being
/// re-traced by hand.
class GlyphStroke {
  const GlyphStroke.path(
    String this.d, {
    this.tone = GlyphTone.body,
    this.width = 2,
    this.dash,
    this.fill,
  }) : cx = 0,
       cy = 0,
       rx = 0,
       ry = 0;

  const GlyphStroke.ellipse(
    this.cx,
    this.cy,
    this.rx,
    this.ry, {
    this.tone = GlyphTone.guide,
    this.width = 2,
    this.dash,
    this.fill,
  }) : d = null;

  final String? d;
  final double cx, cy, rx, ry;
  final GlyphTone tone;
  final double width;

  /// On/off lengths for a dashed stroke, in viewBox units.
  final List<double>? dash;

  /// Fills the shape in its tone colour at this opacity. A [width] of 0 then
  /// draws the fill alone. A highlighted glyph halves translucent fills, so
  /// the darker selected colour doesn't turn a tint into a block.
  final double? fill;

  Path build() {
    final d = this.d;
    if (d == null) {
      return Path()..addOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      );
    }
    return _parse(d);
  }
}

/// A line drawing in a fixed viewBox, scaled to fit its box.
class LineGlyphData {
  const LineGlyphData(this.width, this.height, this.strokes);

  final double width, height;
  final List<GlyphStroke> strokes;
}

/// Renders a [LineGlyphData]. [highlight] draws guide strokes in the body
/// colour too, for the selected state.
class LineGlyph extends StatelessWidget {
  const LineGlyph(
    this.data, {
    super.key,
    required this.size,
    this.highlight = false,
    this.color = AppColors.espresso,
  });

  final LineGlyphData data;
  final Size size;
  final bool highlight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _GlyphPainter(data, highlight: highlight, color: color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.data, {required this.highlight, required this.color});

  final LineGlyphData data;
  final bool highlight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / data.width) < (size.height / data.height)
        ? size.width / data.width
        : size.height / data.height;
    canvas
      ..save()
      ..translate(
        (size.width - data.width * scale) / 2,
        (size.height - data.height * scale) / 2,
      )
      ..scale(scale);
    for (final s in data.strokes) {
      final tone = s.tone == GlyphTone.body || highlight
          ? color
          : AppColors.taupeSoft;
      final path = s.build();
      final fill = s.fill;
      if (fill != null) {
        final opacity = highlight && fill < 1 ? fill / 2 : fill;
        canvas.drawPath(path, Paint()..color = tone.withValues(alpha: opacity));
      }
      if (s.width == 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tone;
      canvas.drawPath(s.dash == null ? path : _dashed(path, s.dash!), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.data != data || old.highlight != highlight || old.color != color;
}

Path _dashed(Path source, List<double> pattern) {
  final out = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    var distance = 0.0;
    var i = 0;
    while (distance < metric.length) {
      final len = pattern[i % pattern.length];
      if (i.isEven) {
        out.addPath(metric.extractPath(distance, distance + len), Offset.zero);
      }
      distance += len;
      i++;
    }
  }
  return out;
}

final _token = RegExp(r'[MLHVCSZmlhvcsz]|-?(?:\d+\.?\d*|\.\d+)');
final _letter = RegExp(r'[A-Za-z]');

Path _parse(String d) {
  final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // subpath start, for Z
  // Second control point of the last curve, which S/s reflects.
  double? cx2, cy2;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (_letter.hasMatch(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    var curve = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + next();
        y = oy + next();
        sx = x;
        sy = y;
        path.moveTo(x, y);
        // Extra coordinate pairs after M are line-tos.
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + next();
        y = oy + next();
        path.lineTo(x, y);
      case 'H':
        x = ox + next();
        path.lineTo(x, y);
      case 'V':
        y = oy + next();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + next(), y1 = oy + next();
        cx2 = ox + next();
        cy2 = oy + next();
        x = ox + next();
        y = oy + next();
        path.cubicTo(x1, y1, cx2, cy2, x, y);
        curve = true;
      case 'S':
        // First control point mirrors the previous curve's second one.
        final x1 = cx2 == null ? x : 2 * x - cx2;
        final y1 = cy2 == null ? y : 2 * y - cy2;
        cx2 = ox + next();
        cy2 = oy + next();
        x = ox + next();
        y = oy + next();
        path.cubicTo(x1, y1, cx2, cy2, x, y);
        curve = true;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
      default:
        throw FormatException('Unsupported path command "$cmd" in "$d"');
    }
    if (!curve) cx2 = cy2 = null;
  }
  return path;
}
