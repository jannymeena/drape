import '../widgets/line_glyph.dart';

/// The body-shape choices on Style Blueprint step 2, per shopping style.
///
/// All three sets store the same backend values (`BodyShape` in
/// `backend/app/schemas/profile.py`); only the names, descriptions and
/// drawings differ. Women's and men's use the familiar shape names; the
/// gender-neutral set describes the silhouette instead of naming it. Each set
/// has its own drawing style, from its own mockup.
enum BodyShapeSet { womens, mens, neutral }

/// Picks the set for a step 1 answer. `both` (no longer offered, but still
/// stored for some users) and "prefer not to say" get the neutral set.
BodyShapeSet bodyShapeSetFor(String? shoppingStyle) => switch (shoppingStyle) {
  'womens' => BodyShapeSet.womens,
  'mens' => BodyShapeSet.mens,
  _ => BodyShapeSet.neutral,
};

class BodyShapeOption {
  const BodyShapeOption(this.value, this.label, this.description, this.glyph);

  /// Backend literal.
  final String value;
  final String label;
  final String description;
  final LineGlyphData glyph;
}

/// The figure for [value] in [set]: a filled silhouette with a guide marking
/// the shape (`assets/onboarding/shapes/`), used wherever a shape is shown.
/// The line drawing in [BodyShapeOption.glyph] is kept only for the outline
/// traced over the user's photo while it's analysed.
String bodyShapeFigure(BodyShapeSet set, String value) =>
    'assets/onboarding/shapes/${set.name}/$value.svg';

List<BodyShapeOption> bodyShapesFor(BodyShapeSet set) => switch (set) {
  BodyShapeSet.womens => _womens,
  BodyShapeSet.mens => _mens,
  BodyShapeSet.neutral => _neutral,
};

/// The label the user saw for [value], for read-backs like the reveal screen.
String? bodyShapeLabel(String? value, String? shoppingStyle) {
  if (value == null) return null;
  for (final o in bodyShapesFor(bodyShapeSetFor(shoppingStyle))) {
    if (o.value == value) return o.label;
  }
  // A shape picked under a different set (the user changed step 1 later).
  for (final set in BodyShapeSet.values) {
    for (final o in bodyShapesFor(set)) {
      if (o.value == value) return o.label;
    }
  }
  return null;
}

// ─── Drawings ───────────────────────────────────────────────────────────────
// Women's: an open figure (two body lines) in a 60×90 box, with a
// faint head, shoulder line and a dashed marker where the shape is defined.

const _g = GlyphTone.guide;
const _dash = [2.0, 2.0];

LineGlyphData _figure(List<GlyphStroke> strokes) =>
    LineGlyphData(60, 90, strokes);

final _hourglass = _figure(const [
  GlyphStroke.path(
    'M22 14 C22 14, 26 12, 30 12 C34 12, 38 14, 38 14',
    tone: _g,
    width: 1.5,
  ),
  GlyphStroke.path('M20 20 C24 22, 36 22, 40 20', tone: _g, width: 1.5),
  GlyphStroke.path('M17 22 C22 28, 25 38, 24 44 C23 49, 18 60, 16 76'),
  GlyphStroke.path('M43 22 C38 28, 35 38, 36 44 C37 49, 42 60, 44 76'),
  GlyphStroke.ellipse(
    30,
    44,
    6,
    1.5,
    tone: GlyphTone.body,
    width: 1.5,
    dash: _dash,
  ),
]);

final _pear = _figure(const [
  GlyphStroke.path(
    'M24 14 C24 14, 27 12, 30 12 C33 12, 36 14, 36 14',
    tone: _g,
    width: 1.5,
  ),
  GlyphStroke.path('M22 22 C24 23, 36 23, 38 22', tone: _g, width: 1.5),
  GlyphStroke.path('M22 22 C22 28, 22 36, 18 46 C15 54, 14 66, 14 76'),
  GlyphStroke.path('M38 22 C38 28, 38 36, 42 46 C45 54, 46 66, 46 76'),
  GlyphStroke.path('M16 54 L44 54', tone: _g, width: 1, dash: _dash),
]);

final _apple = _figure(const [
  GlyphStroke.path(
    'M23 14 C23 14, 26 12, 30 12 C34 12, 37 14, 37 14',
    tone: _g,
    width: 1.5,
  ),
  GlyphStroke.path('M20 22 C23 23, 37 23, 40 22', tone: _g, width: 1.5),
  GlyphStroke.path('M20 22 C16 30, 16 46, 21 56 C23 60, 24 68, 22 76'),
  GlyphStroke.path('M40 22 C44 30, 44 46, 39 56 C37 60, 36 68, 38 76'),
  GlyphStroke.ellipse(30, 42, 12, 12, width: 1, dash: _dash),
]);

