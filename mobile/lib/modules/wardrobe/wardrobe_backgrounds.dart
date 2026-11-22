/// The backgrounds the wardrobe lays its pictures on (files in
/// `assets/wardrobe_backgrounds/`). Ghost-mannequin shots come back
/// transparent, so the background shows around the garment; an ordinary photo
/// covers it. Each item gets one of these at random.
///
/// Only the listed files are in the draw. `beige_wall.jpg` (beige wall with
/// window shadows) ships in the folder but is left out for now — add it here
/// to bring it back.
const wardrobeBackgrounds = [
  'assets/wardrobe_backgrounds/studio_grey.jpg',
];

/// A random pick of [backgrounds] for the item — the same one every time for
/// the same item, so its card doesn't change background on every rebuild.
/// Null when there are none.
String? wardrobeBackgroundFor(
  String itemId, [
  List<String> backgrounds = wardrobeBackgrounds,
]) {
  if (backgrounds.isEmpty) return null;
  var hash = 0;
  for (final unit in itemId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return backgrounds[hash % backgrounds.length];
}
