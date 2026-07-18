"""Phase 5c — wardrobe items service.

Tenant isolation is non-negotiable: every read/write is scoped to user.id and
returns a domain `WardrobeError("not_found", ...)` rather than raw 404s, so
the route layer can map cleanly. Cross-user access is impossible to express
through this API surface — there's no item-by-id-without-user lookup.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional
from uuid import UUID

import structlog
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from sqlalchemy import select  # noqa: F401  -- used below

from app.db.models import User, WardrobeItem, WardrobeWearLog
from app.schemas.wardrobe import (
    LogWornRequest,
    WardrobeItemCreate,
    WardrobeItemUpdate,
    WardrobeListQuery,
)
from app.services import starter_wardrobe_service
from app.services.providers.image.base import ImageStorageProvider

# CTO doc: max 4 photos per item.
MAX_IMAGES_PER_ITEM = 4

# CTO doc 3 §"Free tier" — 30 real (non-starter) items free; Pro unlimited.
FREE_TIER_REAL_ITEM_LIMIT = 30

_log = structlog.get_logger("wardrobe")


class WardrobeError(Exception):
    """Domain-level wardrobe failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _today() -> date:
    return _now().date()


def _compute_cost_per_wear(price: Optional[float], worn_count: int) -> Optional[float]:
    if price is None or worn_count <= 0:
        return None
    return round(float(price) / worn_count, 2)


def _get_owned(db: Session, *, user: User, item_id: UUID) -> WardrobeItem:
    item = db.scalar(
        select(WardrobeItem).where(
            WardrobeItem.id == item_id, WardrobeItem.user_id == user.id
        )
    )
    if item is None:
        raise WardrobeError("not_found", "Wardrobe item not found")
    return item


def list_for_user(
    db: Session, *, user: User, query: WardrobeListQuery
) -> tuple[list[WardrobeItem], int]:
    base = select(WardrobeItem).where(WardrobeItem.user_id == user.id)
    if query.category is not None:
        base = base.where(WardrobeItem.category == query.category)
    if query.is_favorite is not None:
        base = base.where(WardrobeItem.is_favorite.is_(query.is_favorite))
    if query.is_starter_wardrobe is not None:
        base = base.where(WardrobeItem.is_starter_wardrobe.is_(query.is_starter_wardrobe))

    total = db.scalar(
        select(func.count()).select_from(base.subquery())
    ) or 0

    rows = (
        db.scalars(
            base.order_by(WardrobeItem.created_at.desc())
            .limit(query.limit)
            .offset(query.offset)
        )
        .all()
    )
    return list(rows), int(total)


def _real_item_count(db: Session, *, user_id: UUID) -> int:
    return int(
        db.scalar(
            select(func.count(WardrobeItem.id)).where(
                WardrobeItem.user_id == user_id,
                WardrobeItem.is_starter_wardrobe.is_(False),
            )
        )
        or 0
    )


def _enforce_free_item_limit(db: Session, *, user: User) -> None:
    """Free tier caps real wardrobe items at FREE_TIER_REAL_ITEM_LIMIT. Starter
    items don't count — they exist whether the user invited them or not."""
    if (user.subscription_tier or "free") == "pro":
        return
    real = _real_item_count(db, user_id=user.id)
    if real >= FREE_TIER_REAL_ITEM_LIMIT:
        raise WardrobeError(
            "limit_reached",
            f"Free-tier wardrobe is capped at {FREE_TIER_REAL_ITEM_LIMIT} real items "
            f"(you have {real}). Upgrade to Zoura Pro for unlimited storage.",
        )


def create_item(
    db: Session, *, user: User, payload: WardrobeItemCreate
) -> WardrobeItem:
    _enforce_free_item_limit(db, user=user)
    item = WardrobeItem(
        user_id=user.id,
        added_via="manual",
        worn_count=0,
        is_favorite=False,
        is_starter_wardrobe=False,
        **payload.model_dump(),
    )
    item.cost_per_wear = _compute_cost_per_wear(payload.purchase_price, 0)
    db.add(item)
    db.flush()
    starter_wardrobe_service.recompute_transition(db, user=user)
    db.commit()
    db.refresh(item)
    _log.info(
        "wardrobe.item.created",
        user_id=str(user.id),
        item_id=str(item.id),
        category=item.category,
    )
    return item