final _rectangle = _figure(const [
  GlyphStroke.path(
    'M22 14 C22 14, 26 12, 30 12 C34 12, 38 14, 38 14',
    tone: _g,
    width: 1.5,
  ),
  GlyphStroke.path('M19 22 C23 23, 37 23, 41 22', tone: _g, width: 1.5),
  GlyphStroke.path('M19 22 C20 36, 19 54, 20 76'),
  GlyphStroke.path('M41 22 C40 36, 41 54, 40 76'),
  GlyphStroke.path('M20 38 L40 38', tone: _g, width: 1, dash: _dash),
]);

final _invertedTriangle = _figure(const [
  GlyphStroke.path(
    'M21 14 C21 14, 25 12, 30 12 C35 12, 39 14, 39 14',
    tone: _g,
    width: 1.5,
  ),
  GlyphStroke.path('M16 22 C22 23, 38 23, 44 22', tone: _g, width: 1.5),
  GlyphStroke.path('M16 22 C20 34, 23 48, 23 76'),
  GlyphStroke.path('M44 22 C40 34, 37 48, 37 76'),
  GlyphStroke.path('M16 24 L44 24', width: 1.5),
]);

final _womens = [
  BodyShapeOption(
    'hourglass',
    'Hourglass',
    'Shoulders and hips similar, waist defined.',
    _hourglass,
  ),
  BodyShapeOption('triangle', 'Pear', 'Hips wider than shoulders.', _pear),
  BodyShapeOption(
    'oval',
    'Apple',
    'Fuller through the middle, slimmer legs.',
    _apple,
  ),
  BodyShapeOption(
    'rectangle',
    'Rectangle',
    'Shoulders, waist and hips about equal.',
    _rectangle,
  ),
  BodyShapeOption(
    'inverted_triangle',
    'Inverted Triangle',
    'Shoulders wider than hips.',
    _invertedTriangle,
  ),
];

// Men's: a filled torso in an 80×100 box, with dashed lines tracing the
// taper from shoulders to waist. Everything is a guide stroke, so the whole
// figure darkens when selected.

LineGlyphData _torso(String torso, List<GlyphStroke> markers) =>
    LineGlyphData(80, 100, [
      const GlyphStroke.path(
        'M40 8c3 0 5-2 5-5s-2-3-5-3-5 1-5 3 2 5 5 5z',
        tone: _g,
        width: 0,
        fill: 1,
      ),
      GlyphStroke.path(torso, tone: _g, fill: 0.3),
      ...markers,
    ]);

GlyphStroke _taper(double x1, double y1, double x2, double y2) =>
    GlyphStroke.path('M$x1 $y1 L$x2 $y2', tone: _g, width: 1.5, dash: _dash);

