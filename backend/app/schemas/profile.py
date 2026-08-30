"""Phase 5a — profile setup request/response shapes.

The Literal types here are the source of truth for accepted values; the DB
columns (`users.shopping_style`, `users.age_range`) are plain VARCHAR and the
style-blueprint answers live in a single `users.style_profile` JSONB blob, so
we can extend the value set without a migration. If you add a new age band or
style goal, update the Literal here and clients will get a 422 for stale
values until they upgrade.

Onboarding is the 7-step "Style Blueprint" (see `handoff/` blueprints
`style_blueprint_*_of_7_*`). Each step posts one request model below and the
service advances `users.onboarding_last_step`.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

ShoppingStyle = Literal["womens", "mens", "both", "prefer_not_to_say"]
AgeRange = Literal["18-24", "25-34", "35-44", "45-54", "55+", "prefer_not_to_say"]
StyleGoal = Literal[
    "time_saving",
    "polished",
    "maximize_wardrobe",
    "discover_style",
    "confidence",
    "reduce_clutter",
]

# ── Style-blueprint value sets (steps 2-7) ────────────────────────────────
BodyShape = Literal[
    "rectangle", "triangle", "inverted_triangle", "trapezoid", "oval", "hourglass"
]
TopsFit = Literal["slim", "regular", "loose"]
BottomsFit = Literal["skinny", "relaxed", "baggy"]
# Step 3 shows a gendered card set: `rugged`/`smart_casual` are the men's
# tiles, `bohemian`/`romantic` the women's; the other four are shared.
StyleAesthetic = Literal[
    "minimalist",
    "rugged",
    "bohemian",
    "professional",
    "streetwear",
    "smart_casual",
    "romantic",
    "avant_garde",
]
Undertone = Literal["warm", "cool", "neutral"]
ColorPalette = Literal[
    "neutrals", "earth_tones", "jewel_tones", "pastels", "black_white", "bold_bright"
]
DressCode = Literal["casual", "business_casual", "business_formal", "uniform_other"]
ImpressionGoal = Literal["work", "dating", "both", "content"]
ShoppingFeeling = Literal["confident", "necessity", "frustrated", "exploring"]
Accessories = Literal["none", "minimal", "statement"]
BrandTier = Literal["fast_fashion", "premium", "luxury", "mix"]
ThreeMonthFeeling = Literal[
    "confident_anywhere",
    "found_my_look",
    "excited_not_stressed",
    "proud_no_second_guessing",
]

# The seven blueprint screens, then the reveal, then the app.
OnboardingStep = Literal[
    "style_blueprint_1",
    "style_blueprint_2",
    "style_blueprint_3",
    "style_blueprint_4",
    "style_blueprint_5",
    "style_blueprint_6",
    "style_blueprint_7",
    "style_blueprint_reveal",
    "today_dashboard",
]

# Steps from the pre-redesign 15-screen flow. Still accepted by save-progress
# so the standalone measurement screens (now reached from the Shop tab rather
# than onboarding) don't 422, but they no longer chain — see
# `profile_service._LEGACY_STEPS`.
LegacyOnboardingStep = Literal[
    "shopping_style_selection",
    "age_range",
    "style_goals",
    "pre_measurement_intro",
    "measurements_step_1",
    "measurements_step_2",
    "measurements_step_3",
    "measurements_step_4",
    "measurements_step_5",
    "measurements_step_6",
    "measurements_step_7",
    "measurements_step_8",
    "avatar_reveal",
]


class StyleBlueprintIdentityRequest(BaseModel):
    """Step 1 — who we're shopping for, and life stage."""

    shopping_style: ShoppingStyle
    # Nullable so the client can transmit "skip this step" explicitly.
    age_range: AgeRange | None = None


class StyleBlueprintFitRequest(BaseModel):
    """Step 2 — self-reported body shape and how clothes should sit."""

    body_shape: BodyShape
    fit_tops: TopsFit
    fit_bottoms: BottomsFit


class StyleBlueprintAestheticsRequest(BaseModel):
    """Step 3 — the style card grid (gendered art, shared value set)."""

    style_aesthetics: list[StyleAesthetic] = Field(min_length=1, max_length=8)


class StyleBlueprintColorRequest(BaseModel):
    """Step 4 — skin undertone plus the palettes the user gravitates toward."""

    undertone: Undertone
    color_palettes: list[ColorPalette] = Field(min_length=1, max_length=6)


class StyleBlueprintLifestyleRequest(BaseModel):
    """Step 5 — work context. `dress_code` is null when the user isn't working."""

    occupation: str | None = Field(default=None, max_length=120)
    dress_code: DressCode | None = None
    impression_goal: ImpressionGoal


class StyleBlueprintHabitsRequest(BaseModel):
    """Step 6 — attitude to shopping, accessories, and price bracket."""

    shopping_feeling: ShoppingFeeling
    accessories: Accessories
    brand_tier: BrandTier


class StyleBlueprintGoalsRequest(BaseModel):
    """Step 7 — the aspiration plus the (pre-existing) style goals."""

    three_month_feeling: ThreeMonthFeeling
    style_goals: list[StyleGoal] = Field(min_length=1, max_length=10)


class SaveProgressRequest(BaseModel):
    """Records where the user paused so the next session resumes there."""

    last_completed_step: OnboardingStep | LegacyOnboardingStep


class StyleProfileResponse(BaseModel):
    """The step 2-7 answers, as stored in `users.style_profile`. Every field is
    optional because the blob fills in one step at a time."""

    body_shape: BodyShape | None = None
    fit_tops: TopsFit | None = None
    fit_bottoms: BottomsFit | None = None
    style_aesthetics: list[StyleAesthetic] | None = None
    undertone: Undertone | None = None
    color_palettes: list[ColorPalette] | None = None
    occupation: str | None = None
    dress_code: DressCode | None = None
    impression_goal: ImpressionGoal | None = None
    shopping_feeling: ShoppingFeeling | None = None
    accessories: Accessories | None = None
    brand_tier: BrandTier | None = None
    three_month_feeling: ThreeMonthFeeling | None = None


class OnboardingStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    onboarding_completed: bool
    onboarding_last_step: str | None
    next_step: OnboardingStep
    shopping_style: ShoppingStyle | None = None
    age_range: AgeRange | None = None
    style_goals: list[StyleGoal] | None = None
    # Steps 2-7 of the blueprint, so a resumed flow prefills.
    style_profile: StyleProfileResponse = StyleProfileResponse()
    # Measurement progress for the Today resume banner (CTO doc 2 Screen 5).
    # Measurements left the onboarding chain in the 7-step redesign — they're
    # now entered from the Shop/Profile tabs — but the banner still reports
    # 0-8 fields saved; next id is None once the 7 required are in (weight is
    # optional and never blocks completion).
    measurement_steps_completed: int = 0
    next_incomplete_step: str | None = None


class ProfileStepResponse(BaseModel):
    """Returned by each /profile/* mutation: confirms persisted state + next route."""

    success: bool = True
    next_step: OnboardingStep
