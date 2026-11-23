"""Phase 5d — starter wardrobe assignment, built from AWIN products.

Brand-new users have no items, so outfit generation has nothing to draw on.
The starter wardrobe is everything we can offer: every active, tagged
catalog product in the user's genders (menswear, womenswear or both),
materialized into the wardrobe with `is_starter_wardrobe=true` and a
`product_id` link (price + buy link). Each piece carries its product's
occasions (tagged once per product by the catalog worker), so outfit
filtering needs no per-user classification.

It follows the catalog: after each feed sync and tagging run the catalog
worker calls `refresh_all`, which adds newly tagged products, drops pieces
whose product left the feed, and copies re-tagged fields onto the rest.

While the assignment is active the user is in starter mode: outfits come
only from these pieces (one look a day on Today, to shop), never mixed with
their own. The transition-tracking row counts real vs starter items; at
AUTO_DEACTIVATE_REAL_ITEMS the starter assignment auto-deactivates and
outfits switch to the user's own pieces.
"""
from __future__ import annotations

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
# WARDROBE MODE") and doc 3's banner logic hides at `real_items >= 10`
# (outfit generation used to switch to real-only at 10). Deactivating at 15
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

_SEASONS_BY_WARMTH = {
    "light": ["spring", "summer"],
    "mid": ["spring", "fall"],
    "heavy": ["fall", "winter"],
}


def _catalog_is_ready(products: list[Product]) -> bool:
    """Enough is tagged to dress anyone: two tops and a bottom or a dress."""
    roles = [p.role for p in products]
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


def _copy_product(item: WardrobeItem, p: Product) -> None:
    """The product's current details onto its starter piece."""
    item.name = catalog_service.display_name(p)
    item.category = catalog_service.CATEGORY_BY_ROLE.get(p.role or "", p.category)
    item.images = [p.image_url]
    item.primary_image_url = p.image_url
    item.color_name = p.color_name
    item.formality = p.formality
    item.season = _SEASONS_BY_WARMTH.get(p.warmth or "")
    item.brand = p.brand
    item.occasions = list(p.occasions) if p.occasions else None


def _materialize_items(
    db: Session, *, user: User, products: list[Product]
) -> list[WardrobeItem]:
    rows = []
    for p in products:
        row = WardrobeItem(
            user_id=user.id,
            worn_count=0,
            is_favorite=False,
            is_starter_wardrobe=True,
            product_id=p.id,
            added_via="starter_seed",
        )
        _copy_product(row, p)
        rows.append(row)
    db.add_all(rows)
    return rows


def _delete_starter_items(db: Session, *, user_id: UUID) -> int:
    """Used when re-assigning. Returns the count deleted."""
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
    """Materialize the whole catalog for the user's genders.

    Idempotency rules:
      - No prior assignment        -> create + materialize.
      - Prior assignment, 0 real   -> re-assign (delete old starter items,
                                       reactivate, re-materialize).
      - Prior assignment, >=1 real -> no-op; return existing assignment.
        (The catalog keeps it current — `refresh`.)

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

    picked = catalog_service.tagged_products(db, user=user)
    if not _catalog_is_ready(picked):
        raise StarterWardrobeError(
            "catalog_not_ready",
            "The starter wardrobe is still being prepared — try again in a few minutes.",
        )

    if existing is not None:
        # 0 real items: clear old starter items and re-assign.
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


def refresh(db: Session, *, user: User) -> tuple[int, int]:
    """Keeps an active starter wardrobe in step with the catalog: adds every
    tagged product in the user's genders it lacks, drops pieces whose
    product left the feed (inactive or deleted), and copies tagged products'
    current details onto the rest. Products being re-tagged (untagged for a
    moment) are left as they are. Returns (added, removed); commits."""
    assignment = get_assignment(db, user_id=user.id)
    if assignment is None or not assignment.is_active:
        return 0, 0
    items = list(
        db.scalars(
            select(WardrobeItem).where(
                WardrobeItem.user_id == user.id,
                WardrobeItem.is_starter_wardrobe.is_(True),
            )
        ).all()
    )
    genders = catalog_service.genders_for(user)
    held = {i.product_id for i in items if i.product_id is not None}
    products = {
        p.id: p
        for p in db.scalars(
            select(Product).where(
                Product.id.in_(held)
                | (
                    Product.is_active.is_(True)
                    & Product.tagged_at.is_not(None)
                    & Product.gender.in_(genders)
                )
            )
        ).all()
    }
    removed = 0
    for item in items:
        p = products.get(item.product_id) if item.product_id else None
        if p is None or not p.is_active or p.gender not in genders:
            db.delete(item)
            removed += 1
        elif p.tagged_at is not None:
            _copy_product(item, p)
    new = [
        p
        for pid, p in products.items()
        if pid not in held and p.is_active and p.tagged_at is not None and p.gender in genders
    ]
    new.sort(key=lambda p: p.external_id)
    _materialize_items(db, user=user, products=new)
    db.flush()
    recompute_transition(db, user=user)
    db.commit()
    if new or removed:
        _log.info(
            "starter_wardrobe.refreshed",
            user_id=str(user.id),
            added=len(new),
            removed=removed,
        )
    return len(new), removed


def refresh_all(db: Session) -> int:
    """`refresh` for every active starter wardrobe (the catalog worker, after
    a sync or a tagging run). Returns how many were refreshed."""
    users = db.scalars(
        select(User)
        .join(UserStarterWardrobe, UserStarterWardrobe.user_id == User.id)
        .where(UserStarterWardrobe.is_active.is_(True))
    ).all()
    for user in users:
        refresh(db, user=user)
    return len(users)


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
