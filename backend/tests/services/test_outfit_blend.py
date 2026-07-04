"""_blend_pool — CTO doc 2 starter->real transition thresholds."""
from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from app.db.models import WardrobeItem
from app.services.outfit_service import _blend_pool


def _item(starter: bool) -> WardrobeItem:
    return WardrobeItem(
        id=uuid4(),
        user_id=uuid4(),
        name="x",
        category="tops",
        is_starter_wardrobe=starter,
        added_via="manual",
        created_at=datetime(2026, 1, 1),
        updated_at=datetime(2026, 1, 1),
    )


def _pool(real: int, starter: int) -> list[WardrobeItem]:
    return [_item(False) for _ in range(real)] + [_item(True) for _ in range(starter)]


def _counts(pool: list[WardrobeItem]) -> tuple[int, int]:
    blended = _blend_pool(pool)
    real = sum(1 for i in blended if not i.is_starter_wardrobe)
    starter = sum(1 for i in blended if i.is_starter_wardrobe)
    return real, starter


def test_zero_real_uses_starter_only():
    assert _counts(_pool(0, 14)) == (0, 14)


def test_few_real_keeps_all_real_plus_up_to_ten_starter():
    assert _counts(_pool(3, 14)) == (3, 10)


def test_mid_real_keeps_all_real_plus_up_to_four_starter():
    assert _counts(_pool(7, 14)) == (7, 4)


def test_ten_plus_real_drops_starter_entirely():
    assert _counts(_pool(10, 14)) == (10, 0)


def test_no_starter_items_is_a_noop():
    pool = _pool(2, 0)
    assert _blend_pool(pool) == pool
