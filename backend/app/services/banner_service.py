"""Banner dismissal persistence (CTO doc 2 banner rules).

A dismissed banner stays hidden for DISMISS_WINDOW_DAYS, then may reappear.
One row per (user, banner); re-dismissing refreshes the timestamp.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import BannerDismissal

_log = structlog.get_logger("banners")

DISMISS_WINDOW_DAYS = 7

# Whitelist — a typoed banner key should 422, not create junk rows.
KNOWN_BANNERS = ("starter_wardrobe", "incomplete_profile")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def is_dismissed(db: Session, *, user_id: UUID, banner: str) -> bool:
    row = db.scalar(
        select(BannerDismissal).where(
            BannerDismissal.user_id == user_id,
            BannerDismissal.banner == banner,
        )
    )
    if row is None:
        return False
    return _now() - row.dismissed_at < timedelta(days=DISMISS_WINDOW_DAYS)


def dismiss(db: Session, *, user_id: UUID, banner: str) -> BannerDismissal:
    row = db.scalar(
        select(BannerDismissal).where(
            BannerDismissal.user_id == user_id,
            BannerDismissal.banner == banner,
        )
    )
    if row is None:
        row = BannerDismissal(user_id=user_id, banner=banner, dismissed_at=_now())
        db.add(row)
    else:
        row.dismissed_at = _now()
    db.commit()
    db.refresh(row)
    _log.info("banner.dismissed", user_id=str(user_id), banner=banner)
    return row
