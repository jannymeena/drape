"""Phase 5a — profile setup service.

The onboarding step machine lives here. A single source of truth (`_NEXT`)
maps each step to the one that follows it; routes never hardcode transitions.

Phase 5b will extend `_NEXT` to chain through the 8 measurement steps and
into avatar generation. Until that lands, `pre_measurement_intro` is the
last step the user can reach via this service.
"""
from __future__ import annotations

import structlog
from sqlalchemy.orm import Session

from app.db.models import User
from app.schemas.profile import (
    OnboardingStatusResponse,
    OnboardingStep,
    ProfileAgeRangeRequest,
    ProfileShoppingStyleRequest,
    ProfileStyleGoalsRequest,
    SaveProgressRequest,
)

_log = structlog.get_logger("profile")


# Linear flow per CTO_Handoff_Onboarding_Flow.md §Cat 3 → §Cat 4 → §Cat 5.
# Profile setup (5a) → measurements (5b) → avatar (5c). Save-progress reads
# from this map to compute "where to resume" — bulk submit endpoints overwrite
# onboarding_last_step directly when they finish.
_NEXT: dict[str, OnboardingStep] = {
    "shopping_style_selection": "age_range",
    "age_range": "style_goals",
    "style_goals": "pre_measurement_intro",
    "pre_measurement_intro": "measurements_step_1",
    "measurements_step_1": "measurements_step_2",
    "measurements_step_2": "measurements_step_3",
    "measurements_step_3": "measurements_step_4",
    "measurements_step_4": "measurements_step_5",
    "measurements_step_5": "measurements_step_6",
    "measurements_step_6": "measurements_step_7",
    "measurements_step_7": "measurements_step_8",
    "measurements_step_8": "avatar_reveal",
    "avatar_reveal": "today_dashboard",
}

_FIRST_STEP: OnboardingStep = "shopping_style_selection"
_DASHBOARD: OnboardingStep = "today_dashboard"


class ProfileError(Exception):
    """Domain-level profile failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def next_step(user: User) -> OnboardingStep:
    """Where the client should send the user next."""
    if user.onboarding_completed:
        return _DASHBOARD
    last = user.onboarding_last_step
    if last is None:
        return _FIRST_STEP
    # If we've recorded a step name we don't know how to continue from
    # (e.g. a Phase 5b step before 5b has shipped), fall back to dashboard
    # rather than 500 — the client can recover.
    return _NEXT.get(last, _DASHBOARD)


def _advance(user: User, completed_step: str) -> OnboardingStep:
    user.onboarding_last_step = completed_step
    return _NEXT.get(completed_step, _DASHBOARD)


def set_shopping_style(
    db: Session, *, user: User, payload: ProfileShoppingStyleRequest
) -> OnboardingStep:
    user.shopping_style = payload.shopping_style
    nxt = _advance(user, "shopping_style_selection")
    db.commit()
    _log.info("profile.shopping_style.set", user_id=str(user.id), value=payload.shopping_style)
    return nxt


def set_age_range(
    db: Session, *, user: User, payload: ProfileAgeRangeRequest
) -> OnboardingStep:
    # age_range is optional — a None payload still advances the step.
    user.age_range = payload.age_range
    nxt = _advance(user, "age_range")
    db.commit()
    _log.info(
        "profile.age_range.set",
        user_id=str(user.id),
        value=payload.age_range,
        skipped=payload.age_range is None,
    )
    return nxt


def set_style_goals(
    db: Session, *, user: User, payload: ProfileStyleGoalsRequest
) -> OnboardingStep:
    # De-dup while preserving order — clients sometimes double-tap a chip.
    seen: dict[str, None] = {}
    for goal in payload.style_goals:
        seen.setdefault(goal, None)
    user.style_goals = list(seen.keys())
    nxt = _advance(user, "style_goals")
    db.commit()
    _log.info("profile.style_goals.set", user_id=str(user.id), count=len(user.style_goals))
    return nxt


def save_progress(
    db: Session, *, user: User, payload: SaveProgressRequest
) -> OnboardingStep:
    """Record where the user paused. Doesn't write any domain fields —
    just snapshots the step pointer so the next session resumes there."""
    user.onboarding_last_step = payload.last_completed_step
    db.commit()
    _log.info(
        "profile.progress.saved",
        user_id=str(user.id),
        last_step=payload.last_completed_step,
    )
    return next_step(user)


def get_status(user: User) -> OnboardingStatusResponse:
    return OnboardingStatusResponse(
        onboarding_completed=user.onboarding_completed,
        onboarding_last_step=user.onboarding_last_step,
        next_step=next_step(user),
        shopping_style=user.shopping_style,
        age_range=user.age_range,
        style_goals=user.style_goals,
    )
