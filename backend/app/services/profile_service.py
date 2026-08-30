"""Profile setup service — the 7-step Style Blueprint onboarding.

The onboarding step machine lives here. A single source of truth (`_NEXT`)
maps each step to the one that follows it; routes never hardcode transitions.

The flow is: seven blueprint screens (each posting one request model from
`app.schemas.profile`) → the blueprint reveal → the app. Body measurements
used to sit between style goals and the reveal; the 7-step redesign moved them
out of onboarding entirely — they're now entered from the Shop/Profile tabs
via `POST /profile/measurements`, and the measurement services no longer
participate in this chain.

Steps 2-7 write into the `users.style_profile` JSONB blob one step at a time
via `_merge_style_profile`; step 1 and step 7 also write the dedicated
`shopping_style` / `age_range` / `style_goals` columns.
"""
from __future__ import annotations

import structlog
from sqlalchemy.orm import Session

from app.db.models import Profile, User
from app.services import measurements_service
from app.services.providers.crypto.base import Encryptor
from app.services.providers.image.base import ImageStorageProvider
from app.schemas.profile import (
    OnboardingStatusResponse,
    OnboardingStep,
    SaveProgressRequest,
    StyleBlueprintAestheticsRequest,
    StyleBlueprintColorRequest,
    StyleBlueprintFitRequest,
    StyleBlueprintGoalsRequest,
    StyleBlueprintHabitsRequest,
    StyleBlueprintIdentityRequest,
    StyleBlueprintLifestyleRequest,
    StyleProfileResponse,
)

_log = structlog.get_logger("profile")


# The linear blueprint flow. Save-progress reads from this map to compute
# "where to resume"; bulk submit endpoints overwrite onboarding_last_step
# directly when they finish.
_NEXT: dict[str, OnboardingStep] = {
    "style_blueprint_1": "style_blueprint_2",
    "style_blueprint_2": "style_blueprint_3",
    "style_blueprint_3": "style_blueprint_4",
    "style_blueprint_4": "style_blueprint_5",
    "style_blueprint_5": "style_blueprint_6",
    "style_blueprint_6": "style_blueprint_7",
    "style_blueprint_7": "style_blueprint_reveal",
    "style_blueprint_reveal": "today_dashboard",
}

# Pre-redesign step ids. A session that paused mid-way through the old
# 15-screen flow restarts the blueprint rather than resuming into screens that
# no longer chain — safe here because the redesign landed pre-prod, with no
# live users to strand. Remove once no stored `onboarding_last_step` uses them.
_LEGACY_STEPS: frozenset[str] = frozenset(
    {
        "shopping_style_selection",
        "age_range",
        "style_goals",
        "pre_measurement_intro",
        *(f"measurements_step_{i}" for i in range(1, 9)),
        "avatar_reveal",
    }
)

_FIRST_STEP: OnboardingStep = "style_blueprint_1"
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
    if last is None or last in _LEGACY_STEPS:
        return _FIRST_STEP
    # An unrecognized step name (a rolled-back client, a hand-edited row) falls
    # back to the dashboard rather than 500 — the client can recover.
    return _NEXT.get(last, _DASHBOARD)


def _advance(user: User, completed_step: str) -> OnboardingStep:
    user.onboarding_last_step = completed_step
    return _NEXT.get(completed_step, _DASHBOARD)


def _merge_style_profile(user: User, values: dict) -> None:
    """Merge one step's answers into `users.style_profile`.

    Rebinds the attribute rather than mutating in place — SQLAlchemy doesn't
    track in-place edits of a plain JSONB dict, so a mutation would be silently
    dropped on commit.
    """
    merged = dict(user.style_profile or {})
    merged.update(values)
    user.style_profile = merged


def _dedup(values: list[str]) -> list[str]:
    """De-dup while preserving order — clients sometimes double-tap a chip."""
    seen: dict[str, None] = {}
    for value in values:
        seen.setdefault(value, None)
    return list(seen.keys())


def set_blueprint_identity(
    db: Session, *, user: User, payload: StyleBlueprintIdentityRequest
) -> OnboardingStep:
    """Step 1 — shopping style (required) + age range (nullable = skipped)."""
    user.shopping_style = payload.shopping_style
    user.age_range = payload.age_range
    nxt = _advance(user, "style_blueprint_1")
    db.commit()
    _log.info(
        "profile.blueprint.identity",
        user_id=str(user.id),
        shopping_style=payload.shopping_style,
        age_skipped=payload.age_range is None,
    )
    return nxt


def set_blueprint_fit(
    db: Session, *, user: User, payload: StyleBlueprintFitRequest
) -> OnboardingStep:
    """Step 2 — body shape + how tops and bottoms should sit."""
    _merge_style_profile(
        user,
        {
            "body_shape": payload.body_shape,
            "fit_tops": payload.fit_tops,
            "fit_bottoms": payload.fit_bottoms,
        },
    )
    nxt = _advance(user, "style_blueprint_2")
    db.commit()
    _log.info("profile.blueprint.fit", user_id=str(user.id), shape=payload.body_shape)
    return nxt


