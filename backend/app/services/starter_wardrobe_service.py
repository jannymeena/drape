"""Phase 5d — starter wardrobe assignment, built from AWIN products.

Brand-new users have no items, so outfit generation has nothing to draw on.
Assigning a starter wardrobe picks a capsule of tagged catalog products in the
user's genders and materializes them into the wardrobe with
`is_starter_wardrobe=true` and a `product_id` link (price + buy link). They
generate outfits like any other item; the user doesn't own them, so outfits
using them are "shop the look". As the user adds their own pieces, the
transition-tracking row shifts the blending ratio so generation favours real
items; at AUTO_DEACTIVATE_REAL_ITEMS the starter assignment auto-deactivates.

Capsule selection is deterministic in shape (a per-gender role mix) and
greedy in content: each pick favours occasions, warmths and colours the
capsule doesn't cover yet, so a small capsule still dresses work, casual and
date night across the weather.
"""
from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import (
    Product,
    User,
    UserStarterWardrobe,
    WardrobeItem,
    WardrobeTransitionTracking,
)
from app.services import catalog_service

_log = structlog.get_logger("starter_wardrobe")


# Threshold at which a user's starter wardrobe auto-deactivates.
#
# 10, not 15. The handoff docs disagree — CTO doc 2 (Today tab) says 15, doc 3
# (Wardrobe tab) says 10 — and 10 is the number every other part of the system
# already uses: the client banner counts down to it ("n/10 ITEMS TO UNLOCK REAL
# WARDROBE MODE"), doc 3's banner logic hides at `real_items >= 10`, and
# `outfit_service._blend_pool` switches to real-only at 10. Deactivating at 15
# meant the app promised a threshold it then refused to honour.
AUTO_DEACTIVATE_REAL_ITEMS = 10


class StarterWardrobeError(Exception):
    """Domain-level starter-wardrobe failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _now() -> datetime:
    return datetime.now(timezone.utc)


# Response slug for the (single) capsule kind; the client shows it verbatim.
CAPSULE_ID = "awin_capsule"

# Pieces per role. Men's feeds carry no shoes — their own shoes join outfits
# once uploaded. "both" (or no answer) mixes the two catalogs.
_CAPSULE_SHAPE: dict[str, dict[str, int]] = {
    "mens": {"top": 4, "bottom": 3, "outerwear": 2, "accessory": 1},
    "womens": {"top": 3, "bottom": 2, "dress": 2, "outerwear": 2, "shoes": 1, "accessory": 1},
    "both": {"top": 3, "bottom": 2, "dress": 1, "outerwear": 2, "shoes": 1, "accessory": 1},
}

_SEASONS_BY_WARMTH = {
    "light": ["spring", "summer"],
    "mid": ["spring", "fall"],
    "heavy": ["fall", "winter"],
}


def _capsule_shape(user: User) -> dict[str, int]:
    return _CAPSULE_SHAPE.get(user.shopping_style or "", _CAPSULE_SHAPE["both"])


def _pick_capsule(products: list[Product], shape: dict[str, int]) -> list[Product]:
    """Greedy per role: each pick maximises newly covered occasions (x2),
    warmths and colours; random tie-break so users don't all get the same kit."""
    by_role: dict[str, list[Product]] = {}
    for p in products:
        by_role.setdefault(p.role or "", []).append(p)
    occasions: set[str] = set()
    warmths: set[str] = set()
    colours: set[str] = set()
    picked: list[Product] = []
    for role, count in shape.items():
        pool = list(by_role.get(role, []))
        random.shuffle(pool)
        for _ in range(count):
            if not pool:
                break
            best = max(
                pool,
                key=lambda p: (
                    2 * len(set(p.occasions or []) - occasions)
                    + (p.warmth not in warmths)
                    + ((p.color_name or "").lower() not in colours)
                ),
            )
            pool.remove(best)
            picked.append(best)
            occasions.update(best.occasions or [])
            warmths.add(best.warmth or "")
            colours.add((best.color_name or "").lower())
    return picked


def _capsule_is_wearable(picked: list[Product]) -> bool:
    roles = [p.role for p in picked]
    return roles.count("top") >= 2 and ("bottom" in roles or "dress" in roles)


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
    db: Session, *, user: User, products: list[Product]
) -> list[WardrobeItem]:
    rows = [
        WardrobeItem(
            user_id=user.id,
            name=catalog_service.display_name(p),
            category=catalog_service.CATEGORY_BY_ROLE.get(p.role or "", p.category),
            images=[p.image_url],
            primary_image_url=p.image_url,
            color_name=p.color_name,
            formality=p.formality,
            season=_SEASONS_BY_WARMTH.get(p.warmth or ""),
            brand=p.brand,
            worn_count=0,
            is_favorite=False,
            is_starter_wardrobe=True,
            product_id=p.id,
            added_via="starter_seed",
        )
        for p in products
    ]
    db.add_all(rows)
    return rows


def _delete_starter_items(db: Session, *, user_id: UUID) -> int:
    """Used when re-picking the capsule. Returns the count deleted."""
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
    auto-deactivates the active starter wardrobe at AUTO_DEACTIVATE_REAL_ITEMS.
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
    db: Session, *, user: User
) -> tuple[UserStarterWardrobe, list[WardrobeItem], bool]:
    """Pick a capsule of catalog products and materialize it.

    Idempotency rules:
      - No prior assignment        -> create + materialize.
      - Prior assignment, 0 real   -> re-pick (delete old starter items,
                                       reactivate, re-materialize).
      - Prior assignment, >=1 real -> no-op; return existing assignment.
        (Swapping the kit after the user has personalized their wardrobe
        would silently mutate items they may have ranked or worn.)

    Raises StarterWardrobeError("catalog_not_ready") while too few products
    are tagged for the user's genders to dress anyone (right after a fresh
    catalog sync — the worker tags them within minutes).

    Returns (assignment, materialized_items, swapped). `materialized_items` is
    empty on the no-op path; `swapped` reports whether the assignment row was
    changed/created in this call.
    """
    existing = get_assignment(db, user_id=user.id)
    real = real_item_count(db, user_id=user.id)

    if existing is not None and real >= 1:
        # User has already added real items; preserve their state.
        recompute_transition(db, user=user)
        db.commit()
        _log.info("starter_wardrobe.assign.noop", user_id=str(user.id), real_items=real)
        return existing, [], False

    picked = _pick_capsule(catalog_service.tagged_products(db, user=user), _capsule_shape(user))
    if not _capsule_is_wearable(picked):
        raise StarterWardrobeError(
            "catalog_not_ready",
            "The starter wardrobe is still being prepared — try again in a few minutes.",
        )

    if existing is not None:
        # 0 real items: clear old starter items and re-pick.
        _delete_starter_items(db, user_id=user.id)
        existing.is_active = True
        existing.assigned_at = _now()
        existing.deactivated_at = None
        existing.deactivation_reason = None
        assignment = existing
    else:
        assignment = UserStarterWardrobe(
            user_id=user.id,
            is_active=True,
            assigned_at=_now(),
        )
        db.add(assignment)

    items = _materialize_items(db, user=user, products=picked)
    db.flush()
    recompute_transition(db, user=user)
    db.commit()
    db.refresh(assignment)
    for item in items:
        db.refresh(item)

    _log.info(
        "starter_wardrobe.assigned",
        user_id=str(user.id),
        shopping_style=user.shopping_style,
        items=len(items),
    )
    return assignment, items, True


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
