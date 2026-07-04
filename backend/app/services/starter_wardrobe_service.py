"""Phase 5d — starter wardrobe assignment.

Brand-new users have no items, so outfit generation has nothing to draw on.
Assigning a starter wardrobe materializes a template's items into the user's
wardrobe with `is_starter_wardrobe=true`, giving the AI something to work with
on day one. As the user adds their own pieces, the transition-tracking row
shifts the blending ratio so generation favours real items; once 15 real items
exist the starter assignment auto-deactivates.

Template selection is a deterministic mapping over (shopping_style, age_range)
— no AI in the loop. Falls back to `neutral_default` when either field is
missing or doesn't have a dedicated template (e.g. women 45+ get the 35-44
"refined" capsule, which holds up across the older bands).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import (
    StarterWardrobeTemplate,
    User,
    UserStarterWardrobe,
    WardrobeItem,
    WardrobeTransitionTracking,
)

_log = structlog.get_logger("starter_wardrobe")


# Threshold at which a user's starter wardrobe auto-deactivates. CTO doc 3
# specifies 15 — past this point the user's real wardrobe carries outfit gen.
AUTO_DEACTIVATE_REAL_ITEMS = 15


class StarterWardrobeError(Exception):
    """Domain-level starter-wardrobe failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _now() -> datetime:
    return datetime.now(timezone.utc)


# (shopping_style, age_range) -> template_id. Missing/unknown keys fall through
# to neutral_default. Tuples are exhaustive over the values in
# app/schemas/profile.py — anything outside that set means an upstream typo.
_TEMPLATE_MAP: dict[tuple[Optional[str], Optional[str]], str] = {
    ("womens", "18-24"): "women_18_24_versatile",
    ("womens", "25-34"): "women_25_34_polished",
    ("womens", "35-44"): "women_35_44_refined",
    ("womens", "45-54"): "women_35_44_refined",
    ("womens", "55+"): "women_35_44_refined",
    ("mens", "18-24"): "men_18_24_versatile",
    ("mens", "25-34"): "men_25_34_polished",
    ("mens", "35-44"): "men_25_34_polished",
    ("mens", "45-54"): "men_25_34_polished",
    ("mens", "55+"): "men_25_34_polished",
}
_FALLBACK_TEMPLATE = "neutral_default"


def _pick_template_id(user: User) -> str:
    return _TEMPLATE_MAP.get((user.shopping_style, user.age_range), _FALLBACK_TEMPLATE)


def list_active_templates(db: Session) -> list[StarterWardrobeTemplate]:
    return list(
        db.scalars(
            select(StarterWardrobeTemplate)
            .where(StarterWardrobeTemplate.is_active.is_(True))
            .order_by(StarterWardrobeTemplate.template_id)
        ).all()
    )


def _get_template(
    db: Session, *, template_id: Optional[str] = None, override_uuid: Optional[UUID] = None
) -> StarterWardrobeTemplate:
    stmt = select(StarterWardrobeTemplate)
    if override_uuid is not None:
        stmt = stmt.where(StarterWardrobeTemplate.id == override_uuid)
    elif template_id is not None:
        stmt = stmt.where(StarterWardrobeTemplate.template_id == template_id)
    else:
        raise StarterWardrobeError("invalid_request", "Template lookup needs an id")
    template = db.scalar(stmt)
    if template is None:
        raise StarterWardrobeError("template_not_found", "Starter wardrobe template not found")
    if not template.is_active:
        raise StarterWardrobeError("template_inactive", "Starter wardrobe template is inactive")
    return template


def real_item_count(db: Session, *, user_id: UUID) -> int:
    return int(
        db.scalar(
            select(func.count(WardrobeItem.id)).where(
                WardrobeItem.user_id == user_id,
                WardrobeItem.is_starter_wardrobe.is_(False),
            )
        )
        or 0
    )


def _starter_item_count(db: Session, *, user_id: UUID) -> int:
    return int(
        db.scalar(
            select(func.count(WardrobeItem.id)).where(
                WardrobeItem.user_id == user_id,
                WardrobeItem.is_starter_wardrobe.is_(True),
            )
        )
        or 0
    )


def _materialize_items(
    db: Session, *, user: User, template: StarterWardrobeTemplate
) -> list[WardrobeItem]:
    rows: list[WardrobeItem] = []
    for spec in template.items:
        rows.append(
            WardrobeItem(
                user_id=user.id,
                name=spec["name"],
                category=spec["category"],
                subcategory=spec.get("subcategory"),
                images=spec.get("images"),
                primary_image_url=spec.get("primary_image_url"),
                color_hex=spec.get("color_hex"),
                color_name=spec.get("color_name"),
                pattern=spec.get("pattern"),
                material=spec.get("material"),
                formality=spec.get("formality"),
                season=spec.get("season"),
                brand=spec.get("brand"),
                description=spec.get("description"),
                worn_count=0,
                is_favorite=False,
                is_starter_wardrobe=True,
                starter_template_id=template.id,
                added_via="starter_seed",
            )
        )
    db.add_all(rows)
    return rows


def _delete_starter_items(db: Session, *, user_id: UUID) -> int:
    """Used during template swaps. Returns the count deleted."""
    rows = db.scalars(
        select(WardrobeItem).where(
            WardrobeItem.user_id == user_id,
            WardrobeItem.is_starter_wardrobe.is_(True),
        )
    ).all()
    for row in rows:
        db.delete(row)
    return len(rows)