def set_blueprint_aesthetics(
    db: Session, *, user: User, payload: StyleBlueprintAestheticsRequest
) -> OnboardingStep:
    """Step 3 — the style card grid."""
    aesthetics = _dedup(payload.style_aesthetics)
    _merge_style_profile(user, {"style_aesthetics": aesthetics})
    nxt = _advance(user, "style_blueprint_3")
    db.commit()
    _log.info(
        "profile.blueprint.aesthetics", user_id=str(user.id), count=len(aesthetics)
    )
    return nxt


def set_blueprint_color(
    db: Session, *, user: User, payload: StyleBlueprintColorRequest
) -> OnboardingStep:
    """Step 4 — undertone + preferred palettes."""
    palettes = _dedup(payload.color_palettes)
    _merge_style_profile(
        user, {"undertone": payload.undertone, "color_palettes": palettes}
    )
    nxt = _advance(user, "style_blueprint_4")
    db.commit()
    _log.info(
        "profile.blueprint.color", user_id=str(user.id), undertone=payload.undertone
    )
    return nxt


def set_blueprint_lifestyle(
    db: Session, *, user: User, payload: StyleBlueprintLifestyleRequest
) -> OnboardingStep:
    """Step 5 — work context. Occupation is free text; blank means "not given"."""
    occupation = (payload.occupation or "").strip() or None
    _merge_style_profile(
        user,
        {
            "occupation": occupation,
            "dress_code": payload.dress_code,
            "impression_goal": payload.impression_goal,
        },
    )
    nxt = _advance(user, "style_blueprint_5")
    db.commit()
    _log.info(
        "profile.blueprint.lifestyle",
        user_id=str(user.id),
        impression_goal=payload.impression_goal,
    )
    return nxt


def set_blueprint_habits(
    db: Session, *, user: User, payload: StyleBlueprintHabitsRequest
) -> OnboardingStep:
    """Step 6 — shopping attitude, accessories, brand tier."""
    _merge_style_profile(
        user,
        {
            "shopping_feeling": payload.shopping_feeling,
            "accessories": payload.accessories,
            "brand_tier": payload.brand_tier,
        },
    )
    nxt = _advance(user, "style_blueprint_6")
    db.commit()
    _log.info(
        "profile.blueprint.habits", user_id=str(user.id), brand_tier=payload.brand_tier
    )
    return nxt


def set_blueprint_goals(
    db: Session, *, user: User, payload: StyleBlueprintGoalsRequest
) -> OnboardingStep:
    """Step 7 — the 3-month aspiration plus style goals. Goals keep their own
    column (they predate the blueprint and are read by starter-wardrobe
    matching); the aspiration joins the blob."""
    user.style_goals = _dedup(payload.style_goals)
    _merge_style_profile(user, {"three_month_feeling": payload.three_month_feeling})
    nxt = _advance(user, "style_blueprint_7")
    db.commit()
    _log.info(
        "profile.blueprint.goals",
        user_id=str(user.id),
        count=len(user.style_goals),
        feeling=payload.three_month_feeling,
    )
    return nxt


def complete_blueprint(db: Session, *, user: User) -> OnboardingStep:
    """The reveal's "Build My Wardrobe" — the last step before the app."""
    nxt = _advance(user, "style_blueprint_reveal")
    db.commit()
    _log.info("profile.blueprint.revealed", user_id=str(user.id))
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


def set_avatar(
    db: Session,
    *,
    user: User,
    storage: ImageStorageProvider,
    content: bytes,
    content_type: str,
) -> str:
    """Store an uploaded avatar image and point the user's profile at it.

    The avatar lives on the 1:1 `profiles` row (get-or-created here), so a user
    who never had a profile row still gets one. Returns the fetchable URL."""
    url = storage.upload(
        content=content,
        content_type=content_type,
        key_hint=f"avatars/{user.id}",
    )
    profile = user.profile
    if profile is None:
        profile = Profile(user_id=user.id)
        db.add(profile)
    profile.avatar_url = url
    db.commit()
    _log.info("profile.avatar.set", user_id=str(user.id))
    return url


def set_body_analysis(db: Session, *, user: User, analysis: dict) -> None:
    """Persist the §5.5 body/skin analysis derived from the avatar photo onto
    the user's 1:1 profile row (get-or-created, mirroring `set_avatar`)."""
    profile = user.profile
    if profile is None:
        profile = Profile(user_id=user.id)
        db.add(profile)
    profile.body_analysis = analysis
    db.commit()
    _log.info("profile.body_analysis.set", user_id=str(user.id))


def get_status(
    db: Session, *, encryptor: Encryptor, user: User
) -> OnboardingStatusResponse:
    steps_done, next_incomplete = measurements_service.step_progress(
        db, encryptor=encryptor, user=user
    )
    return OnboardingStatusResponse(
        onboarding_completed=user.onboarding_completed,
        onboarding_last_step=user.onboarding_last_step,
        next_step=next_step(user),
        shopping_style=user.shopping_style,
        age_range=user.age_range,
        style_goals=user.style_goals,
        style_profile=StyleProfileResponse(**(user.style_profile or {})),
        measurement_steps_completed=steps_done,
        next_incomplete_step=next_incomplete,
    )