def get_item(db: Session, *, user: User, item_id: UUID) -> WardrobeItem:
    return _get_owned(db, user=user, item_id=item_id)


def update_item(
    db: Session, *, user: User, item_id: UUID, payload: WardrobeItemUpdate
) -> WardrobeItem:
    item = _get_owned(db, user=user, item_id=item_id)
    changes = payload.model_dump(exclude_unset=True)
    for k, v in changes.items():
        setattr(item, k, v)
    if "purchase_price" in changes:
        item.cost_per_wear = _compute_cost_per_wear(item.purchase_price, item.worn_count)
    db.commit()
    db.refresh(item)
    _log.info(
        "wardrobe.item.updated",
        user_id=str(user.id),
        item_id=str(item.id),
        fields=list(changes.keys()),
    )
    return item


def delete_item(db: Session, *, user: User, item_id: UUID) -> None:
    item = _get_owned(db, user=user, item_id=item_id)
    db.delete(item)
    db.flush()
    starter_wardrobe_service.recompute_transition(db, user=user)
    db.commit()
    _log.info("wardrobe.item.deleted", user_id=str(user.id), item_id=str(item_id))


def log_worn(
    db: Session, *, user: User, item_id: UUID, payload: LogWornRequest
) -> tuple[WardrobeItem, bool]:
    """Idempotent per (user, item, day): logging the same item twice on the
    same day is a no-op for worn_count but still returns the current row."""
    item = _get_owned(db, user=user, item_id=item_id)
    when = payload.worn_date or _today()
    log_row = WardrobeWearLog(
        user_id=user.id, item_id=item.id, worn_date=when, logged_at=_now()
    )
    db.add(log_row)
    already = False
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        already = True

    if not already:
        item.worn_count += 1
        # last_worn tracks the most recent date, regardless of order of inserts.
        if item.last_worn is None or when > item.last_worn:
            item.last_worn = when
        item.cost_per_wear = _compute_cost_per_wear(item.purchase_price, item.worn_count)
    db.commit()
    db.refresh(item)
    _log.info(
        "wardrobe.item.worn",
        user_id=str(user.id),
        item_id=str(item.id),
        worn_date=str(when),
        already_logged_today=already,
    )
    return item, already


def add_images(
    db: Session,
    *,
    user: User,
    item_id: UUID,
    uploads: list[tuple[bytes, str]],
    storage: ImageStorageProvider,
) -> WardrobeItem:
    """Persist `uploads` (each `(bytes, content_type)`) to image storage and
    append the resulting URLs to `wardrobe_items.images`. Sets `primary_image_url`
    if the item had none. Caps total images at MAX_IMAGES_PER_ITEM."""
    item = _get_owned(db, user=user, item_id=item_id)
    existing = list(item.images or [])
    if len(existing) + len(uploads) > MAX_IMAGES_PER_ITEM:
        raise WardrobeError(
            "too_many_images",
            f"At most {MAX_IMAGES_PER_ITEM} images per item "
            f"(have {len(existing)}, trying to add {len(uploads)}).",
        )
    new_urls: list[str] = []
    for content, content_type in uploads:
        url = storage.upload(
            content=content,
            content_type=content_type,
            key_hint=f"wardrobe/{user.id}/{item.id}",
        )
        new_urls.append(url)
    item.images = existing + new_urls
    if not item.primary_image_url and new_urls:
        item.primary_image_url = new_urls[0]
    db.commit()
    db.refresh(item)
    _log.info(
        "wardrobe.item.images_added",
        user_id=str(user.id),
        item_id=str(item.id),
        added=len(new_urls),
        total=len(item.images or []),
    )
    return item


def toggle_favorite(
    db: Session, *, user: User, item_id: UUID
) -> WardrobeItem:
    item = _get_owned(db, user=user, item_id=item_id)
    item.is_favorite = not item.is_favorite
    item.favorited_at = _now() if item.is_favorite else None
    db.commit()
    db.refresh(item)
    _log.info(
        "wardrobe.item.favorited",
        user_id=str(user.id),
        item_id=str(item.id),
        is_favorite=item.is_favorite,
    )
    return item
