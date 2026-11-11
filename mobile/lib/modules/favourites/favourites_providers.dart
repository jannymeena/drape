import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../today/models/outfit.dart';
import '../today/today_controller.dart';
import '../wardrobe/models/wardrobe_item.dart';
import '../wardrobe/wardrobe_service.dart';

/// Favourite wardrobe items — `GET /wardrobe?is_favorite=true` (real API).
/// AutoDispose so each visit refetches (hearts change from the Wardrobe tab).
/// Debug builds fall back to [sampleFavouriteItems] when nothing is saved.
final favouriteItemsProvider = FutureProvider.autoDispose<List<WardrobeItem>>((
  ref,
) async {
  final result = await ref
      .read(wardrobeServiceProvider)
      .getItems(isFavorite: true, limit: 200);
  if (result.items.isEmpty && kDebugMode) return sampleFavouriteItems();
  return result.items;
});

/// Favourite outfits. There is no "list favourite outfits" endpoint yet
/// (BACKEND_CHANGES 1.0), so this is today's hearted outfits from the Today
/// frame — live: hearting/un-hearting on either screen shows on both.
/// Swap for the endpoint so earlier days' favourites appear too.
///
/// Debug builds fall back to [sampleFavouriteOutfits] when nothing is saved,
/// so the screen can be reviewed; release builds never show them.
final favouriteOutfitsProvider = Provider<List<Outfit>>((ref) {
  final outfits = ref.watch(todayControllerProvider).dashboard?.outfits;
  final saved = [
    for (final o in outfits ?? const <Outfit>[])
      if (o.isFavorite) o,
  ];
  if (saved.isEmpty && kDebugMode) return sampleFavouriteOutfits();
  return saved;
});

// ─── Debug-only sample cards (the Stitch mock's four looks) ───────────────

const _samplePrefix = 'sample-';

/// Sample cards aren't real records: their actions explain instead of
/// calling the API.
bool isSampleFavourite(String id) => id.startsWith(_samplePrefix);

OutfitItem _piece(
  String name,
  String category,
  String colour,
  String formality,
) => OutfitItem(
  itemId: '$_samplePrefix${name.toLowerCase().replaceAll(' ', '-')}',
  name: name,
  category: category,
  colorName: colour,
  formality: formality,
);

@visibleForTesting
List<Outfit> sampleFavouriteOutfits() => [
  Outfit(
    id: '${_samplePrefix}autumn',
    title: 'Autumn camel & denim',
    occasion: 'casual',
    items: [
      _piece('Camel Trench', 'outerwear', 'tan', 'smart_casual'),
      _piece('Cashmere Knit', 'tops', 'cream', 'smart_casual'),
      _piece('Raw Denim', 'bottoms', 'navy', 'casual'),
      _piece('Leather Bag', 'bags', 'brown', 'smart_casual'),
    ],
    usingStarterWardrobe: false,
    isLogged: false,
    wornCount: 2,
    isFavorite: true,
  ),
  Outfit(
    id: '${_samplePrefix}espresso',
    title: 'Tailored espresso look',
    occasion: 'work',
    items: [
      _piece('Espresso Blazer', 'outerwear', 'brown', 'formal'),
      _piece('Silk Blouse', 'tops', 'cream', 'formal'),
      _piece('Pleated Trousers', 'bottoms', 'black', 'formal'),
      _piece('Loafers', 'shoes', 'cream', 'formal'),
    ],
    usingStarterWardrobe: false,
    isLogged: false,
    wornCount: 1,
    isFavorite: true,
  ),
  Outfit(
    id: '${_samplePrefix}rainy',
    title: 'Rainy-day layers',
    occasion: 'casual',
    items: [
      _piece('Wax Rain Mac', 'outerwear', 'olive', 'casual'),
      _piece('Wool Scarf', 'accessories', 'brown', 'casual'),
      _piece('Moccasins', 'shoes', 'brown', 'casual'),
    ],
    usingStarterWardrobe: false,
    isLogged: false,
    wornCount: 0,
    isFavorite: true,
  ),
  Outfit(
    id: '${_samplePrefix}office',
    title: 'Dry office classic',
    occasion: 'work',
    items: [
      _piece('Poplin Shirt', 'tops', 'white', 'smart_casual'),
      _piece('Pleated Culottes', 'bottoms', 'grey', 'smart_casual'),
      _piece('Leather Tote', 'bags', 'black', 'smart_casual'),
    ],
    usingStarterWardrobe: false,
    isLogged: false,
    wornCount: 4,
    isFavorite: true,
  ),
];

@visibleForTesting
List<WardrobeItem> sampleFavouriteItems() {
  final at = DateTime(2026, 11, 1);
  WardrobeItem item(
    String name,
    String category,
    String colour,
    String formality,
    int worn,
  ) => WardrobeItem.fromJson({
    'id': '$_samplePrefix${name.toLowerCase().replaceAll(' ', '-')}',
    'name': name,
    'category': category,
    'color_name': colour,
    'formality': formality,
    'worn_count': worn,
    'is_favorite': true,
    'created_at': at.toIso8601String(),
    'updated_at': at.toIso8601String(),
  });
  return [
    item('Camel Overcoat', 'outerwear', 'tan', 'smart_casual', 6),
    item('Ribbed Knit', 'tops', 'cream', 'smart_casual', 9),
    item('Charcoal Trousers', 'bottoms', 'grey', 'smart_casual', 7),
    item('Chelsea Boots', 'shoes', 'brown', 'smart_casual', 12),
    item('Silk Blouse', 'tops', 'white', 'formal', 2),
    item('Leather Tote', 'bags', 'black', 'smart_casual', 0),
  ];
}

/// "We are learning your taste" line, from what's been saved: the most saved
/// dress level and whether the colours lean neutral. Null until there's
/// enough to say something (2+ favourites with a signal).
String? tasteInsight({
  required List<Outfit> outfits,
  required List<WardrobeItem> items,
}) {
  final formalities = <String>[
    for (final o in outfits)
      for (final i in o.items)
        if (i.formality != null) i.formality!,
    for (final i in items)
      if (i.formality != null) i.formality!,
  ];
  final colours = <String>[
    for (final o in outfits)
      for (final i in o.items)
        if (i.colorName != null) i.colorName!.toLowerCase(),
    for (final i in items)
      if (i.colorName != null) i.colorName!.toLowerCase(),
  ];
  if (outfits.length + items.length < 2) return null;

  String? topFormality;
  if (formalities.isNotEmpty) {
    final counts = <String, int>{};
    for (final f in formalities) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    topFormality = counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key
        .replaceAll('_', ' ');
  }

  String? colourPhrase;
  if (colours.isNotEmpty) {
    final neutral = colours.where(_isNeutral).length;
    if (neutral / colours.length >= 0.6) {
      colourPhrase = 'neutral tones';
    } else {
      final counts = <String, int>{};
      for (final c in colours) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      final top = counts.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      colourPhrase = '$top pieces';
    }
  }

  if (topFormality == null && colourPhrase == null) return null;
  final parts = [?topFormality, ?colourPhrase];
  return 'You save ${parts.join(' and ')} the most.';
}

const _neutrals = {
  'black',
  'white',
  'ivory',
  'cream',
  'beige',
  'camel',
  'tan',
  'taupe',
  'brown',
  'chocolate',
  'espresso',
  'grey',
  'gray',
  'charcoal',
  'navy',
  'khaki',
  'stone',
  'sand',
  'off-white',
  'oatmeal',
  'nude',
};

bool _isNeutral(String colour) =>
    _neutrals.any((n) => colour == n || colour.contains(n));
