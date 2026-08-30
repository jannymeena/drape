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

  // Step 3 — aesthetics
  final List<String> styleAesthetics;

  // Step 4 — colour
  final String? undertone;
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

  StyleBlueprintDraft copyWith({
    String? bodyShape,
    String? fitTops,
    String? fitBottoms,
    List<String>? styleAesthetics,
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
      bodyShape: bodyShape ?? this.bodyShape,
      fitTops: fitTops ?? this.fitTops,
      fitBottoms: fitBottoms ?? this.fitBottoms,
      styleAesthetics: styleAesthetics ?? this.styleAesthetics,
      undertone: undertone ?? this.undertone,
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
