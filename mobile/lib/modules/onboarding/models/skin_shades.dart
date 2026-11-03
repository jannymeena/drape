import 'package:flutter/painting.dart' show Color;

/// Style Blueprint step 4's skin shades, fairest (1) to deepest (10): the
/// swatch shown, and the colours that flatter it (the "Colours that flatter
/// you" strip, and the reveal's palette). From the step 4 mockup.
class SkinShade {
  const SkinShade(this.number, this.color, this.flattering);

  /// 1–10, what's stored (`skin_shade`).
  final int number;
  final Color color;
  final List<Color> flattering;
}

const skinShades = [
  SkinShade(1, Color(0xFFF6EDE4), [
    Color(0xFF9EB3C2),
    Color(0xFF899878),
    Color(0xFF2C363F),
    Color(0xFFE4D6A7),
    Color(0xFFFAF0CA),
  ]),
  SkinShade(2, Color(0xFFF3E7DB), [
    Color(0xFFB7B7A4),
    Color(0xFFDDBEA9),
    Color(0xFF6B705C),
    Color(0xFFCB997E),
    Color(0xFFFFE8D6),
  ]),
  SkinShade(3, Color(0xFFF7EAD0), [
    Color(0xFFC9ADA7),
    Color(0xFF9A8C98),
    Color(0xFF4A4E69),
    Color(0xFF22223B),
    Color(0xFFF2E9E4),
  ]),
  SkinShade(4, Color(0xFFEADABA), [
    Color(0xFFC86D51),
    Color(0xFF987284),
    Color(0xFF75B9BE),
    Color(0xFFD0D6B5),
    Color(0xFFF9F1F0),
  ]),
  SkinShade(5, Color(0xFFD7BD96), [
    Color(0xFFC86D51),
    Color(0xFF8B9E6E),
    Color(0xFF512F1B),
    Color(0xFFD4A373),
    Color(0xFFFFF3E3),
  ]),
  SkinShade(6, Color(0xFFA07E56), [
    Color(0xFFA44A3F),
    Color(0xFFC38D9E),
    Color(0xFFE2B4BD),
    Color(0xFF45364B),
    Color(0xFFF7EBEC),
  ]),
  SkinShade(7, Color(0xFF825C43), [
    Color(0xFFB2533E),
    Color(0xFF186F65),
    Color(0xFFFFC436),
    Color(0xFFFCE09B),
    Color(0xFFEDE4E0),
  ]),
  SkinShade(8, Color(0xFF604134), [
    Color(0xFF893168),
    Color(0xFF4A1942),
    Color(0xFF2E1C2B),
    Color(0xFFEAE151),
    Color(0xFFEAE8E8),
  ]),
  SkinShade(9, Color(0xFF3A312A), [
    Color(0xFF93441A),
    Color(0xFF386641),
    Color(0xFFBC4749),
    Color(0xFFF2E8CF),
    Color(0xFFF4ECE1),
  ]),
  SkinShade(10, Color(0xFF292420), [
    Color(0xFFA8422B),
    Color(0xFFE0A96D),
    Color(0xFF201E1F),
    Color(0xFFD4B2D8),
    Color(0xFFFAF6EE),
  ]),
];

/// Shade [number], or null when there's none (skipped, or off the scale).
SkinShade? skinShade(int? number) =>
    number != null && number >= 1 && number <= skinShades.length
    ? skinShades[number - 1]
    : null;
