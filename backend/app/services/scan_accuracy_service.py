"""Scan accuracy — how often users correct what the vision model said.

Every scanned item keeps the scanner's untouched answer in
`wardrobe_items.ai_detection` (with the model id). A field counts as
corrected when the item's current value differs from the AI's, whether the
user fixed it on the scan review screen or later via Edit. Grouped by model,
so a cheap vision model can be judged against a stronger one on real photos.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import WardrobeItem

# AI detection key -> WardrobeItem attribute holding the user's final value.
FIELDS: dict[str, str] = {
    "category": "category",
    "color": "color_name",
    "pattern": "pattern",
    "formality": "formality",
}


@dataclass
class ModelAccuracy:
    model: str
    items: int = 0
    # Items where at least one field was corrected.
    any_corrected: int = 0
    corrected: dict[str, int] = field(default_factory=lambda: dict.fromkeys(FIELDS, 0))

    def accuracy(self, key: str) -> float:
        """Share of items where the AI's value for `key` was kept (0-1)."""
        return 1 - self.corrected[key] / self.items if self.items else 0.0


def _norm(value: object) -> str:
    return str(value).strip().lower() if value is not None else ""


def corrected_fields(item: WardrobeItem) -> list[str]:
    """Detection keys whose value the user changed on this item."""
    detection = item.ai_detection or {}
    return [
        key
        for key, attr in FIELDS.items()
        if _norm(detection.get(key)) != _norm(getattr(item, attr))
    ]


def scan_accuracy(db: Session, *, since: Optional[datetime] = None) -> list[ModelAccuracy]:
    """Per-model correction counts over every scanned item (all users),
    optionally only items created at/after `since`. Most-used model first."""
    query = select(WardrobeItem).where(WardrobeItem.ai_detection.is_not(None))
    if since is not None:
        query = query.where(WardrobeItem.created_at >= since)
    by_model: dict[str, ModelAccuracy] = {}
    for item in db.scalars(query):
        model = (item.ai_detection or {}).get("model") or "unknown"
        acc = by_model.setdefault(model, ModelAccuracy(model=model))
        acc.items += 1
        changed = corrected_fields(item)
        if changed:
            acc.any_corrected += 1
        for key in changed:
            acc.corrected[key] += 1
    return sorted(by_model.values(), key=lambda a: a.items, reverse=True)