def get_assignment(db: Session, *, user_id: UUID) -> Optional[UserStarterWardrobe]:
    return db.scalar(
        select(UserStarterWardrobe).where(UserStarterWardrobe.user_id == user_id)
    )


def get_or_create_transition_row(
    db: Session, *, user_id: UUID
) -> WardrobeTransitionTracking:
    row = db.scalar(
        select(WardrobeTransitionTracking).where(
            WardrobeTransitionTracking.user_id == user_id
        )
    )
    if row is not None:
        return row
    row = WardrobeTransitionTracking(
        user_id=user_id,
        real_items_count=0,
        starter_items_count=0,
        percentage_real=0,
        blending_ratio=1.0,
        last_updated=_now(),
    )
    db.add(row)
    db.flush()
    return row


def recompute_transition(
    db: Session, *, user: User
) -> WardrobeTransitionTracking:
    """Re-counts items and updates the user's transition row.

    Called from wardrobe_service.create_item / delete_item via the
    `on_wardrobe_change` hook (Phase 5d) and from `assign` here. Also
    auto-deactivates the active starter wardrobe once real items >= 15.
    """
    row = get_or_create_transition_row(db, user_id=user.id)
    real = real_item_count(db, user_id=user.id)
    starter = _starter_item_count(db, user_id=user.id)
    total = real + starter
    pct_real = (real / total * 100.0) if total > 0 else 0.0
    # Blending ratio: starter share of the wardrobe. Drops linearly with real
    # adoption; outfit generation will use this to bias item selection.
    ratio = (starter / total) if total > 0 else 1.0

    row.real_items_count = real
    row.starter_items_count = starter
    row.percentage_real = round(pct_real, 2)
    row.blending_ratio = round(ratio, 2)
    row.last_updated = _now()

    if real >= AUTO_DEACTIVATE_REAL_ITEMS:
        assignment = get_assignment(db, user_id=user.id)
        if assignment is not None and assignment.is_active:
            assignment.is_active = False
            assignment.deactivated_at = _now()
            assignment.deactivation_reason = "user_has_enough_items"
            _log.info(
                "starter_wardrobe.auto_deactivated",
                user_id=str(user.id),
                real_items=real,
            )
    return row


def assign(
    db: Session,
    *,
    user: User,
    template_id: Optional[str] = None,
) -> tuple[UserStarterWardrobe, StarterWardrobeTemplate, list[WardrobeItem], bool]:
    """Pick a template (auto or explicit) and materialize starter items.

    Idempotency rules:
      - No prior assignment        -> create + materialize.
      - Prior assignment, 0 real   -> swap template (delete old starter items,
                                       reassign, re-materialize).
      - Prior assignment, >=1 real -> no-op; return existing assignment.
        (Swapping templates after the user has personalized their wardrobe
        would silently mutate items they may have ranked or worn.)

    Returns (assignment, template, materialized_items, swapped).
    `materialized_items` is empty on the no-op path; `swapped` reports whether
    the assignment row was changed/created in this call.
    """
    chosen_template_id = template_id or _pick_template_id(user)
    template = _get_template(db, template_id=chosen_template_id)

    existing = get_assignment(db, user_id=user.id)
    real = real_item_count(db, user_id=user.id)

    if existing is not None and real >= 1:
        # User has already added real items; preserve their state.
        recompute_transition(db, user=user)
        db.commit()
        _log.info(
            "starter_wardrobe.assign.noop",
            user_id=str(user.id),
            existing_template_id=str(existing.template_id),
            real_items=real,
        )
        return existing, template, [], False

    if existing is not None:
        # 0 real items: clear old starter items and swap.
        _delete_starter_items(db, user_id=user.id)
        existing.template_id = template.id
        existing.is_active = True
        existing.assigned_at = _now()
        existing.deactivated_at = None
        existing.deactivation_reason = None
        assignment = existing
    else:
        assignment = UserStarterWardrobe(
            user_id=user.id,
            template_id=template.id,
            is_active=True,
            assigned_at=_now(),
        )
        db.add(assignment)

    items = _materialize_items(db, user=user, template=template)
    db.flush()
    recompute_transition(db, user=user)
    db.commit()
    db.refresh(assignment)
    for item in items:
        db.refresh(item)

    _log.info(
        "starter_wardrobe.assigned",
        user_id=str(user.id),
        template_id=template.template_id,
        items=len(items),
    )
    return assignment, template, items, True


def deactivate(
    db: Session, *, user: User, reason: str = "manual"
) -> UserStarterWardrobe:
    assignment = get_assignment(db, user_id=user.id)
    if assignment is None:
        raise StarterWardrobeError(
            "not_assigned", "User has no starter wardrobe to deactivate"
        )
    if not assignment.is_active:
        # Idempotent: deactivating an already-inactive assignment returns the
        # current row without altering it. Avoids 4xx for race-style retries.
        return assignment
    assignment.is_active = False
    assignment.deactivated_at = _now()
    assignment.deactivation_reason = reason
    db.commit()
    db.refresh(assignment)
    _log.info(
        "starter_wardrobe.deactivated",
        user_id=str(user.id),
        reason=reason,
    )
    return assignment
