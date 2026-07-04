"""Phase 5a — profile setup request/response shapes.

The Literal types here are the source of truth for accepted values; the DB
columns (`users.shopping_style`, `users.age_range`) are plain VARCHAR so we
can extend the value set without a migration. If you add a new age band or
style goal, update the Literal here and clients will get a 422 for stale
values until they upgrade.
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
OnboardingStep = Literal[
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
    "today_dashboard",
]


class ProfileShoppingStyleRequest(BaseModel):
    shopping_style: ShoppingStyle


class ProfileAgeRangeRequest(BaseModel):
    # Nullable so the client can transmit "skip this step" explicitly.
    age_range: AgeRange | None = None


class ProfileStyleGoalsRequest(BaseModel):
    style_goals: list[StyleGoal] = Field(min_length=1, max_length=10)


class SaveProgressRequest(BaseModel):
    """Records where the user paused so the next session resumes there."""

    last_completed_step: OnboardingStep


class OnboardingStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    onboarding_completed: bool
    onboarding_last_step: str | None
    next_step: OnboardingStep
    shopping_style: ShoppingStyle | None = None
    age_range: AgeRange | None = None
    style_goals: list[StyleGoal] | None = None
    # Measurement progress for the Today resume banner (CTO doc 2 Screen 5).
    # 0-8 fields saved; next id is None once the 7 required are in (weight is
    # optional and never blocks completion).
    measurement_steps_completed: int = 0
    next_incomplete_step: str | None = None


class ProfileStepResponse(BaseModel):
    """Returned by each /profile/* mutation: confirms persisted state + next route."""

    success: bool = True
    next_step: OnboardingStep
