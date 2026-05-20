"""Hand-rolled test data builders. Composable with `make_user` from conftest.

Kept hand-written instead of using `factory_boy` so collaborators don't need
another dependency to read the tests. If the suite grows past ~20 builders,
revisit factory_boy.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models import (
    Outfit,
    User,
    WardrobeItem,
)


def make_wardrobe_item(
    db: Session,
    user: User,
    *,
    name: str = "Test Item",
    category: str = "tops",
    color_name: str | None = "white",
    formality: str | None = "casual",
    purchase_price: float | None = None,
    is_starter_wardrobe: bool = False,
    worn_count: int = 0,
) -> WardrobeItem:
    item = WardrobeItem(
        user_id=user.id,
        name=name,
        category=category,
        color_name=color_name,
        formality=formality,
        purchase_price=purchase_price,
        worn_count=worn_count,
        is_favorite=False,
        is_starter_wardrobe=is_starter_wardrobe,
        added_via="manual" if not is_starter_wardrobe else "starter_seed",
    )
    if purchase_price is not None and worn_count > 0:
        item.cost_per_wear = round(float(purchase_price) / worn_count, 2)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def make_starter_wardrobe(db: Session, user: User, *, count: int = 9) -> list[WardrobeItem]:
    """Quick path: drops `count` plausible starter items into the user's wardrobe
    without going through the template-assignment service. Use when a test
    needs a populated wardrobe but doesn't care about the assignment row."""
    categories = ["tops", "bottoms", "shoes", "outerwear"]
    items: list[WardrobeItem] = []
    for i in range(count):
        items.append(
            make_wardrobe_item(
                db,
                user,
                name=f"Starter Item {i}",
                category=categories[i % len(categories)],
                color_name=["white", "black", "navy", "beige"][i % 4],
                formality=["casual", "smart_casual", "formal"][i % 3],
                is_starter_wardrobe=True,
            )
        )
    return items


def make_outfit(
    db: Session,
    user: User,
    *,
    occasion: str = "work",
    items: list[WardrobeItem] | None = None,
    compatibility_score: int = 80,
    is_logged: bool = False,
) -> Outfit:
    """Persist an outfit with a denormalized item snapshot. Caller can pass
    real wardrobe items or rely on a placeholder shape."""
    item_payload: list[dict[str, Any]] = []
    if items:
        for it in items:
            item_payload.append(
                {
                    "item_id": str(it.id),
                    "name": it.name,
                    "category": it.category,
                    "primary_image_url": it.primary_image_url,
                    "color_name": it.color_name,
                    "formality": it.formality,
                    "why_it_works": None,
                    "is_starter_wardrobe": it.is_starter_wardrobe,
                }
            )
    outfit = Outfit(
        user_id=user.id,
        occasion=occasion,
        items=item_payload,
        ai_reasoning_short="Test reasoning short.",
        ai_reasoning_full="Test reasoning full text — three sentences worth.",
        compatibility_score=compatibility_score,
        weather_context=None,
        using_starter_wardrobe=any(i.is_starter_wardrobe for i in (items or [])),
        generation_method="anthropic_v1",
        is_logged=is_logged,
        logged_at=datetime.now(timezone.utc) if is_logged else None,
        worn_count=1 if is_logged else 0,
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    return outfit