final _mens = [
  BodyShapeOption(
    'rectangle',
    'Rectangle',
    'Shoulders, waist and hips about equal.',
    _torso(
      'M26 22c-5 0-9 4-11 9l-3 18c-.5 3 1.5 5 4.5 4.5l3.5-.5v36c0 3 2 5 5 5h30c3 0 5-2 5-5V53l3.5.5c3 .5 5-1.5 4.5-4.5l-3-18c-2-5-6-9-11-9H26z',
      [_taper(28, 28, 28, 82), _taper(52, 28, 52, 82)],
    ),
  ),
  BodyShapeOption(
    'triangle',
    'Triangle',
    'Waist and hips wider than shoulders.',
    _torso(
      'M30 23c-4 0-7 3-8 7l-4 16c-.5 3 1.5 5 4 4.5l3-.5 3 34c.5 4 3.5 6 7 6h10c3.5 0 6.5-2 7-6l3-34 3 .5c2.5.5 4.5-1.5 4-4.5l-4-16c-1-4-4-7-8-7H30z',
      [_taper(31, 26, 23, 84), _taper(49, 26, 57, 84)],
    ),
  ),
  BodyShapeOption(
    'inverted_triangle',
    'Inverted Triangle',
    'Broad shoulders, narrower waist.',
    _torso(
      'M22 21c-5 0-9 4-11 9l-3 17c-.5 3 1.5 5 4.5 4.5l3.5-.5 4 33c.5 3 2.5 5 5.5 5h19c3 0 5-2 5.5-5l4-33 3.5.5c3 .5 5-1.5 4.5-4.5l-3-17c-2-5-6-9-11-9H22z',
      [_taper(22, 26, 31, 82), _taper(58, 26, 49, 82)],
    ),
  ),
  BodyShapeOption(
    'oval',
    'Oval',
    'Fuller through the middle.',
    _torso(
      'M26 23c-4 0-7 3-9 7l-3 15c-.5 3 1.5 5 4 4.5l3-.5c-1 8 0 17 2 24 1.5 5 5 8 9 8h16c4 0 7.5-3 9-8 2-7 3-16 2-24l3 .5c2.5.5 4.5-1.5 4-4.5l-3-15c-2-4-5-7-9-7H26z',
      const [
        GlyphStroke.path(
          'M27 48c3 6 8 10 13 10s10-4 13-10',
          tone: _g,
          width: 1.5,
          dash: _dash,
        ),
      ],
    ),
  ),
  BodyShapeOption(
    'trapezoid',
    'Trapezoid',
    'Broad shoulders and chest, straight waist.',
    _torso(
      'M24 22c-5 0-8 3-10 8l-3 17c-.5 3 1.5 5 4 4.5l3-.5 2 34c0 3 2.5 5 5.5 5h29c3 0 5.5-2 5.5-5l2-34 3 .5c2.5.5 4.5-1.5 4-4.5l-3-17c-2-5-5-8-10-8H24z',
      [_taper(25, 27, 30, 82), _taper(55, 27, 50, 82)],
    ),
  ),
];

// Gender-neutral: a closed outline in a 100×140 box. The outline is a guide
// stroke; the shoulder and waist/hip marks carry the shape.

LineGlyphData _outline(
  String outline,
  String shoulders,
  String lower, {
  GlyphTone lowerTone = GlyphTone.body,
  double shoulderWidth = 2,
}) => LineGlyphData(100, 140, [
  const GlyphStroke.ellipse(50, 18, 8, 4, dash: [2, 3]),
  GlyphStroke.path(outline, tone: _g, width: 2.5),
  GlyphStroke.path(shoulders, width: shoulderWidth),
  GlyphStroke.path(lower, tone: lowerTone),
]);

final _neutral = [
  BodyShapeOption(
    'rectangle',
    'Balanced',
    'Shoulders and hips about equal.',
    _outline(
      'M30 32C37 34 63 34 70 32C74 46 72 65 67 80C64 89 67 106 69 122H31C33 106 36 89 33 80C28 65 26 46 30 32Z',
      'M42 42C47 43 53 43 58 42',
      'M40 76C46 77 54 77 60 76',
    ),
  ),
  BodyShapeOption(
    'triangle',
    'Fuller hips',
    'Hips wider than shoulders.',
    _outline(
      'M34 32C40 33 60 33 66 32C68 46 65 65 62 76C60 85 71 106 74 122H26C29 106 40 85 38 76C35 65 32 46 34 32Z',
      'M44 42C48 43 52 43 56 42',
      'M36 88C45 90 55 90 64 88',
    ),
  ),
  BodyShapeOption(
    'inverted_triangle',
    'Broader shoulders',
    'Shoulders wider than hips.',
    _outline(
      'M24 32C34 34 66 34 76 32C76 46 70 65 64 78C61 86 63 105 64 122H36C37 105 39 86 36 78C30 65 24 46 24 32Z',
      'M38 42C46 44 54 44 62 42',
      'M42 90C47 91 53 91 58 90',
      lowerTone: _g,
      shoulderWidth: 2.5,
    ),
  ),
  BodyShapeOption(
    'oval',
    'Fuller middle',
    'Fuller through the waist and torso.',
    _outline(
      'M31 32C38 33 62 33 69 32C73 45 74 65 72 78C70 90 68 106 67 122H33C32 106 30 90 28 78C26 65 27 45 31 32Z',
      'M42 42C47 43 53 43 58 42',
      'M36 74C45 78 55 78 64 74',
    ),
  ),
  BodyShapeOption(
    'trapezoid',
    'Athletic',
    'Broad shoulders, straight waist.',
    _outline(
      'M26 32C35 33 65 33 74 32C74 48 70 65 67 78C65 89 65 106 65 122H35C35 106 35 89 33 78C30 65 26 48 26 32Z',
      'M38 42C46 43 54 43 62 42',
      'M42 78C47 78 53 78 58 78',
    ),
  ),
];
