/// The answers collected across steps 2–7 of the Style Blueprint.
///
/// Mirrors the backend `StyleProfileResponse` / `users.style_profile` JSONB
/// blob. Every field is nullable because the blob fills in one step at a time,
/// and because a resumed flow hydrates whatever the user had already saved.
///
/// Step 1's answers (shopping style, age range) and step 7's style goals keep
/// their own dedicated fields on [OnboardingState] — they have dedicated
/// columns on the backend and are read by starter-wardrobe matching.
class StyleBlueprintDraft {
  const StyleBlueprintDraft({
    this.bodyShape,
    this.fitTops,
    this.fitBottoms,
    this.styleAesthetics = const [],
    this.microAesthetics = const [],
    this.skinShade,
    this.undertone,
    this.colorPalettes = const [],
    this.occupation,
    this.dressCode,
    this.impressionGoal,
    this.shoppingFeeling,
    this.accessories,
    this.brandTier,
    this.threeMonthFeeling,
  });

  // Step 2 — fit
  final String? bodyShape;
  final String? fitTops;
  final String? fitBottoms;

  // Step 3 — aesthetics, and the optional "Want to get more specific?" tags
  final List<String> styleAesthetics;
  final List<String> microAesthetics;

  // Step 4 — skin tone: shade 1 (fairest) to 10 (deepest), and undertone.
  // Both null when the step was skipped.
  final int? skinShade;
  final String? undertone;

  /// From the earlier step 4 (palettes the user liked); no longer asked,
  /// still read back for users who answered it.
  final List<String> colorPalettes;

  // Step 5 — lifestyle
  final String? occupation;
  final String? dressCode;
  final String? impressionGoal;

  // Step 6 — habits
  final String? shoppingFeeling;
  final String? accessories;
  final String? brandTier;

  // Step 7 — aspiration
  final String? threeMonthFeeling;

  /// [clearBodyShape] sets [bodyShape] to null — a null argument alone means
  /// "unchanged", and "Not sure" has to be able to erase an earlier pick.
  /// [clearSkinTone] likewise nulls [skinShade] and [undertone], for step 4's
  /// "Skip for now".
  StyleBlueprintDraft copyWith({
    String? bodyShape,
    bool clearBodyShape = false,
    int? skinShade,
    bool clearSkinTone = false,
    String? fitTops,
    String? fitBottoms,
    List<String>? styleAesthetics,
    List<String>? microAesthetics,
    String? undertone,
    List<String>? colorPalettes,
    String? occupation,
    String? dressCode,
    String? impressionGoal,
    String? shoppingFeeling,
    String? accessories,
    String? brandTier,
    String? threeMonthFeeling,
  }) {
    return StyleBlueprintDraft(
      bodyShape: clearBodyShape ? null : bodyShape ?? this.bodyShape,
      fitTops: fitTops ?? this.fitTops,
      fitBottoms: fitBottoms ?? this.fitBottoms,
      styleAesthetics: styleAesthetics ?? this.styleAesthetics,
      microAesthetics: microAesthetics ?? this.microAesthetics,
      skinShade: clearSkinTone ? null : skinShade ?? this.skinShade,
      undertone: clearSkinTone ? null : undertone ?? this.undertone,
      colorPalettes: colorPalettes ?? this.colorPalettes,
      occupation: occupation ?? this.occupation,
      dressCode: dressCode ?? this.dressCode,
      impressionGoal: impressionGoal ?? this.impressionGoal,
      shoppingFeeling: shoppingFeeling ?? this.shoppingFeeling,
      accessories: accessories ?? this.accessories,
      brandTier: brandTier ?? this.brandTier,
      threeMonthFeeling: threeMonthFeeling ?? this.threeMonthFeeling,
    );
  }

  factory StyleBlueprintDraft.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) =>
        (json[key] as List<dynamic>?)?.cast<String>() ?? const [];
    return StyleBlueprintDraft(
      bodyShape: json['body_shape'] as String?,
      fitTops: json['fit_tops'] as String?,
      fitBottoms: json['fit_bottoms'] as String?,
      styleAesthetics: list('style_aesthetics'),
      microAesthetics: list('micro_aesthetics'),
      skinShade: (json['skin_shade'] as num?)?.toInt(),
      undertone: json['undertone'] as String?,
      colorPalettes: list('color_palettes'),
      occupation: json['occupation'] as String?,
      dressCode: json['dress_code'] as String?,
      impressionGoal: json['impression_goal'] as String?,
      shoppingFeeling: json['shopping_feeling'] as String?,
      accessories: json['accessories'] as String?,
      brandTier: json['brand_tier'] as String?,
      threeMonthFeeling: json['three_month_feeling'] as String?,
    );
  }
}
